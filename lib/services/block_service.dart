import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import '../utils/logger.dart';
import '../utils/error_handler.dart';
import '../utils/exceptions.dart';

class BlockService {
  final SupabaseService _supabaseService;
  static const String _blockedUsersKey = 'blocked_user_ids';
  Set<String>? _cachedBlockedIds;

  BlockService(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;

  String? get currentUserId => _supabaseService.currentUser?.id;

  /// Bloqueia um usuário
  Future<void> blockUser({
    required String blockedUserId,
    String? reason,
    String? contextPhotoId,
  }) async {
    try {
      if (currentUserId == null) {
        throw Exception('Usuário não autenticado');
      }

      if (currentUserId == blockedUserId) {
        throw Exception('Você não pode bloquear a si mesmo');
      }

      // Inserir bloqueio no Supabase
      await _client.from('user_blocks').insert({
        'blocker_id': currentUserId!,
        'blocked_id': blockedUserId,
        'reason': reason,
        'context_photo_id': contextPhotoId,
      });

      // Atualizar cache local
      await _updateLocalCache(blockedUserId, add: true);

      Logger.info('Usuário bloqueado com sucesso: $blockedUserId');
    } catch (e, stackTrace) {
      Logger.error('Erro ao bloquear usuário', e, stackTrace);
      throw _handleError(e);
    }
  }

  /// Desbloqueia um usuário
  Future<void> unblockUser(String blockedUserId) async {
    try {
      if (currentUserId == null) {
        throw Exception('Usuário não autenticado');
      }

      // Remover bloqueio do Supabase
      await _client
          .from('user_blocks')
          .delete()
          .eq('blocker_id', currentUserId!)
          .eq('blocked_id', blockedUserId);

      // Atualizar cache local
      await _updateLocalCache(blockedUserId, add: false);

      Logger.info('Usuário desbloqueado com sucesso: $blockedUserId');
    } catch (e, stackTrace) {
      Logger.error('Erro ao desbloquear usuário', e, stackTrace);
      throw _handleError(e);
    }
  }

  /// Obtém o conjunto de IDs de usuários bloqueados
  Future<Set<String>> getBlockedUserIds() async {
    try {
      if (currentUserId == null) {
        return <String>{};
      }

      // Se já temos cache em memória, retornar
      if (_cachedBlockedIds != null) {
        return _cachedBlockedIds!;
      }

      // Tentar buscar do Supabase
      try {
        final response = await _client
            .from('user_blocks')
            .select('blocked_id')
            .eq('blocker_id', currentUserId!);

        final blockedIds = (response as List)
            .map((item) => item['blocked_id'] as String)
            .toSet();

        // Atualizar cache local e em memória
        _cachedBlockedIds = blockedIds;
        await _saveToLocalCache(blockedIds);

        return blockedIds;
      } catch (e) {
        // Se falhar, tentar usar cache local
        Logger.warning('Erro ao buscar bloqueios do Supabase, usando cache local', e);
        return await _loadFromLocalCache();
      }
    } catch (e, stackTrace) {
      Logger.error('Erro ao obter IDs bloqueados', e, stackTrace);
      // Em caso de erro, retornar cache local ou conjunto vazio
      return await _loadFromLocalCache();
    }
  }

  /// Obtém lista completa de usuários bloqueados com dados do perfil
  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    try {
      if (currentUserId == null) {
        return [];
      }

      // 1) Buscar registros de bloqueio
      final blocksResponse = await _client
          .from('user_blocks')
          .select('blocked_id, created_at, reason')
          .eq('blocker_id', currentUserId!)
          .order('created_at', ascending: false);

      final blocks = List<Map<String, dynamic>>.from(blocksResponse as List);
      if (blocks.isEmpty) {
        return [];
      }

      // Extrair IDs de usuários bloqueados
      final blockedIds = blocks
          .map((b) => b['blocked_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      if (blockedIds.isEmpty) {
        return [];
      }

      // 2) Buscar dados dos usuários na tabela public.users
      final usersResponse = await _client
          .from('users')
          .select('id, username, avatar_url')
          .inFilter('id', blockedIds);

      final users = List<Map<String, dynamic>>.from(usersResponse as List);
      final usersById = <String, Map<String, dynamic>>{};
      for (final u in users) {
        final id = u['id'] as String?;
        if (id != null) {
          usersById[id] = u;
        }
      }

      // 3) Juntar dados de bloqueio + usuário
      final blockedUsers = <Map<String, dynamic>>[];
      for (final block in blocks) {
        final blockedId = block['blocked_id'] as String?;
        if (blockedId == null) continue;

        final userData = usersById[blockedId];

        blockedUsers.add({
          'blocked_id': blockedId,
          'username': userData?['username'] as String?,
          'avatar_url': userData?['avatar_url'] as String?,
          'created_at': block['created_at'] as String?,
          'reason': block['reason'] as String?,
        });
      }

      return blockedUsers;
    } catch (e, stackTrace) {
      Logger.error('Erro ao obter usuários bloqueados', e, stackTrace);
      // Em caso de erro, retornar lista vazia
      return [];
    }
  }

  /// Verifica se um usuário está bloqueado
  Future<bool> isUserBlocked(String userId) async {
    if (currentUserId == null || userId == currentUserId) {
      return false;
    }

    final blockedIds = await getBlockedUserIds();
    return blockedIds.contains(userId);
  }

  /// Carrega bloqueios do cache local
  Future<Set<String>> _loadFromLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final blockedIdsJson = prefs.getStringList(_blockedUsersKey);
      
      if (blockedIdsJson == null) {
        return <String>{};
      }

      final blockedIds = blockedIdsJson.toSet();
      _cachedBlockedIds = blockedIds;
      return blockedIds;
    } catch (e) {
      Logger.warning('Erro ao carregar bloqueios do cache local', e);
      return <String>{};
    }
  }

  /// Salva bloqueios no cache local
  Future<void> _saveToLocalCache(Set<String> blockedIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_blockedUsersKey, blockedIds.toList());
    } catch (e) {
      Logger.warning('Erro ao salvar bloqueios no cache local', e);
    }
  }

  /// Atualiza o cache local adicionando ou removendo um ID
  Future<void> _updateLocalCache(String userId, {required bool add}) async {
    try {
      final blockedIds = await getBlockedUserIds();
      
      if (add) {
        blockedIds.add(userId);
      } else {
        blockedIds.remove(userId);
      }

      _cachedBlockedIds = blockedIds;
      await _saveToLocalCache(blockedIds);
    } catch (e) {
      Logger.warning('Erro ao atualizar cache local de bloqueios', e);
    }
  }

  /// Limpa o cache (útil para logout)
  Future<void> clearCache() async {
    _cachedBlockedIds = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_blockedUsersKey);
    } catch (e) {
      Logger.warning('Erro ao limpar cache de bloqueios', e);
    }
  }

  /// Recarrega os bloqueios do Supabase (força refresh)
  Future<void> refreshBlockedUsers() async {
    _cachedBlockedIds = null;
    await getBlockedUserIds();
  }

  AppException _handleError(dynamic error) {
    return ErrorHandler.handleError(error);
  }
}

