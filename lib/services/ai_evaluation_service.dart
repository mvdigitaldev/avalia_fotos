import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../models/evaluation_result_model.dart';
import '../models/photo_model.dart';
import 'photo_service.dart';

class AIEvaluationService {
  final SupabaseService _supabaseService;
  final PhotoService _photoService;

  AIEvaluationService(this._supabaseService)
      : _photoService = PhotoService(_supabaseService);

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
      
      // O objeto photo já vem do banco com todos os campos corretos
      // Apenas garantir que os campos estão no formato correto
      return PhotoModel.fromJson(photoData);
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

      // Obter mês atual
      final now = DateTime.now();
      final month = DateTime(now.year, now.month, 1);

      // Verificar se já existe registro para este mês
      final existing = await _client
          .from('user_monthly_scores')
          .select('id, score')
          .eq('user_id', currentUserId!)
          .eq('month', month.toIso8601String())
          .maybeSingle();

      if (existing != null) {
        // Atualizar pontuação existente
        await _client
            .from('user_monthly_scores')
            .update({
              'score': (existing['score'] as num).toDouble() + scoreToAdd,
            })
            .eq('id', existing['id']);
      } else {
        // Criar novo registro
        await _client.from('user_monthly_scores').insert({
          'user_id': currentUserId!,
          'month': month.toIso8601String(),
          'score': scoreToAdd,
        });
      }
    } catch (e) {
      // Não falhar a avaliação se houver erro ao atualizar score
      print('Erro ao atualizar pontuação mensal: $e');
    }
  }
}

