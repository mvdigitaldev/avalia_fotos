import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/achievement_model.dart';
import '../utils/logger.dart';
import 'supabase_service.dart';

class AchievementService {
  final SupabaseService _supabaseService;

  AchievementService(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;
  String? get currentUserId => _supabaseService.currentUser?.id;

  /// Busca todas as conquistas disponíveis
  Future<List<AchievementModel>> getAllAchievements() async {
    try {
      final response = await _client
          .from('achievements')
          .select()
          .order('created_at', ascending: true);

      if (response == null) {
        return [];
      }

      final achievementsList = response as List<dynamic>;
      
      // Buscar conquistas desbloqueadas do usuário atual
      final unlockedIds = await getUnlockedAchievementIds(currentUserId ?? '');
      final unlockedAtMap = await getUnlockedAtMap(currentUserId ?? '');

      return achievementsList.map((json) {
        return AchievementModel.fromJson(
          json as Map<String, dynamic>,
          unlockedAchievementIds: unlockedIds,
          unlockedAtMap: unlockedAtMap,
        );
      }).toList();
    } catch (e, stackTrace) {
      Logger.error('Erro ao buscar conquistas', e, stackTrace);
      throw Exception('Erro ao buscar conquistas: $e');
    }
  }

  /// Busca conquistas desbloqueadas pelo usuário atual
  Future<List<AchievementModel>> getUserAchievements() async {
    try {
      if (currentUserId == null) {
        return [];
      }

      final response = await _client
          .from('user_achievements')
          .select('''
            id,
            unlocked_at,
            achievements:achievement_id (
              id,
              title,
              description,
              img,
              requirement,
              created_at,
              updated_at
            )
          ''')
          .eq('user_id', currentUserId!)
          .order('unlocked_at', ascending: false);

      if (response == null) {
        return [];
      }

      final achievementsList = response as List<dynamic>;
      return achievementsList.map((json) {
        final achievementData = json['achievements'] as Map<String, dynamic>;
        final unlockedAt = DateTime.parse(json['unlocked_at'] as String);
        
        return AchievementModel.fromJson(
          achievementData,
          unlockedAchievementIds: {achievementData['id'] as String},
          unlockedAtMap: {achievementData['id'] as String: unlockedAt},
        );
      }).toList();
    } catch (e, stackTrace) {
      Logger.error('Erro ao buscar conquistas do usuário', e, stackTrace);
      throw Exception('Erro ao buscar conquistas do usuário: $e');
    }
  }

  /// Verifica e desbloqueia conquistas para o usuário
  /// Retorna lista de conquistas recém-desbloqueadas
  Future<List<AchievementModel>> checkAndUnlockAchievements(String userId) async {
    try {
      Logger.debug('Chamando RPC check_and_unlock_achievements para userId: $userId');
      
      // Chamar função RPC no banco
      final response = await _client.rpc(
        'check_and_unlock_achievements',
        params: {'p_user_id': userId},
      );

      Logger.debug('Resposta da RPC: $response');
      Logger.debug('Tipo da resposta: ${response.runtimeType}');

      if (response == null) {
        Logger.debug('Resposta da RPC é null');
        return [];
      }

      // A função RPC retorna um JSONB array
      // Pode vir como List ou como String JSON que precisa ser parseado
      List<dynamic> unlockedList;
      
      if (response is List) {
        unlockedList = response;
        Logger.debug('Resposta é uma List com ${unlockedList.length} itens');
      } else if (response is String) {
        // Se vier como string JSON, fazer parse
        Logger.debug('Resposta é uma String, fazendo parse...');
        try {
          final decoded = jsonDecode(response);
          unlockedList = decoded is List ? decoded : [decoded];
          Logger.debug('Após parse: ${unlockedList.length} itens');
        } catch (e, stackTrace) {
          Logger.warning('Erro ao fazer parse da string JSON', e, stackTrace);
          unlockedList = [];
        }
      } else if (response is Map) {
        // Se vier como Map, pode ser um objeto único ou um wrapper
        Logger.debug('Resposta é um Map, convertendo para lista...');
        unlockedList = [response];
      } else {
        // Tentar converter para List
        Logger.debug('Resposta não é List nem String nem Map, tentando converter...');
        Logger.debug('Tipo: ${response.runtimeType}');
        unlockedList = [response];
      }
      
      if (unlockedList.isEmpty) {
        Logger.debug('Nenhuma conquista desbloqueada');
        return [];
      }
      
      Logger.debug('Processando ${unlockedList.length} conquistas desbloqueadas');
      final now = DateTime.now();
      final achievements = unlockedList.map((json) {
        Map<String, dynamic> achievementData;
        if (json is Map) {
          achievementData = json as Map<String, dynamic>;
        } else {
          // Se não for Map, tentar converter
          achievementData = Map<String, dynamic>.from(json);
        }
        
        final achievementId = achievementData['id'] as String;
        Logger.debug('Processando conquista: ${achievementData['title']} (id: $achievementId)');
        return AchievementModel.fromJson(
          achievementData,
          unlockedAchievementIds: {achievementId},
          unlockedAtMap: {achievementId: now}, // Usar data atual como fallback
        );
      }).toList();
      
      Logger.debug('Retornando ${achievements.length} conquistas');
      return achievements;
    } catch (e, stackTrace) {
      Logger.error('Erro ao verificar conquistas', e, stackTrace);
      // Não lançar exceção para não quebrar o fluxo de avaliação
      return [];
    }
  }

  /// Busca IDs das conquistas desbloqueadas pelo usuário
  Future<Set<String>> getUnlockedAchievementIds(String userId) async {
    try {
      if (userId.isEmpty) {
        return {};
      }

      final response = await _client
          .from('user_achievements')
          .select('achievement_id')
          .eq('user_id', userId);

      if (response == null) {
        return {};
      }

      final achievementsList = response as List<dynamic>;
      return achievementsList
          .map((json) => json['achievement_id'] as String)
          .toSet();
    } catch (e, stackTrace) {
      Logger.error('Erro ao buscar IDs de conquistas desbloqueadas', e, stackTrace);
      return {};
    }
  }

  /// Busca mapa de datas de desbloqueio
  Future<Map<String, DateTime>> getUnlockedAtMap(String userId) async {
    try {
      if (userId.isEmpty) {
        return {};
      }

      final response = await _client
          .from('user_achievements')
          .select('achievement_id, unlocked_at')
          .eq('user_id', userId);

      if (response == null) {
        return {};
      }

      final achievementsList = response as List<dynamic>;
      final map = <String, DateTime>{};
      
      for (final json in achievementsList) {
        final achievementId = json['achievement_id'] as String;
        final unlockedAt = DateTime.parse(json['unlocked_at'] as String);
        map[achievementId] = unlockedAt;
      }
      
      return map;
    } catch (e, stackTrace) {
      Logger.error('Erro ao buscar datas de desbloqueio', e, stackTrace);
      return {};
    }
  }

  /// Busca estatísticas do usuário para calcular progresso
  Future<Map<String, int>> getUserStats(String userId) async {
    try {
      // Contar total de fotos
      final photosResponse = await _client
          .from('photos')
          .select('id')
          .eq('user_id', userId);
      
      final totalPhotos = photosResponse != null 
          ? (photosResponse as List).length 
          : 0;

      // Contar fotos com score > 9
      final highScoreResponse = await _client
          .from('photos')
          .select('id')
          .eq('user_id', userId)
          .gt('score', 9);
      
      final highScorePhotos = highScoreResponse != null
          ? (highScoreResponse as List).length
          : 0;

      return {
        'total_photos': totalPhotos,
        'high_score_photos': highScorePhotos,
      };
    } catch (e, stackTrace) {
      Logger.error('Erro ao buscar estatísticas do usuário', e, stackTrace);
      return {
        'total_photos': 0,
        'high_score_photos': 0,
      };
    }
  }
}

