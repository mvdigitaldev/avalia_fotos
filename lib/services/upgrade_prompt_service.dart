// lib/services/upgrade_prompt_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'plan_service.dart';
import 'photo_service.dart';
import 'supabase_service.dart';
import '../models/user_plan_model.dart';
import '../models/evaluation_limit_model.dart';
import '../utils/logger.dart';

class UpgradePromptService {
  final PlanService _planService;
  final PhotoService _photoService;

  UpgradePromptService(this._planService, SupabaseService supabaseService)
      : _photoService = PhotoService(supabaseService);

  static const int _bannerCooldownDays = 7;
  static const int _modalCooldownDays = 1;
  static const double _limitWarningThreshold = 0.8; // 80%

  /// Verifica se deve mostrar banner baseado em frequência
  Future<bool> shouldShowBanner(String userId, String bannerType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'upgrade_banner_${bannerType}_last_shown_$userId';
      final lastShown = prefs.getInt(key);

      if (lastShown == null) {
        return true; // Nunca foi mostrado
      }

      final lastShownDate = DateTime.fromMillisecondsSinceEpoch(lastShown);
      final daysSince = DateTime.now().difference(lastShownDate).inDays;

      return daysSince >= _bannerCooldownDays;
    } catch (e, stackTrace) {
      Logger.error('Erro ao verificar se deve mostrar banner', e, stackTrace);
      return false;
    }
  }

  /// Registra que um prompt foi mostrado
  Future<void> trackPromptShown(String userId, String promptType) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'upgrade_${promptType}_last_shown_$userId';
      await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
    } catch (e, stackTrace) {
      Logger.error('Erro ao registrar prompt mostrado', e, stackTrace);
    }
  }

  /// Verifica se deve mostrar aviso de limite
  Future<bool> shouldShowLimitWarning(String userId, String limitType) async {
    try {
      // Verificar cooldown
      final prefs = await SharedPreferences.getInstance();
      final key = 'upgrade_modal_limit_${limitType}_last_shown_$userId';
      final lastShown = prefs.getInt(key);

      if (lastShown != null) {
        final lastShownDate = DateTime.fromMillisecondsSinceEpoch(lastShown);
        final daysSince = DateTime.now().difference(lastShownDate).inDays;
        if (daysSince < _modalCooldownDays) {
          return false; // Ainda em cooldown
        }
      }

      // Verificar se está próximo do limite
      final progress = await getUsageProgress(userId);
      
      if (limitType == 'evaluations') {
        final evaluationsProgress = progress['evaluations'] as Map<String, dynamic>?;
        if (evaluationsProgress != null) {
          final percentage = evaluationsProgress['percentage'] as double? ?? 0.0;
          return percentage >= _limitWarningThreshold;
        }
      } else if (limitType == 'storage') {
        final storageProgress = progress['storage'] as Map<String, dynamic>?;
        if (storageProgress != null) {
          final percentage = storageProgress['percentage'] as double? ?? 0.0;
          return percentage >= _limitWarningThreshold;
        }
      }

      return false;
    } catch (e, stackTrace) {
      Logger.error('Erro ao verificar aviso de limite', e, stackTrace);
      return false;
    }
  }

  /// Retorna progresso de uso (avaliações e storage)
  Future<Map<String, dynamic>> getUsageProgress(String userId) async {
    try {
      final userPlan = await _planService.getUserPlan(userId);
      
      if (userPlan == null || userPlan.plan.isFree) {
        return {
          'isFree': true,
          'evaluations': null,
          'storage': null,
        };
      }

      final plan = userPlan.plan;
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      // Progresso de avaliações
      Map<String, dynamic>? evaluationsProgress;
      if (!plan.isUnlimitedEvaluations && plan.monthlyEvaluationsLimit != null) {
        final evaluationsUsed = await _planService.getUserMonthlyEvaluations(
          userId,
          currentMonth,
          currentYear,
        );
        final limit = plan.monthlyEvaluationsLimit!;
        final percentage = limit > 0 ? evaluationsUsed / limit : 0.0;

        evaluationsProgress = {
          'used': evaluationsUsed,
          'limit': limit,
          'percentage': percentage,
          'remaining': limit - evaluationsUsed,
        };
      }

      // Progresso de storage
      Map<String, dynamic>? storageProgress;
      if (!plan.isUnlimitedStorage && plan.storageLimit != null) {
        final storageUsed = await _photoService.getUserStorageCount();
        final limit = plan.storageLimit!;
        final percentage = limit > 0 ? storageUsed / limit : 0.0;

        storageProgress = {
          'used': storageUsed,
          'limit': limit,
          'percentage': percentage,
          'remaining': limit - storageUsed,
        };
      }

      return {
        'isFree': false,
        'evaluations': evaluationsProgress,
        'storage': storageProgress,
      };
    } catch (e, stackTrace) {
      Logger.error('Erro ao obter progresso de uso', e, stackTrace);
      return {
        'isFree': true,
        'evaluations': null,
        'storage': null,
      };
    }
  }

  /// Verifica se o usuário está no plano free
  Future<bool> isUserOnFreePlan(String userId) async {
    try {
      final userPlan = await _planService.getUserPlan(userId);
      return userPlan == null || userPlan.plan.isFree;
    } catch (e, stackTrace) {
      Logger.error('Erro ao verificar se usuário está no plano free', e, stackTrace);
      return true; // Assume free em caso de erro
    }
  }

  /// Obtém informações do plano atual do usuário
  Future<UserPlanModel?> getUserPlan(String userId) async {
    try {
      return await _planService.getUserPlan(userId);
    } catch (e, stackTrace) {
      Logger.error('Erro ao obter plano do usuário', e, stackTrace);
      return null;
    }
  }
}
