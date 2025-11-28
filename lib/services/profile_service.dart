// lib/services/profile_service.dart
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/user_model.dart';
import 'storage_service.dart';
import 'photo_service.dart';

class ProfileService {
  final SupabaseService _supabaseService;
  final StorageService _storageService;
  final PhotoService _photoService;

  ProfileService(this._supabaseService)
      : _storageService = StorageService(_supabaseService),
        _photoService = PhotoService(_supabaseService);

  SupabaseClient get _client => _supabaseService.client;
  String? get currentUserId => _supabaseService.currentUser?.id;

  /// Verifica se o username está disponível (case-insensitive)
  Future<bool> checkUsernameAvailability(String username) async {
    try {
      final response = await _client
          .from('users')
          .select('id')
          .ilike('username', username)
          .limit(1);

      return response.isEmpty;
    } catch (e) {
      throw Exception('Erro ao verificar disponibilidade do username: $e');
    }
  }

  /// Faz upload da foto de avatar e atualiza o perfil
  Future<String> updateAvatar(File imageFile) async {
    try {
      if (currentUserId == null) {
        throw Exception('Usuário não autenticado');
      }

      // Usar bucket 'photos' que já existe
      final bucketName = 'photos';
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$timestamp.jpg';
      final filePath = 'avatars/$currentUserId/$fileName';

      // Deletar avatar antigo se existir
      final userData = await _client
          .from('users')
          .select('avatar_url')
          .eq('id', currentUserId!)
          .maybeSingle();

      final oldAvatarUrl = userData?['avatar_url'] as String?;
      if (oldAvatarUrl != null && oldAvatarUrl.isNotEmpty) {
        try {
          // Extrair path do URL antigo
          final uri = Uri.parse(oldAvatarUrl);
          final pathSegments = uri.pathSegments;
          final bucketIndex = pathSegments.indexOf(bucketName);
          if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
            final oldFilePath = pathSegments.sublist(bucketIndex + 1).join('/');
            await _client.storage.from(bucketName).remove([oldFilePath]);
          }
        } catch (e) {
          // Ignorar erro ao deletar avatar antigo
          print('Erro ao deletar avatar antigo: $e');
        }
      }

      // Upload da nova imagem
      await _client.storage.from(bucketName).upload(
        filePath,
        imageFile,
        fileOptions: const FileOptions(
          upsert: true,
          contentType: 'image/jpeg',
        ),
      );

      // Obter URL pública
      final publicUrl = _client.storage.from(bucketName).getPublicUrl(filePath);

      // Atualizar avatar_url na tabela users
      await _client
          .from('users')
          .update({'avatar_url': publicUrl})
          .eq('id', currentUserId!);

      return publicUrl;
    } catch (e) {
      throw Exception('Erro ao atualizar avatar: $e');
    }
  }

  /// Atualiza o username com validação de unicidade
  Future<UserModel> updateUsername(String username) async {
    try {
      if (currentUserId == null) {
        throw Exception('Usuário não autenticado');
      }

      // Validar formato do username
      final usernameRegex = RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]{2,16}$');
      if (!usernameRegex.hasMatch(username)) {
        throw Exception(
          'Username inválido. Deve começar com letra e ter entre 3-17 caracteres (letras, números, _ ou -)',
        );
      }

      // Verificar se username já existe (case-insensitive)
      final isAvailable = await checkUsernameAvailability(username);
      if (!isAvailable) {
        throw Exception('Este username já está em uso');
      }

      // Atualizar username
      await _client
          .from('users')
          .update({'username': username})
          .eq('id', currentUserId!);

      // Buscar usuário atualizado
      final response = await _client
          .from('users')
          .select()
          .eq('id', currentUserId!)
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      if (e is Exception) {
        throw e;
      }
      throw Exception('Erro ao atualizar username: $e');
    }
  }

  /// Deleta a conta do usuário e todos os dados relacionados
  Future<void> deleteAccount() async {
    try {
      if (currentUserId == null) {
        throw Exception('Usuário não autenticado');
      }

      final userId = currentUserId!;

      // 1. Buscar todas as fotos do usuário para deletar do storage
      final photosResponse = await _client
          .from('photos')
          .select('image_url')
          .eq('user_id', userId);

      final photoUrls = photosResponse
          .map((p) => p['image_url'] as String?)
          .where((url) => url != null && url.isNotEmpty)
          .toList();

      // Deletar fotos do storage
      for (final url in photoUrls) {
        try {
          // Extrair path do URL
          final uri = Uri.parse(url!);
          final pathParts = uri.pathSegments;
          if (pathParts.length >= 2) {
            final bucketName = pathParts[pathParts.length - 2];
            final fileName = pathParts.last;
            await _client.storage.from(bucketName).remove([fileName]);
          }
        } catch (e) {
          print('Erro ao deletar foto do storage: $e');
          // Continuar mesmo se houver erro
        }
      }

      // Deletar avatar do storage se existir
      final userData = await _client
          .from('users')
          .select('avatar_url')
          .eq('id', userId)
          .maybeSingle();

      if (userData != null) {
        final avatarUrl = userData['avatar_url'] as String?;
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          try {
            final uri = Uri.parse(avatarUrl);
            final pathParts = uri.pathSegments;
            if (pathParts.length >= 2) {
              final bucketName = pathParts[pathParts.length - 2];
              final fileName = pathParts.last;
              await _client.storage.from(bucketName).remove([fileName]);
            }
          } catch (e) {
            print('Erro ao deletar avatar do storage: $e');
          }
        }
      }

      // 2. Deletar registros relacionados (em ordem:
      // - likes (likes do usuário)
      await _client.from('likes').delete().eq('user_id', userId);

      // - comments (comentários do usuário)
      await _client.from('comments').delete().eq('user_id', userId);

      // - photos (fotos do usuário)
      await _client.from('photos').delete().eq('user_id', userId);

      // - user_monthly_scores
      await _client.from('user_monthly_scores').delete().eq('user_id', userId);

      // - user_monthly_evaluations
      await _client.from('user_monthly_evaluations').delete().eq('user_id', userId);

      // - user_plans
      await _client.from('user_plans').delete().eq('user_id', userId);

      // 3. Deletar da tabela users ANTES de deletar do Auth
      // Isso é importante porque precisamos estar autenticados para deletar devido ao RLS
      await _client.from('users').delete().eq('id', userId);

      // 4. Chamar Edge Function para deletar do Supabase Auth
      // A Edge Function terá permissões de admin para deletar o usuário
      try {
        final response = await _client.functions.invoke(
          'delete-user-account',
          body: {'user_id': userId},
        );

        if (response.status != 200) {
          final errorData = response.data as Map<String, dynamic>?;
          // Se falhar, fazer signOut mesmo assim
          await _client.auth.signOut();
          throw Exception(
            errorData?['error'] ?? 'Erro ao deletar conta do Auth',
          );
        }

        // Se a Edge Function funcionou, fazer signOut
        await _client.auth.signOut();
      } catch (e) {
        print('Erro ao chamar Edge Function para deletar conta: $e');
        // Fazer signOut mesmo se a Edge Function falhar
        // A conta do Auth pode precisar ser deletada manualmente no Supabase Dashboard
        try {
          await _client.auth.signOut();
        } catch (signOutError) {
          print('Erro ao fazer signOut: $signOutError');
        }
        throw Exception(
          'Conta deletada parcialmente. A conta do Auth pode precisar ser deletada manualmente no Supabase Dashboard.',
        );
      }
    } catch (e) {
      // Se admin.deleteUser não funcionar, tentar signOut
      try {
        await _client.auth.signOut();
      } catch (signOutError) {
        print('Erro ao fazer signOut: $signOutError');
      }
      throw Exception('Erro ao deletar conta: $e');
    }
  }

  /// Busca estatísticas do perfil do usuário
  Future<Map<String, dynamic>> getProfileStats() async {
    try {
      if (currentUserId == null) {
        throw Exception('Usuário não autenticado');
      }

      final userId = currentUserId!;

      // Buscar dados do usuário
      final userResponse = await _client
          .from('users')
          .select('created_at, username, email, avatar_url')
          .eq('id', userId)
          .single();

      // Contar total de fotos avaliadas
      final photosCountResponse = await _client
          .from('photos')
          .select('id')
          .eq('user_id', userId);

      final totalPhotosEvaluated = photosCountResponse.length;

      // Buscar plano atual
      final planResponse = await _client
          .from('user_plans')
          .select('''
            expires_at,
            plans:plan_id (
              name
            )
          ''')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      String planName = 'Sem plano';
      DateTime? planExpiresAt;
      bool isFreePlan = false;
      
      if (planResponse != null) {
        final planData = planResponse['plans'];
        if (planData is Map<String, dynamic>) {
          planName = planData['name'] as String? ?? 'Sem plano';
        } else if (planData is List && planData.isNotEmpty) {
          planName = (planData[0] as Map<String, dynamic>)['name'] as String? ?? 'Sem plano';
        }
        
        isFreePlan = planName.toLowerCase() == 'free';
        
        // Buscar expires_at
        final expiresAtStr = planResponse['expires_at'] as String?;
        if (expiresAtStr != null && expiresAtStr.isNotEmpty) {
          planExpiresAt = DateTime.parse(expiresAtStr);
        }
      }

      return {
        'username': userResponse['username'] as String?,
        'email': userResponse['email'] as String?,
        'avatar_url': userResponse['avatar_url'] as String?,
        'created_at': DateTime.parse(userResponse['created_at'] as String),
        'total_photos_evaluated': totalPhotosEvaluated,
        'plan_name': planName,
        'plan_expires_at': planExpiresAt,
        'is_free_plan': isFreePlan,
      };
    } catch (e) {
      throw Exception('Erro ao buscar estatísticas do perfil: $e');
    }
  }
}

