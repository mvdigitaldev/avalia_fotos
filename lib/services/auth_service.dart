import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'notification_service.dart';
import '../models/user_model.dart';
import '../utils/logger.dart';
import '../utils/error_handler.dart';
import '../utils/exceptions.dart';

class AuthService {
  final SupabaseService _supabaseService;

  AuthService(this._supabaseService);

  SupabaseClient get _client {
    try {
      return _supabaseService.client;
    } catch (e) {
      Logger.error('Erro ao acessar cliente Supabase no AuthService', e);
      rethrow;
    }
  }

  User? get currentUser => _supabaseService.currentUser;

  Stream<AuthState> get authStateChanges => _supabaseService.authStateChanges;

  Future<UserModel?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw Exception('Falha ao fazer login');
      }

      Logger.info('Login realizado com sucesso. Atualizando token de notificação...');
      // Atualizar token de notificação
      try {
        await NotificationService().refreshToken();
        Logger.info('Token de notificação atualizado após login.');
      } catch (e) {
        Logger.error('Erro ao atualizar token após login: $e');
        // Não impedir o login se falhar
      }

      return await getCurrentUserProfile();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserModel?> signUpWithEmail({
    required String email,
    required String password,
    String? username,
  }) async {
    try {
      // Se username foi fornecido, validar formato e unicidade
      if (username != null && username.isNotEmpty) {
        // Validar formato do username
        final usernameRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]{2,16}$');
        if (!usernameRegex.hasMatch(username)) {
          throw Exception(
            'Username inválido. Deve começar com letra e ter entre 3-17 caracteres (letras, números, _ ou -)',
          );
        }

        // Verificar se username já existe (case-insensitive)
        final existing = await _client
            .from('users')
            .select('id')
            .ilike('username', username)
            .limit(1);

        if (existing.isNotEmpty) {
          throw Exception('Este username já está em uso');
        }
      }

      // Criar usuário no Auth primeiro
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: username != null ? {'username': username} : null,
      );

      if (response.user == null) {
        throw Exception('Falha ao criar conta');
      }

      final userId = response.user!.id;
      final finalUsername = username ?? 'user_${userId.substring(0, 8)}';

      // Aguardar um pouco para o trigger processar (se existir)
      await Future.delayed(const Duration(milliseconds: 1500));

      // Verificar se o registro foi criado pelo trigger
      UserModel? userProfile;
      try {
        userProfile = await getCurrentUserProfile();
        if (userProfile != null) {
          // Atualizar token de notificação
          try {
            await NotificationService().refreshToken();
          } catch (e) {
            Logger.warning('Erro ao atualizar token de notificação após cadastro', e);
          }
          return userProfile;
        }
      } catch (e, stackTrace) {
        Logger.debug('Trigger não criou o registro ou ainda não está disponível', e, stackTrace);
      }

      // Se o trigger não funcionou, criar manualmente usando RPC
      try {
        // Buscar o plano Free primeiro
        final freePlanResponse = await _client
            .from('plans')
            .select('id')
            .eq('name', 'Free')
            .single();

        final freePlanId = freePlanResponse['id'] as String;

        // Chamar função RPC para criar o perfil
        try {
          final rpcResponse = await _client.rpc('create_user_profile', params: {
            'p_user_id': userId,
            'p_email': email,
            'p_username': finalUsername,
            'p_free_plan_id': freePlanId,
          });

          // Verificar resposta do RPC
          if (rpcResponse is Map<String, dynamic>) {
            final success = rpcResponse['success'] as bool? ?? false;
            if (!success) {
              final error = rpcResponse['error'] as String? ?? 'Erro desconhecido';
              Logger.warning('RPC retornou erro: $error');
              throw Exception('Erro ao criar perfil: $error');
            }
          }
        } catch (rpcError, stackTrace) {
          Logger.warning('Erro ao chamar RPC', rpcError, stackTrace);
          // Continuar para tentar inserção direta
          rethrow;
        }

        // Aguardar um pouco para garantir que foi criado
        await Future.delayed(const Duration(milliseconds: 1000));

        // Tentar buscar o perfil novamente
        userProfile = await getCurrentUserProfile();
        
        if (userProfile != null) {
          // Atualizar token de notificação
          try {
            await NotificationService().refreshToken();
          } catch (e) {
            Logger.warning('Erro ao atualizar token de notificação após cadastro (fallback)', e);
          }
          return userProfile;
        }

        // Se ainda não encontrou, tentar inserção direta como último recurso
        try {
          await _client.from('users').insert({
            'id': userId,
            'email': email,
            'username': finalUsername,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          await Future.delayed(const Duration(milliseconds: 500));

          await _client.from('user_plans').insert({
            'user_id': userId,
            'plan_id': freePlanId,
            'is_active': true,
            'started_at': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          await Future.delayed(const Duration(milliseconds: 500));
          userProfile = await getCurrentUserProfile();
          
          if (userProfile != null) {
            // Atualizar token de notificação
            try {
              await NotificationService().refreshToken();
            } catch (e) {
              Logger.warning('Erro ao atualizar token de notificação após cadastro (direct)', e);
            }
            return userProfile;
          }
        } catch (insertError, stackTrace) {
          Logger.warning('Erro ao inserir diretamente', insertError, stackTrace);
        }

        // Se chegou aqui, nenhum método funcionou
        // Mas o usuário foi criado no Auth, então pedir para fazer login
        throw Exception('Conta criada no sistema de autenticação, mas houve um erro ao criar o perfil. Por favor, faça login novamente.');
      } catch (e, stackTrace) {
        Logger.error('Erro geral ao criar perfil', e, stackTrace);
        // Se o usuário foi criado no Auth mas não no banco, pedir para fazer login
        throw Exception('Conta criada, mas houve um erro ao criar o perfil. Por favor, faça login novamente - seu perfil será criado automaticamente.');
      }
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> signOut() async {
    try {
      // Remover token de notificação antes de fazer logout
      try {
        final notificationService = NotificationService();
        if (notificationService.isInitialized) {
          await notificationService.removeToken();
        }
      } catch (e) {
        Logger.debug('Erro ao remover token de notificação no logout', e);
        // Continuar mesmo se houver erro ao remover token
      }
      
      await _client.auth.signOut();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserModel?> getCurrentUserProfile() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      final response = await _client
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<UserModel> updateProfile({
    String? username,
    String? avatarUrl,
  }) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('Usuário não autenticado');
      }

      final updates = <String, dynamic>{};
      if (username != null) {
        // Validar formato do username
        final usernameRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]{2,16}$');
        if (!usernameRegex.hasMatch(username)) {
          throw Exception(
            'Username inválido. Deve começar com letra e ter entre 3-17 caracteres (letras, números, _ ou -)',
          );
        }

        // Verificar se username já existe (case-insensitive), excluindo o usuário atual
        final existing = await _client
            .from('users')
            .select('id')
            .ilike('username', username)
            .neq('id', user.id)
            .limit(1);

        if (existing.isNotEmpty) {
          throw Exception('Este username já está em uso');
        }

        updates['username'] = username;
      }
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      await _client.from('users').update(updates).eq('id', user.id);

      return (await getCurrentUserProfile())!;
    } catch (e) {
      throw _handleError(e);
    }
  }

  AppException _handleError(dynamic error) {
    return ErrorHandler.handleError(error);
  }
}

