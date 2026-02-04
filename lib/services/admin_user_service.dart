// lib/services/admin_user_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../utils/logger.dart';

class AdminUserService {
  final SupabaseService _supabaseService;

  AdminUserService(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;

  Future<List<Map<String, dynamic>>> searchUserByEmail(String email) async {
    try {
      final response = await _client.rpc(
        'admin_search_user_by_email',
        params: {'p_email': email.trim()},
      );
      if (response == null) return [];
      if (response is! List) return [];
      return List<Map<String, dynamic>>.from(
        response.map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map)),
      );
    } catch (e) {
      Logger.error('Erro ao buscar usuário por email', e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updateUserData(
    String userId, {
    String? username,
    String? email,
    String? city,
    String? state,
    String? phone,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (username != null) updates['username'] = username.trim().isEmpty ? null : username.trim();
      if (email != null) updates['email'] = email.trim().isEmpty ? null : email.trim();
      if (city != null) updates['city'] = city.trim().isEmpty ? null : city.trim();
      if (state != null) {
        final s = state.trim().toUpperCase();
        updates['state'] = s.isEmpty ? null : (s.length > 2 ? s.substring(0, 2) : s);
      }
      if (phone != null) updates['phone'] = phone.trim().isEmpty ? null : phone.trim();

      if (updates.isEmpty) return;

      updates['updated_at'] = DateTime.now().toIso8601String();

      await _client.from('users').update(updates).eq('id', userId);
    } catch (e) {
      Logger.error('Erro ao atualizar dados do usuário', e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updateUserPlan(String userId, String planId) async {
    try {
      await _client.from('plans').select('id').eq('id', planId).single();

      final existingPlans = await _client
          .from('user_plans')
          .select('id')
          .eq('user_id', userId)
          .eq('is_active', true);

      final now = DateTime.now().toIso8601String();

      if (existingPlans != null && existingPlans.isNotEmpty) {
        await _client
            .from('user_plans')
            .update({
              'is_active': false,
              'updated_at': now,
            })
            .eq('user_id', userId)
            .eq('is_active', true);
      }

      await _client.from('user_plans').insert({
        'user_id': userId,
        'plan_id': planId,
        'is_active': true,
        'started_at': now,
        'created_at': now,
        'updated_at': now,
      });
    } catch (e) {
      Logger.error('Erro ao atualizar plano do usuário', e, StackTrace.current);
      rethrow;
    }
  }

  Future<void> updateUserPassword(String userId, String newPassword) async {
    try {
      final response = await _client.functions.invoke(
        'admin-update-user-password',
        body: {'userId': userId, 'newPassword': newPassword},
      );

      if (response.status != 200) {
        final errorBody = response.data;
        final msg = errorBody is Map ? (errorBody['error'] as String? ?? response.status.toString()) : response.status.toString();
        throw Exception(msg);
      }
    } catch (e) {
      if (e is Exception) rethrow;
      Logger.error('Erro ao atualizar senha', e, StackTrace.current);
      rethrow;
    }
  }
}
