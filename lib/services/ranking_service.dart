import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/ranking_item_model.dart';
import '../models/photo_model.dart';

class RankingService {
  final SupabaseService _supabaseService;

  RankingService(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;

  Future<List<RankingItemModel>> getTopUsersOfMonth({
    int limit = 10,
  }) async {
    try {
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      final response = await _client
          .from('user_monthly_scores')
          .select('''
            user_id,
            score,
            photos_count,
            users:user_id (
              username,
              avatar_url
            )
          ''')
          .eq('month', currentMonth)
          .eq('year', currentYear)
          .order('score', ascending: false)
          .limit(limit);

      return response.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final userData = item['users'] as Map<String, dynamic>?;
        
        return RankingItemModel(
          userId: item['user_id'] as String,
          username: userData?['username'] as String?,
          avatarUrl: userData?['avatar_url'] as String?,
          score: (item['score'] ?? 0).toDouble(),
          photosCount: item['photos_count'] ?? 0,
          position: index + 1,
        );
      }).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<PhotoModel>> getBestPhotosOfMonth({
    int limit = 10,
  }) async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final response = await _client
          .from('photos')
          .select('''
            *,
            users:user_id (
              username,
              avatar_url
            )
          ''')
          .eq('is_shared', true)
          .gte('created_at', startOfMonth.toIso8601String())
          .lte('created_at', endOfMonth.toIso8601String())
          .order('score', ascending: false)
          .limit(limit);

      final photos = <PhotoModel>[];
      for (final item in response) {
        final userData = item['users'] as Map<String, dynamic>?;
        photos.add(PhotoModel.fromJson(item).copyWith(
          username: userData?['username'] as String?,
          userAvatarUrl: userData?['avatar_url'] as String?,
        ));
      }
      return photos;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<int?> getUserRankingPosition(String userId) async {
    try {
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      // Buscar score do usuário
      final userScore = await _client
          .from('user_monthly_scores')
          .select('score')
          .eq('user_id', userId)
          .eq('month', currentMonth)
          .eq('year', currentYear)
          .maybeSingle();

      if (userScore == null) return null;

      final score = (userScore['score'] ?? 0).toDouble();

      // Contar quantos usuários têm score maior
      final countResponse = await _client
          .from('user_monthly_scores')
          .select('id')
          .eq('month', currentMonth)
          .eq('year', currentYear)
          .gt('score', score);

      final position = countResponse.length + 1;
      return position;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic error) {
    if (error is PostgrestException) {
      return Exception(error.message);
    } else if (error is Exception) {
      return error;
    } else {
      return Exception('Erro desconhecido: $error');
    }
  }
}

