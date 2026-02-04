// lib/pages/inspirar_categoria/inspirar_categoria_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../services/photo_service.dart';
import '../../services/block_service.dart';
import '../../utils/logger.dart';
import '../../models/photo_model.dart';
import 'inspirar_categoria_model.dart';
export 'inspirar_categoria_model.dart';

class InspirarCategoriaWidget extends StatefulWidget {
  const InspirarCategoriaWidget({super.key});

  static String routeName = 'inspirar_categoria';
  static String routePath = '/inspirar-categoria';

  @override
  State<InspirarCategoriaWidget> createState() => _InspirarCategoriaWidgetState();
}

class _InspirarCategoriaWidgetState extends State<InspirarCategoriaWidget> {
  late InspirarCategoriaModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late PhotoService _photoService;
  bool _servicesInitialized = false;
  final ScrollController _scrollController = ScrollController();

  static final CacheManager _photoCacheManager = CacheManager(
    Config(
      'photoCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 200,
    ),
  );

  String? get _categoria {
    final state = GoRouterState.of(context);
    return state.uri.queryParameters['categoria'];
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => InspirarCategoriaModel());
    _scrollController.addListener(_onScroll);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _photoService = PhotoService(supabaseService);
      _photoService.setBlockService(BlockService(supabaseService));
      setState(() {
        _servicesInitialized = true;
      });
      await _loadPhotos(refresh: true);
    } catch (e, stackTrace) {
      Logger.error('Erro ao inicializar serviços', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar fotos: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _loadPhotos({bool refresh = false}) async {
    if (_model.isLoading || !_servicesInitialized) return;
    final categoria = _categoria;
    if (categoria == null || categoria.isEmpty) return;

    safeSetState(() {
      _model.isLoading = true;
      if (refresh) {
        _model.currentPage = 0;
        _model.photos = [];
        _model.hasMore = true;
      }
    });

    try {
      final newPhotos = await _photoService.getPhotosByCategory(
        categoria: categoria,
        limit: _model.pageSize,
        offset: _model.currentPage * _model.pageSize,
      );

      safeSetState(() {
        if (refresh) {
          _model.photos = newPhotos;
        } else {
          _model.photos.addAll(newPhotos);
        }
        _model.hasMore = newPhotos.length == _model.pageSize;
        _model.currentPage++;
        _model.isLoading = false;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar fotos', e, stackTrace);
      safeSetState(() {
        _model.isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar fotos: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (_model.hasMore && !_model.isLoading) {
        _loadPhotos();
      }
    }
  }

  void _navigateToPhotoDetail(String photoId) {
    context.push('/photo-detail/$photoId');
  }

  Widget _buildPhotoThumbnail(PhotoModel photo) {
    return GestureDetector(
      onTap: () => _navigateToPhotoDetail(photo.id),
      child: Stack(
        children: [
          CachedNetworkImage(
            imageUrl: photo.imageUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            cacheManager: _photoCacheManager,
            placeholder: (context, url) => Container(
              color: FlutterFlowTheme.of(context).alternate,
              child: Center(
                child: CircularProgressIndicator(
                  color: FlutterFlowTheme.of(context).primary,
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: FlutterFlowTheme.of(context).alternate,
              child: Icon(
                Icons.broken_image_outlined,
                color: FlutterFlowTheme.of(context).secondary,
              ),
            ),
          ),
          Positioned(
            bottom: 4,
            left: 4,
            child: Container(
              padding: EdgeInsetsDirectional.fromSTEB(6, 2, 6, 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                photo.score.toStringAsFixed(1),
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      font: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                      ),
                      color: FlutterFlowTheme.of(context).primary,
                      fontSize: 11,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoria = _categoria ?? 'Categoria';

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 24.0,
            ),
            onPressed: () => context.safePop(),
          ),
          title: Text(
            categoria,
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  font: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                  letterSpacing: 0.0,
                ),
          ),
        ),
        body: SafeArea(
          top: true,
          child: RefreshIndicator(
            onRefresh: () => _loadPhotos(refresh: true),
            color: FlutterFlowTheme.of(context).primary,
            child: _model.photos.isEmpty && _model.isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: FlutterFlowTheme.of(context).primary,
                    ),
                  )
                : _model.photos.isEmpty && !_model.isLoading
                    ? SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(20, 40, 20, 40),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.photo_library_outlined,
                                  size: 80,
                                  color: FlutterFlowTheme.of(context).primary.withOpacity(0.5),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(20, 24, 20, 0),
                                  child: Text(
                                    'Nenhuma foto encontrada nesta categoria.',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context).titleMedium.override(
                                          font: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w500,
                                          ),
                                          color: FlutterFlowTheme.of(context).primaryText,
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : GridView.builder(
                        controller: _scrollController,
                        padding: EdgeInsetsDirectional.fromSTEB(2, 2, 2, 2),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _model.photos.length +
                            (_model.isLoading && _model.photos.isNotEmpty ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _model.photos.length) {
                            return Center(
                              child: CircularProgressIndicator(
                                color: FlutterFlowTheme.of(context).primary,
                                strokeWidth: 2,
                              ),
                            );
                          }
                          return _buildPhotoThumbnail(_model.photos[index]);
                        },
                      ),
          ),
        ),
      ),
    );
  }
}
