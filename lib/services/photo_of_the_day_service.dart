// lib/services/photo_of_the_day_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'supabase_service.dart';
import '../models/photo_of_the_day_model.dart';
import '../models/photo_model.dart';
import '../utils/logger.dart';

class PhotoOfTheDayService {
  final SupabaseService _supabaseService;

  PhotoOfTheDayService(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;

  /// Busca a foto do dia de uma data específica
  Future<PhotoOfTheDayModel?> getPhotoOfTheDay(DateTime date) async {
    try {
      final dateStr = _formatDate(date);
      final response = await _client.rpc(
        'get_photo_of_the_day',
        params: {'p_date': dateStr},
      );

      if (response == null || (response as List).isEmpty) {
        return null;
      }

      final data = (response as List).first as Map<String, dynamic>;
      return PhotoOfTheDayModel.fromJson(data);
    } catch (e, stackTrace) {
      Logger.error('Erro ao buscar foto do dia', e, stackTrace);
      return null;
    }
  }

  /// Busca todas as fotos do dia de um mês/ano para o calendário
  Future<Map<DateTime, String>> getPhotosOfTheDayCalendar(
    int year,
    int month,
  ) async {
    try {
      final response = await _client.rpc(
        'get_photos_of_the_day_calendar',
        params: {
          'p_year': year,
          'p_month': month,
        },
      );

      final Map<DateTime, String> result = {};

      if (response != null && response is List) {
        for (final item in response) {
          final data = item as Map<String, dynamic>;
          final dateStr = data['selected_date'] as String;
          final photoId = data['photo_id'] as String;
          final date = DateTime.parse(dateStr);
          result[date] = photoId;
        }
      }

      return result;
    } catch (e, stackTrace) {
      Logger.error('Erro ao buscar calendário de fotos do dia', e, stackTrace);
      return {};
    }
  }

  /// Seleciona uma foto como foto do dia (apenas para ADM)
  Future<String> selectPhotoOfTheDay(String photoId, DateTime date) async {
    try {
      final dateStr = _formatDate(date);
      final response = await _client.rpc(
        'select_photo_of_the_day',
        params: {
          'p_photo_id': photoId,
          'p_date': dateStr,
        },
      );

      // Enviar notificação push para todos os usuários
      try {
        await _sendPhotoOfDayNotification(photoId, date);
      } catch (e, stackTrace) {
        // Não falhar a seleção se a notificação falhar
        Logger.warning('Erro ao enviar notificação push', e, stackTrace);
      }

      return response.toString();
    } catch (e, stackTrace) {
      Logger.error('Erro ao selecionar foto do dia', e, stackTrace);
      rethrow;
    }
  }

  /// Envia notificação push para todos os usuários sobre a foto do dia
  Future<void> _sendPhotoOfDayNotification(String photoId, DateTime date) async {
    try {
      final dateFormatted = DateFormat('dd/MM/yyyy', 'pt_BR').format(date);
      final dateStr = _formatDate(date);
      
      // Chamar Edge Function para enviar notificação
      await _client.functions.invoke(
        'send-push-notification',
        body: {
          'type': 'photo_of_the_day',
          'title': 'Nova Foto do Dia! 🏆',
          'body': 'A foto do dia de $dateFormatted foi selecionada! Clique para ver qual foi a foto premiada.',
          'data': {
            'type': 'photo_of_the_day',
            'photo_id': photoId,
            'date': dateStr,
            'deep_link': '/premiacoes?date=$dateStr',
          },
          'broadcast': true, // Enviar para todos os usuários
        },
      );

      Logger.info('Notificação push enviada para foto do dia: $photoId');
    } catch (e, stackTrace) {
      Logger.error('Erro ao enviar notificação push de foto do dia', e, stackTrace);
      rethrow;
    }
  }

  /// Verifica se pode desfazer a seleção de uma data
  Future<bool> canUndoSelection(DateTime date) async {
    try {
      final photoOfDay = await getPhotoOfTheDay(date);
      return photoOfDay != null;
    } catch (e, stackTrace) {
      Logger.error('Erro ao verificar se pode desfazer seleção', e, stackTrace);
      return false;
    }
  }

  /// Remove a foto do dia de uma data específica (apenas para ADM)
  Future<void> removePhotoOfTheDay(DateTime date) async {
    try {
      final dateStr = _formatDate(date);
      await _client
          .from('photo_of_the_day')
          .delete()
          .eq('selected_date', dateStr);
    } catch (e, stackTrace) {
      Logger.error('Erro ao remover foto do dia', e, stackTrace);
      rethrow;
    }
  }

  /// Verifica se uma foto é a foto do dia de uma data específica
  Future<bool> isPhotoOfTheDay(String photoId, DateTime date) async {
    try {
      final photoOfDay = await getPhotoOfTheDay(date);
      return photoOfDay?.photoId == photoId;
    } catch (e, stackTrace) {
      Logger.error('Erro ao verificar se foto é do dia', e, stackTrace);
      return false;
    }
  }

  /// Busca fotos candidatas para uma data (fotos compartilhadas de usuários com plano pago)
  Future<List<PhotoModel>> getCandidatePhotos(DateTime date) async {
    try {
      // Buscar fotos publicadas na data selecionada
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

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
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .order('score', ascending: false);

      final photos = <PhotoModel>[];

      for (final item in response) {
        final photo = PhotoModel.fromJson(item);
        
        // Verificar se o usuário tem plano pago ativo
        final hasPaidPlan = await _checkUserHasPaidPlan(photo.userId);
        if (hasPaidPlan) {
          photos.add(photo);
        }
      }

      return photos;
    } catch (e, stackTrace) {
      Logger.error('Erro ao buscar fotos candidatas', e, stackTrace);
      return [];
    }
  }

  /// Verifica se um usuário tem plano pago ativo
  Future<bool> _checkUserHasPaidPlan(String userId) async {
    try {
      final response = await _client
          .from('user_plans')
          .select('''
            *,
            plans:plan_id (
              price
            )
          ''')
          .eq('user_id', userId)
          .eq('is_active', true)
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return false;

      // Verificar se o plano não expirou
      final expiresAt = response['expires_at'] as String?;
      if (expiresAt != null) {
        final expiryDate = DateTime.parse(expiresAt);
        if (expiryDate.isBefore(DateTime.now())) {
          return false;
        }
      }

      final planData = response['plans'];
      if (planData == null) return false;

      // Se planData é uma lista, pegar o primeiro item
      Map<String, dynamic> plan;
      if (planData is List && planData.isNotEmpty) {
        plan = planData.first as Map<String, dynamic>;
      } else if (planData is Map) {
        plan = planData as Map<String, dynamic>;
      } else {
        return false;
      }

      final price = plan['price'];
      if (price == null) return false;

      // Converter para num e verificar se é maior que 0
      final priceNum = price is String ? double.tryParse(price) : (price as num?)?.toDouble();
      return priceNum != null && priceNum > 0;
    } catch (e) {
      Logger.debug('Erro ao verificar plano pago: $e');
      return false;
    }
  }

  /// Formata data para formato YYYY-MM-DD
  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

