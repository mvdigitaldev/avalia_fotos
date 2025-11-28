import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/evaluation_result_model.dart';
import '../models/photo_model.dart';
import '../models/achievement_model.dart';
import 'photo_service.dart';
import 'plan_service.dart';
import 'achievement_service.dart';

class AIEvaluationService {
  final SupabaseService _supabaseService;
  final PhotoService _photoService;
  final PlanService _planService;
  final AchievementService _achievementService;

  AIEvaluationService(this._supabaseService)
      : _photoService = PhotoService(_supabaseService),
        _planService = PlanService(_supabaseService),
        _achievementService = AchievementService(_supabaseService);

  SupabaseClient get _client => _supabaseService.client;
  String? get currentUserId => _supabaseService.currentUser?.id;

  Future<PhotoModel> evaluatePhoto({
    required File imageFile,
    required String imageUrl,
    required bool isShared,
  }) async {
    try {
      if (currentUserId == null) {
        throw Exception('Usuário não autenticado');
      }

      // Verificar limites antes de avaliar
      final limitCheck = await _planService.canEvaluatePhoto(currentUserId!);
      if (!limitCheck.canEvaluate) {
        throw Exception(limitCheck.reason ?? 'Limite atingido');
      }

      // Converter imagem para base64
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // Chamar Edge Function
      final response = await _client.functions.invoke(
        'evaluate-photo',
        body: {
          'image_base64': base64Image,
          'image_url': imageUrl, // Incluir também para compatibilidade
          'is_shared': isShared,
          'user_id': currentUserId!,
        },
      );

      if (response.status != 200) {
        final errorData = response.data as Map<String, dynamic>?;
        throw Exception(
          errorData?['error'] ?? 'Erro ao avaliar foto',
        );
      }

      // Processar resultado da avaliação
      final responseData = response.data as Map<String, dynamic>;
      
      // A Edge Function já salva a foto no banco e retorna o objeto photo completo
      final photoData = responseData['photo'] as Map<String, dynamic>;
      final photo = PhotoModel.fromJson(photoData);
      
      // Incrementar contador de avaliações mensais após sucesso
      await _planService.incrementMonthlyEvaluation(currentUserId!);
      
      // Atualizar pontuação mensal do usuário
      await _updateMonthlyScore(photo.score);
      
      // Nota: A verificação de conquistas será feita na UI após a avaliação
      // para permitir que o modal seja exibido corretamente
      
      return photo;
    } catch (e) {
      if (e is Exception) {
        throw e;
      } else {
        throw Exception('Erro desconhecido ao avaliar foto: $e');
      }
    }
  }

  Future<void> _updateMonthlyScore(double photoScore) async {
    try {
      if (currentUserId == null) return;

      // Calcular pontuação a adicionar: (score/2) + 2
      final scoreToAdd = (photoScore / 2) + 2;

      // Obter mês e ano atual como inteiros
      final now = DateTime.now();
      final month = now.month;
      final year = now.year;

      // Verificar se já existe registro para este mês/ano
      final existing = await _client
          .from('user_monthly_scores')
          .select('id, score, photos_count')
          .eq('user_id', currentUserId!)
          .eq('month', month)
          .eq('year', year)
          .maybeSingle();

      if (existing != null) {
        // Atualizar pontuação existente e incrementar contador de fotos
        final currentScore = (existing['score'] as num).toDouble();
        final currentPhotosCount = (existing['photos_count'] as num?)?.toInt() ?? 0;
        
        await _client
            .from('user_monthly_scores')
            .update({
              'score': currentScore + scoreToAdd,
              'photos_count': currentPhotosCount + 1,
            })
            .eq('id', existing['id']);
      } else {
        // Criar novo registro para o mês/ano atual
        // Quando o mês muda, um novo registro é criado automaticamente (score começa do zero)
        await _client.from('user_monthly_scores').insert({
          'user_id': currentUserId!,
          'month': month,
          'year': year,
          'score': scoreToAdd,
          'photos_count': 1,
        });
      }
    } catch (e, stackTrace) {
      // Não falhar a avaliação se houver erro ao atualizar score
      print('Erro ao atualizar pontuação mensal: $e');
      print('Stack trace: $stackTrace');
    }
  }
}

