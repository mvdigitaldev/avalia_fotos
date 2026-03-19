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
      
      // A Edge Function já salva a foto e atualiza user_monthly_scores e user_monthly_evaluations
      final photoData = responseData['photo'] as Map<String, dynamic>;
      final photo = PhotoModel.fromJson(photoData);
      
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

}

