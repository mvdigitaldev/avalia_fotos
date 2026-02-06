import '../models/photo_model.dart';

/// PR7: Cache do feed em memória com TTL.
/// Ao voltar para a tela do feed, evita refetch da primeira página se o cache for válido.
class FeedCache {
  FeedCache._();
  static final FeedCache instance = FeedCache._();

  static const Duration ttl = Duration(minutes: 5);

  List<PhotoModel>? _photos;
  int _currentPage = 0;
  bool _hasMore = true;
  DateTime? _lastFetched;
  String? _userId;

  /// Retorna true se existe cache válido para o usuário (mesmo userId e dentro do TTL).
  bool hasValidCache(String? userId) {
    if (userId == null || userId.isEmpty) return false;
    if (_photos == null || _lastFetched == null || _userId != userId) return false;
    return DateTime.now().difference(_lastFetched!) < ttl;
  }

  /// Restaura estado do cache. Retorna null se cache inválido.
  FeedCacheSnapshot? restore(String? userId) {
    if (!hasValidCache(userId)) return null;
    return FeedCacheSnapshot(
      List<PhotoModel>.from(_photos!),
      _currentPage,
      _hasMore,
    );
  }

  /// Salva estado atual no cache (após _loadFeed com sucesso).
  void save(String? userId, List<PhotoModel> photos, int currentPage, bool hasMore) {
    if (userId == null || userId.isEmpty) return;
    _photos = List<PhotoModel>.from(photos);
    _currentPage = currentPage;
    _hasMore = hasMore;
    _lastFetched = DateTime.now();
    _userId = userId;
  }

  /// Invalida o cache (ex.: pull-to-refresh ou botão Atualizar).
  void clear() {
    _photos = null;
    _currentPage = 0;
    _hasMore = true;
    _lastFetched = null;
    _userId = null;
  }
}

class FeedCacheSnapshot {
  final List<PhotoModel> photos;
  final int currentPage;
  final bool hasMore;

  FeedCacheSnapshot(this.photos, this.currentPage, this.hasMore);
}
