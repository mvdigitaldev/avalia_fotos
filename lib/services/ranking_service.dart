import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';
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
    final now = DateTime.now();
    return getTopUsersOfMonthPaginated(
      limit: limit,
      offset: 0,
      month: now.month,
      year: now.year,
    );
  }

  Future<List<RankingItemModel>> getTopUsersOfMonthPaginated({
    required int limit,
    required int offset,
    required int month,
    required int year,
  }) async {
    try {
      Logger.debug('Buscando ranking: month=$month, year=$year, limit=$limit, offset=$offset');
      
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
          .eq('month', month)
          .eq('year', year)
          .order('score', ascending: false)
          .range(offset, offset + limit - 1);

      Logger.debug('Resposta recebida: ${response.length} itens');
      
      final users = <RankingItemModel>[];
      for (var i = 0; i < response.length; i++) {
        try {
          final item = response[i];
          
          // Processar userData - pode vir como Map ou List dependendo do formato
          final userData = item['users'];
          Map<String, dynamic>? userMap;
          
          if (userData != null) {
            if (userData is List && userData.isNotEmpty) {
              userMap = userData[0] as Map<String, dynamic>?;
            } else if (userData is Map<String, dynamic>) {
              userMap = userData;
            }
          }
          
          // Processar score - pode vir como String ou num
          final score = item['score'];
          double scoreValue = 0.0;
          if (score is String) {
            scoreValue = double.tryParse(score) ?? 0.0;
          } else if (score is num) {
            scoreValue = score.toDouble();
          }
          
          // Processar photos_count
          final photosCount = item['photos_count'];
          int photosCountValue = 0;
          if (photosCount is int) {
            photosCountValue = photosCount;
          } else if (photosCount is num) {
            photosCountValue = photosCount.toInt();
          }
          
          final userId = item['user_id'] as String;
          
          users.add(RankingItemModel(
            userId: userId,
            username: userMap?['username'] as String?,
            avatarUrl: userMap?['avatar_url'] as String?,
            score: scoreValue,
            photosCount: photosCountValue,
            position: offset + i + 1,
          ));
        } catch (e, stackTrace) {
          Logger.warning('Erro ao processar item $i do ranking', e, stackTrace);
          // Continuar processando outros itens mesmo se um falhar
        }
      }
      
      Logger.debug('Total de usuários processados: ${users.length}');
      return users;
    } catch (e, stackTrace) {
      Logger.error('Erro no getTopUsersOfMonthPaginated', e, stackTrace);
      throw _handleError(e);
    }
  }

  Future<int> getTotalUsersCount({
    required int month,
    required int year,
  }) async {
    try {
      final response = await _client
          .from('user_monthly_scores')
          .select('id')
          .eq('month', month)
          .eq('year', year);

      return (response as List).length;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<PhotoModel>> getBestPhotosOfMonth({
    int limit = 10,
  }) async {
    final now = DateTime.now();
    return getBestPhotosOfMonthPaginated(
      limit: limit,
      offset: 0,
      month: now.month,
      year: now.year,
    );
  }

  Future<List<PhotoModel>> getBestPhotosOfMonthPaginated({
    required int limit,
    required int offset,
    required int month,
    required int year,
  }) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

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
          .range(offset, offset + limit - 1);

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

  Future<int> getTotalPhotosCount({
    required int month,
    required int year,
  }) async {
    try {
      final startOfMonth = DateTime(year, month, 1);
      final endOfMonth = DateTime(year, month + 1, 0, 23, 59, 59);

      final response = await _client
          .from('photos')
          .select('id')
          .eq('is_shared', true)
          .gte('created_at', startOfMonth.toIso8601String())
          .lte('created_at', endOfMonth.toIso8601String());

      return (response as List).length;
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

  Future<int?> getUserOverallRankingPosition(String userId) async {
    try {
      // Buscar total_score do usuário
      final userData = await _client
          .from('users')
          .select('total_score')
          .eq('id', userId)
          .maybeSingle();

      if (userData == null) return null;

      final totalScore = (userData['total_score'] ?? 0).toDouble();

      // Contar quantos usuários têm total_score maior
      final countResponse = await _client
          .from('users')
          .select('id')
          .gt('total_score', totalScore);

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

