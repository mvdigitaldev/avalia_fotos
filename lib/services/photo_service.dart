import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'storage_service.dart';
import 'block_service.dart';
import '../models/photo_model.dart';
import '../utils/logger.dart';
import '../utils/error_handler.dart';
import '../utils/exceptions.dart';

class PhotoService {
  final SupabaseService _supabaseService;
  BlockService? _blockService;

  PhotoService(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;

  String? get currentUserId => _supabaseService.currentUser?.id;

  /// Define o BlockService para filtrar usuários bloqueados
  void setBlockService(BlockService blockService) {
    _blockService = blockService;
  }

  Future<List<PhotoModel>> getFeedPhotos({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Obter IDs de usuários bloqueados (se houver BlockService)
      Set<String> blockedUserIds = {};
      if (_blockService != null && currentUserId != null) {
        try {
          blockedUserIds = await _blockService!.getBlockedUserIds();
        } catch (e) {
          Logger.warning('Erro ao obter usuários bloqueados, continuando sem filtro', e);
        }
      }

      // View feed_photos: select mínimo + is_photo_of_the_day (zero request extra por item)
      var query = _client
          .from('feed_photos')
          .select('''
            id,
            user_id,
            image_url,
            thumbnail_url,
            score,
            recado,
            is_shared,
            likes_count,
            comments_count,
            created_at,
            updated_at,
            categoria,
            is_photo_of_the_day,
            users:user_id (
              username,
              avatar_url
            )
          ''');

      // Filtrar usuários bloqueados usando NOT IN (se houver bloqueios)
      if (blockedUserIds.isNotEmpty && currentUserId != null) {
        // Usar uma subquery para filtrar fotos de usuários bloqueados
        // Como o Supabase não suporta NOT IN diretamente com subquery, vamos filtrar em memória
        // Mas primeiro vamos tentar usar uma abordagem com NOT EXISTS via RPC ou filtrar depois
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final photos = <PhotoModel>[];
      final photoIds = <String>[];

      // Extrair IDs das fotos para buscar likes em batch
      for (final item in response) {
        try {
          final photoId = item['id'] as String?;
          if (photoId != null) {
            photoIds.add(photoId);
          }
        } catch (e, stackTrace) {
          Logger.debug('Erro ao extrair ID da foto', e, stackTrace);
        }
      }

      // Buscar status de plano pago dos autores das fotos
      final feedUserIds = (response as List)
          .map((item) => item['user_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      Map<String, bool> paidPlanStatus = {};
      if (feedUserIds.isNotEmpty) {
        try {
          final paidResponse = await _client.rpc(
            'get_users_paid_plan_status',
            params: {'p_user_ids': feedUserIds},
          );
          if (paidResponse != null && paidResponse is List) {
            for (final item in paidResponse) {
              if (item is Map<String, dynamic>) {
                final uid = item['user_id'] as String?;
                final hasPaid = item['has_paid_plan'] as bool? ?? false;
                if (uid != null) paidPlanStatus[uid] = hasPaid;
              }
            }
          }
        } catch (e) {
          Logger.debug('Erro ao buscar status de plano pago: $e');
        }
      }

      // Buscar todos os likes do usuário atual em uma única query (otimização N+1)
      Set<String> likedPhotoIds = {};
      if (currentUserId != null && photoIds.isNotEmpty) {
        try {
          final likesResponse = await _client
              .from('likes')
              .select('photo_id')
              .eq('user_id', currentUserId!)
              .inFilter('photo_id', photoIds);

          likedPhotoIds = (likesResponse as List)
              .map((like) => like['photo_id'] as String)
              .toSet();
        } catch (e, stackTrace) {
          Logger.warning('Erro ao buscar likes em batch', e, stackTrace);
          // Continua sem informações de likes se houver erro
        }
      }

      // Processar fotos com informações de likes já disponíveis
      for (final item in response) {
        try {
          final userData = item['users'] as Map<String, dynamic>?;
          final photo = PhotoModel.fromJson(item);
          
          // Filtrar usuários bloqueados em memória
          if (blockedUserIds.contains(photo.userId)) {
            continue; // Pular fotos de usuários bloqueados
          }
          
          // Verificar se o usuário curtiu usando o Set pré-carregado
          final isLiked = currentUserId != null && likedPhotoIds.contains(photo.id);
          final hasPaidPlan = paidPlanStatus[photo.userId] ?? false;

          photos.add(photo.copyWith(
            username: userData?['username'] as String?,
            userAvatarUrl: userData?['avatar_url'] as String?,
            isLiked: isLiked,
            hasPaidPlan: hasPaidPlan,
          ));
        } catch (e, stackTrace) {
          Logger.warning('Erro ao processar foto', e, stackTrace);
          // Continua processando outras fotos mesmo se uma falhar
        }
      }

      return photos;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<PhotoModel>> getUserPhotos({
    required String userId,
    int limit = 20,
    int offset = 0,
    bool? isShared,
    bool skipBlockCheck = false,
  }) async {
    try {
      // Verificar se o usuário está bloqueado (exceto para admin)
      if (!skipBlockCheck && _blockService != null && currentUserId != null) {
        final isBlocked = await _blockService!.isUserBlocked(userId);
        if (isBlocked) {
          return <PhotoModel>[];
        }
      }

      var query = _client
          .from('photos')
          .select('''
            *,
            users:user_id (
              username,
              avatar_url
            )
          ''')
          .eq('user_id', userId);

      if (isShared != null) {
        query = query.eq('is_shared', isShared);
      }

      final response = await query
          .order('created_at', ascending: false)
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

  Future<PhotoModel> getPhotoById(String photoId) async {
    try {
      final response = await _client
          .from('photos')
          .select('''
            *,
            users:user_id (
              username,
              avatar_url
            )
          ''')
          .eq('id', photoId)
          .single();

      final userData = response['users'] as Map<String, dynamic>?;
      return PhotoModel.fromJson(response).copyWith(
        username: userData?['username'] as String?,
        userAvatarUrl: userData?['avatar_url'] as String?,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> toggleLike(String photoId) async {
    try {
      if (currentUserId == null) {
        throw Exception('Usuário não autenticado');
      }

      // Tentar usar função RPC otimizada primeiro
      try {
        final result = await _client.rpc(
          'toggle_photo_like',
          params: {
            'p_photo_id': photoId,
            'p_user_id': currentUserId!,
          },
        );
        
        // Função RPC retorna JSON com resultado
        // Não precisamos fazer nada aqui, a UI já foi atualizada otimisticamente
        Logger.debug('Like toggled via RPC: $result');
      } catch (rpcError) {
        // Se a função RPC não existir ainda, usar método antigo como fallback
        Logger.warning('RPC toggle_photo_like não disponível, usando método antigo: $rpcError');
        
        // Verificar se já curtiu
        final existingLike = await _client
            .from('likes')
            .select('id')
            .eq('photo_id', photoId)
            .eq('user_id', currentUserId!)
            .maybeSingle();

        if (existingLike != null) {
          // Remover like
          await _client.from('likes').delete().eq('id', existingLike['id']);
          await _client.rpc('decrement_likes_count', params: {'p_photo_id': photoId});
        } else {
          // Adicionar like
          await _client.from('likes').insert({
            'photo_id': photoId,
            'user_id': currentUserId!,
          });
          await _client.rpc('increment_likes_count', params: {'p_photo_id': photoId});
        }
      }
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> addComment({
    required String photoId,
    required String content,
  }) async {
    try {
      if (currentUserId == null) {
        throw Exception('Usuário não autenticado');
      }

      await _client.from('comments').insert({
        'photo_id': photoId,
        'user_id': currentUserId!,
        'content': content,
      });

      await _client.rpc('increment_comments_count', params: {'p_photo_id': photoId});
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getComments(String photoId) async {
    try {
      final response = await _client
          .from('comments')
          .select('''
            *,
            users:user_id (
              username,
              avatar_url
            )
          ''')
          .eq('photo_id', photoId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> deleteComment(String commentId, String photoId) async {
    try {
      if (currentUserId == null) {
        throw Exception('Usuário não autenticado');
      }

      await _client.from('comments').delete().eq('id', commentId);

      await _client.rpc('decrement_comments_count', params: {'p_photo_id': photoId});
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updatePhotoShareStatus({
    required String photoId,
    required bool isShared,
  }) async {
    try {
      await _client
          .from('photos')
          .update({'is_shared': isShared})
          .eq('id', photoId);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<int> getUserPhotosCount({String? userId, bool? isShared}) async {
    try {
      final targetUserId = userId ?? currentUserId;
      if (targetUserId == null) return 0;

      // Buscar todas as fotos sem limit para contar
      var query = _client
          .from('photos')
          .select('id')
          .eq('user_id', targetUserId);

      if (isShared != null) {
        query = query.eq('is_shared', isShared);
      }

      final response = await query;
      return response.length;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Busca fotos compartilhadas de um usuário específico (para perfil público)
  Future<List<PhotoModel>> getUserSharedPhotos({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    return getUserPhotos(
      userId: userId,
      limit: limit,
      offset: offset,
      isShared: true, // Apenas fotos compartilhadas
    );
  }

  /// Conta total de fotos compartilhadas de um usuário
  Future<int> getUserSharedPhotosCount(String userId) async {
    return getUserPhotosCount(userId: userId, isShared: true);
  }

  Future<int> getUserStorageCount() async {
    try {
      if (currentUserId == null) return 0;

      // Buscar todas as fotos do usuário e contar
      final response = await _client
          .from('photos')
          .select('id')
          .eq('user_id', currentUserId!);

      // Converter para lista e contar
      final photosList = response as List;
      return photosList.length;
    } catch (e, stackTrace) {
      Logger.error('Erro ao contar fotos armazenadas', e, stackTrace);
      throw _handleError(e);
    }
  }

  Future<List<String>> deletePhotos(List<String> photoIds) async {
    try {
      if (currentUserId == null) {
        throw Exception('Usuário não autenticado');
      }

      // Buscar URLs das imagens antes de deletar
      final photosResponse = await _client
          .from('photos')
          .select('id, image_url')
          .inFilter('id', photoIds)
          .eq('user_id', currentUserId!); // Garantir que só deleta fotos do usuário atual

      final imageUrls = <String>[];
      final validPhotoIds = <String>[];

      for (final photo in photosResponse) {
        final photoId = photo['id'] as String;
        final imageUrl = photo['image_url'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          imageUrls.add(imageUrl);
          validPhotoIds.add(photoId);
        }
      }

      if (validPhotoIds.isEmpty) {
        return [];
      }

      // Deletar do Storage primeiro
      final storageService = StorageService(_supabaseService);
      final deletedUrls = await storageService.deleteMultiplePhotos(imageUrls);

      // Mapear URLs deletadas para IDs
      final deletedPhotoIds = <String>[];
      for (int i = 0; i < imageUrls.length; i++) {
        if (deletedUrls.contains(imageUrls[i])) {
          deletedPhotoIds.add(validPhotoIds[i]);
        }
      }

      // Deletar do banco de dados apenas as que foram deletadas do Storage
      if (deletedPhotoIds.isNotEmpty) {
        await _client.from('photos').delete().inFilter('id', deletedPhotoIds);
      }

      return deletedPhotoIds;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Exclui fotos por IDs (apenas para admin). Não verifica user_id.
  Future<List<String>> deletePhotosAsAdmin(List<String> photoIds) async {
    try {
      if (currentUserId == null) {
        throw Exception('Usuário não autenticado');
      }
      if (photoIds.isEmpty) return [];

      final photosResponse = await _client
          .from('photos')
          .select('id, image_url')
          .inFilter('id', photoIds);

      final imageUrls = <String>[];
      final validPhotoIds = <String>[];

      for (final photo in photosResponse) {
        final photoId = photo['id'] as String;
        final imageUrl = photo['image_url'] as String?;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          imageUrls.add(imageUrl);
          validPhotoIds.add(photoId);
        }
      }

      if (validPhotoIds.isEmpty) return [];

      final storageService = StorageService(_supabaseService);
      final deletedUrls = await storageService.deleteMultiplePhotos(imageUrls);

      final deletedPhotoIds = <String>[];
      for (int i = 0; i < imageUrls.length; i++) {
        if (deletedUrls.contains(imageUrls[i])) {
          deletedPhotoIds.add(validPhotoIds[i]);
        }
      }

      if (deletedPhotoIds.isNotEmpty) {
        await _client.from('photos').delete().inFilter('id', deletedPhotoIds);
      }

      return deletedPhotoIds;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<PhotoModel>> getFilteredSharedPhotos({
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minScore,
    String? categoria,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Obter IDs de usuários bloqueados (se houver BlockService)
      Set<String> blockedUserIds = {};
      if (_blockService != null && currentUserId != null) {
        try {
          blockedUserIds = await _blockService!.getBlockedUserIds();
        } catch (e) {
          Logger.warning('Erro ao obter usuários bloqueados, continuando sem filtro', e);
        }
      }

      // Construir query base sempre filtrando por is_shared = true
      var query = _client
          .from('photos')
          .select('''
            *,
            users:user_id (
              username,
              avatar_url
            )
          ''')
          .eq('is_shared', true);

      // Aplicar filtros dinamicamente
      if (dateFrom != null) {
        query = query.gte('created_at', dateFrom.toIso8601String());
      }

      if (dateTo != null) {
        // Adicionar 1 dia para incluir o dia inteiro
        final dateToEnd = DateTime(dateTo.year, dateTo.month, dateTo.day, 23, 59, 59);
        query = query.lte('created_at', dateToEnd.toIso8601String());
      }

      if (minScore != null) {
        query = query.gte('score', minScore);
      }

      if (categoria != null && categoria.isNotEmpty) {
        query = query.eq('categoria', categoria);
      }

      // Ordenar por data de criação (mais recentes primeiro) e aplicar paginação
      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final photos = <PhotoModel>[];
      final photoIds = <String>[];

      // Extrair IDs das fotos para buscar likes em batch
      for (final item in response) {
        try {
          final photoId = item['id'] as String?;
          if (photoId != null) {
            photoIds.add(photoId);
          }
        } catch (e, stackTrace) {
          Logger.debug('Erro ao extrair ID da foto', e, stackTrace);
        }
      }

      // Buscar todos os likes do usuário atual em uma única query (otimização N+1)
      Set<String> likedPhotoIds = {};
      if (currentUserId != null && photoIds.isNotEmpty) {
        try {
          final likesResponse = await _client
              .from('likes')
              .select('photo_id')
              .eq('user_id', currentUserId!)
              .inFilter('photo_id', photoIds);

          likedPhotoIds = (likesResponse as List)
              .map((like) => like['photo_id'] as String)
              .toSet();
        } catch (e, stackTrace) {
          Logger.warning('Erro ao buscar likes em batch', e, stackTrace);
          // Continua sem informações de likes se houver erro
        }
      }

      // Processar fotos com informações de likes já disponíveis
      for (final item in response) {
        try {
          final userData = item['users'] as Map<String, dynamic>?;
          final photo = PhotoModel.fromJson(item);
          
          // Filtrar usuários bloqueados em memória
          if (blockedUserIds.contains(photo.userId)) {
            continue; // Pular fotos de usuários bloqueados
          }
          
          // Verificar se o usuário curtiu usando o Set pré-carregado
          final isLiked = currentUserId != null && likedPhotoIds.contains(photo.id);

          photos.add(photo.copyWith(
            username: userData?['username'] as String?,
            userAvatarUrl: userData?['avatar_url'] as String?,
            isLiked: isLiked,
          ));
        } catch (e, stackTrace) {
          Logger.warning('Erro ao processar foto', e, stackTrace);
          // Continua processando outras fotos mesmo se uma falhar
        }
      }

      return photos;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Fotos por categoria (score > 9, ordenadas por data, paginadas)
  Future<List<PhotoModel>> getPhotosByCategory({
    required String categoria,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      Set<String> blockedUserIds = {};
      if (_blockService != null && currentUserId != null) {
        try {
          blockedUserIds = await _blockService!.getBlockedUserIds();
        } catch (e) {
          Logger.warning('Erro ao obter usuários bloqueados, continuando sem filtro', e);
        }
      }

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
          .eq('categoria', categoria)
          .gt('score', 9)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final photoIds = <String>[];
      for (final item in response) {
        final photoId = item['id'] as String?;
        if (photoId != null) photoIds.add(photoId);
      }

      Set<String> likedPhotoIds = {};
      if (currentUserId != null && photoIds.isNotEmpty) {
        try {
          final likesResponse = await _client
              .from('likes')
              .select('photo_id')
              .eq('user_id', currentUserId!)
              .inFilter('photo_id', photoIds);
          likedPhotoIds = (likesResponse as List)
              .map((like) => like['photo_id'] as String)
              .toSet();
        } catch (e) {
          Logger.debug('Erro ao buscar likes: $e');
        }
      }

      final photos = <PhotoModel>[];
      for (final item in response) {
        try {
          final userData = item['users'] as Map<String, dynamic>?;
          final photo = PhotoModel.fromJson(item);
          if (blockedUserIds.contains(photo.userId)) continue;
          final isLiked = currentUserId != null && likedPhotoIds.contains(photo.id);
          photos.add(photo.copyWith(
            username: userData?['username'] as String?,
            userAvatarUrl: userData?['avatar_url'] as String?,
            isLiked: isLiked,
          ));
        } catch (e, stackTrace) {
          Logger.warning('Erro ao processar foto', e, stackTrace);
        }
      }
      return photos;
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<String>> getAvailableCategories() async {
    try {
      // Buscar categorias distintas de fotos compartilhadas com score > 9
      final response = await _client
          .from('photos')
          .select('categoria')
          .eq('is_shared', true)
          .gt('score', 9)
          .not('categoria', 'is', null);

      // Extrair categorias únicas e ordenar alfabeticamente
      final categoriesSet = <String>{};
      for (final item in response) {
        final categoria = item['categoria'] as String?;
        if (categoria != null && categoria.isNotEmpty) {
          categoriesSet.add(categoria);
        }
      }

      final categoriesList = categoriesSet.toList()..sort();
      return categoriesList;
    } catch (e) {
      throw _handleError(e);
    }
  }

  AppException _handleError(dynamic error) {
    return ErrorHandler.handleError(error);
  }
}

