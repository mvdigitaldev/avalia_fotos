import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/user_model.dart';

class AuthService {
  final SupabaseService _supabaseService;

  AuthService(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;

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
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: username != null ? {'username': username} : null,
      );

      if (response.user == null) {
        throw Exception('Falha ao criar conta');
      }

      // O trigger cria o registro em users automaticamente
      return await getCurrentUserProfile();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> signOut() async {
    try {
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
      if (username != null) updates['username'] = username;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      await _client.from('users').update(updates).eq('id', user.id);

      return (await getCurrentUserProfile())!;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic error) {
    if (error is AuthException) {
      return Exception(error.message);
    } else if (error is PostgrestException) {
      return Exception(error.message);
    } else if (error is Exception) {
      return error;
    } else {
      return Exception('Erro desconhecido: $error');
    }
  }
}

