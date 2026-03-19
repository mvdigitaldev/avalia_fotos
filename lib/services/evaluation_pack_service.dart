// lib/services/evaluation_pack_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/evaluation_pack_model.dart';

class EvaluationPackService {
  final SupabaseService _supabaseService;

  EvaluationPackService(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;

  Future<List<EvaluationPackModel>> getActivePacks() async {
    try {
      final response = await _client
          .from('evaluation_packs')
          .select('*')
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      return (response as List)
          .map((item) => EvaluationPackModel.fromJson(item))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<int> getUserExtraCount(String userId) async {
    try {
      final result = await _client.rpc(
        'get_user_extra_count',
        params: {'p_user_id': userId},
      );
      if (result == null) return 0;
      return (result as num).toInt();
    } catch (e) {
      return 0;
    }
  }
}
