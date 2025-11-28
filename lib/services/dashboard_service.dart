// lib/services/dashboard_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/dashboard_stats_model.dart';
import '../models/photo_model.dart';
import 'ranking_service.dart';
import 'plan_service.dart';
import 'photo_service.dart';
import 'auth_service.dart';

class DashboardService {
  final SupabaseService _supabaseService;
  final RankingService _rankingService;
  final PlanService _planService;
  final PhotoService _photoService;
  final AuthService _authService;

  DashboardService(this._supabaseService)
      : _rankingService = RankingService(_supabaseService),
        _planService = PlanService(_supabaseService),
        _photoService = PhotoService(_supabaseService),
        _authService = AuthService(_supabaseService);

  SupabaseClient get _client => _supabaseService.client;
  String? get currentUserId => _supabaseService.currentUser?.id;

  Future<DashboardStatsModel> getUserDashboardStats(String userId) async {
    try {
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;
      final startOfMonth = DateTime(currentYear, currentMonth, 1);
      final endOfMonth = DateTime(currentYear, currentMonth + 1, 0, 23, 59, 59);

      // Buscar pontuação mensal do usuário
      final monthlyScoreData = await _client
          .from('user_monthly_scores')
          .select('score')
          .eq('user_id', userId)
          .eq('month', currentMonth)
          .eq('year', currentYear)
          .maybeSingle();

      final monthlyScore = monthlyScoreData != null
          ? (monthlyScoreData['score'] as num).toDouble()
          : 0.0;

      // Buscar posição no ranking mensal
      final rankingPosition = await _rankingService.getUserRankingPosition(userId);

      // Buscar avaliações do mês
      final monthlyEvaluations = await _planService.getUserMonthlyEvaluations(
        userId,
        currentMonth,
        currentYear,
      );

      // Buscar plano do usuário para pegar limite
      final userPlan = await _planService.getUserPlan(userId);
      final monthlyLimit = userPlan?.plan?.monthlyEvaluationsLimit;

      // Calcular média das notas do mês
      final photosResponse = await _client
          .from('photos')
          .select('score')
          .eq('user_id', userId)
          .gte('created_at', startOfMonth.toIso8601String())
          .lte('created_at', endOfMonth.toIso8601String());

      double? monthlyAverageScore;
      if (photosResponse.isNotEmpty) {
        final scores = photosResponse
            .map((p) => (p['score'] is String
                ? double.tryParse(p['score'] as String)
                : (p['score'] ?? 0).toDouble()))
            .where((s) => s != null)
            .cast<double>()
            .toList();
        
        if (scores.isNotEmpty) {
          monthlyAverageScore = scores.reduce((a, b) => a + b) / scores.length;
        }
      }

      // Buscar melhor foto do mês
      final bestPhotoResponse = await _client
          .from('photos')
          .select('''
            *,
            users:user_id (
              username,
              avatar_url
            )
          ''')
          .eq('user_id', userId)
          .gte('created_at', startOfMonth.toIso8601String())
          .lte('created_at', endOfMonth.toIso8601String())
          .order('score', ascending: false)
          .limit(1)
          .maybeSingle();

      PhotoModel? bestPhotoOfMonth;
      if (bestPhotoResponse != null) {
        final userData = bestPhotoResponse['users'] as Map<String, dynamic>?;
        bestPhotoOfMonth = PhotoModel.fromJson(bestPhotoResponse).copyWith(
          username: userData?['username'] as String?,
          userAvatarUrl: userData?['avatar_url'] as String?,
        );
      }

      return DashboardStatsModel(
        rankingPosition: rankingPosition,
        monthlyScore: monthlyScore,
        monthlyEvaluationsUsed: monthlyEvaluations,
        monthlyEvaluationsLimit: monthlyLimit,
        monthlyAverageScore: monthlyAverageScore,
        bestPhotoOfMonth: bestPhotoOfMonth,
      );
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

