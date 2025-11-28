import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'storage_service.dart';
import '../models/photo_model.dart';
import '../utils/logger.dart';
import '../utils/error_handler.dart';
import '../utils/exceptions.dart';

class PhotoService {
  final SupabaseService _supabaseService;

  PhotoService(this._supabaseService);

  SupabaseClient get _client => _supabaseService.client;

  String? get currentUserId => _supabaseService.currentUser?.id;

  Future<List<PhotoModel>> getFeedPhotos({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Buscar fotos compartilhadas com informações do usuário
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

  Future<List<PhotoModel>> getUserPhotos({
    required String userId,
    int limit = 20,
    int offset = 0,
    bool? isShared,
  }) async {
    try {
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

  Future<int> getUserPhotosCount({bool? isShared}) async {
    try {
      if (currentUserId == null) return 0;

      // Buscar todas as fotos sem limit para contar
      var query = _client
          .from('photos')
          .select('id')
          .eq('user_id', currentUserId!);

      if (isShared != null) {
        query = query.eq('is_shared', isShared);
      }

      final response = await query;
      return response.length;
    } catch (e) {
      throw _handleError(e);
    }
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

  Future<List<PhotoModel>> getFilteredSharedPhotos({
    DateTime? dateFrom,
    DateTime? dateTo,
    double? minScore,
    String? categoria,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
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

  Future<List<String>> getAvailableCategories() async {
    try {
      // Buscar categorias distintas de fotos compartilhadas
      final response = await _client
          .from('photos')
          .select('categoria')
          .eq('is_shared', true)
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

