// lib/services/plan_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/plan_model.dart';
import '../models/user_plan_model.dart';
import '../models/evaluation_limit_model.dart';
import 'photo_service.dart';

class PlanService {
  final SupabaseService _supabaseService;
  final PhotoService _photoService;

  PlanService(this._supabaseService)
      : _photoService = PhotoService(_supabaseService);

  SupabaseClient get _client => _supabaseService.client;
  String? get currentUserId => _supabaseService.currentUser?.id;

  Future<UserPlanModel?> getUserPlan(String userId) async {
    try {
      final response = await _client
          .from('user_plans')
          .select('''
            *,
            plans:plan_id (
              id,
              name,
              monthly_evaluations_limit,
              storage_limit,
              price,
              link_plan
            )
          ''')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return UserPlanModel.fromJson(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<int> getUserMonthlyEvaluations(String userId, int month, int year) async {
    try {
      final response = await _client
          .from('user_monthly_evaluations')
          .select('evaluations_count')
          .eq('user_id', userId)
          .eq('month', month)
          .eq('year', year)
          .maybeSingle();

      return response?['evaluations_count'] as int? ?? 0;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<EvaluationLimitModel> canEvaluatePhoto(String userId) async {
    try {
      // Buscar plano do usuário
      final userPlan = await getUserPlan(userId);
      if (userPlan == null) {
        return EvaluationLimitModel(
          canEvaluate: false,
          reason: 'Plano não encontrado',
          storageUsed: 0,
        );
      }

      final plan = userPlan.plan;

      // Verificar limite mensal
      final now = DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;

      int? monthlyEvaluationsUsed;
      if (!plan.isUnlimitedEvaluations) {
        monthlyEvaluationsUsed = await getUserMonthlyEvaluations(
          userId,
          currentMonth,
          currentYear,
        );

        if (monthlyEvaluationsUsed >= plan.monthlyEvaluationsLimit!) {
          return EvaluationLimitModel(
            canEvaluate: false,
            reason: 'Limite mensal de avaliações atingido',
            monthlyEvaluationsUsed: monthlyEvaluationsUsed,
            monthlyEvaluationsLimit: plan.monthlyEvaluationsLimit,
            storageUsed: 0,
            storageLimit: plan.storageLimit,
          );
        }
      }

      // Verificar limite de armazenamento
      int storageUsed = await _photoService.getUserStorageCount();
      
      // Garantir que storageUsed seja sempre atualizado
      if (!plan.isUnlimitedStorage) {
        if (storageUsed >= plan.storageLimit!) {
          return EvaluationLimitModel(
            canEvaluate: false,
            reason: 'Limite de armazenamento atingido',
            monthlyEvaluationsUsed: monthlyEvaluationsUsed,
            monthlyEvaluationsLimit: plan.monthlyEvaluationsLimit,
            storageUsed: storageUsed,
            storageLimit: plan.storageLimit,
          );
        }
      }

      return EvaluationLimitModel(
        canEvaluate: true,
        monthlyEvaluationsUsed: monthlyEvaluationsUsed ?? 0,
        monthlyEvaluationsLimit: plan.monthlyEvaluationsLimit,
        storageUsed: storageUsed,
        storageLimit: plan.storageLimit,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> incrementMonthlyEvaluation(String userId) async {
    try {
      await _client.rpc('increment_monthly_evaluation', params: {
        'p_user_id': userId,
      });
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<PlanModel>> getAvailablePlans() async {
    try {
      final response = await _client
          .from('plans')
          .select('id, name, monthly_evaluations_limit, storage_limit, price, link_plan')
          .order('price', ascending: true);

      return (response as List)
          .map((item) => PlanModel.fromJson(item))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> upgradePlan(String userId, String planId) async {
    try {
      // Verificar se o plano escolhido é Free (não permitir upgrade para Free)
      final planInfo = await _client
          .from('plans')
          .select('name')
          .eq('id', planId)
          .single();
      
      final planName = planInfo['name'] as String?;
      if (planName?.toLowerCase() == 'free') {
        throw Exception('Não é possível migrar para o plano Free');
      }

      // Verificar se já existe um plano ativo
      final existingPlan = await _client
          .from('user_plans')
          .select('id, plan_id, plans:plan_id(name)')
          .eq('user_id', userId)
          .eq('is_active', true)
          .maybeSingle();

      if (existingPlan != null) {
        final planData = existingPlan['plans'];
        final currentPlanName = planData is Map<String, dynamic> 
            ? planData['name'] as String?
            : (planData is List && planData.isNotEmpty)
                ? (planData[0] as Map<String, dynamic>)['name'] as String?
                : null;
        
        final isCurrentlyFree = currentPlanName?.toLowerCase() == 'free';
        
        if (isCurrentlyFree) {
          // Se está no Free, criar novo registro com o plano escolhido
          // Primeiro, desativar o plano Free atual
          await _client
              .from('user_plans')
              .update({
                'is_active': false,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', existingPlan['id']);
          
          // Criar novo registro com o plano escolhido
          await _client.from('user_plans').insert({
            'user_id': userId,
            'plan_id': planId,
            'is_active': true,
            'started_at': DateTime.now().toIso8601String(),
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } else {
          // Se já tem plano pago ativo, atualizar o plan_id
          await _client
              .from('user_plans')
              .update({
                'plan_id': planId,
                'started_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', existingPlan['id']);
        }
      } else {
        // Se não existe plano ativo, criar novo
        await _client.from('user_plans').insert({
          'user_id': userId,
          'plan_id': planId,
          'is_active': true,
          'started_at': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
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

