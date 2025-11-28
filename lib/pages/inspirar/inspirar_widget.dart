// lib/pages/inspirar/inspirar_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../services/photo_service.dart';
import '../../models/photo_model.dart';
import '../../components/inspirar_filters_drawer.dart';
import 'inspirar_model.dart';
export 'inspirar_model.dart';

class InspirarWidget extends StatefulWidget {
  const InspirarWidget({super.key});

  static String routeName = 'inspirar';
  static String routePath = '/inspirar';

  @override
  State<InspirarWidget> createState() => _InspirarWidgetState();
}

class _InspirarWidgetState extends State<InspirarWidget> {
  late InspirarModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late PhotoService _photoService;
  bool _servicesInitialized = false;
  final ScrollController _scrollController = ScrollController();

  // Cache manager customizado para thumbnails
  static final CacheManager _photoCacheManager = CacheManager(
    Config(
      'photoCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 200,
    ),
  );

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => InspirarModel());
    _scrollController.addListener(_onScroll);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _photoService = PhotoService(supabaseService);
      setState(() {
        _servicesInitialized = true;
      });
      await _loadCategories();
      // Não carregar fotos inicialmente - aguardar filtros do usuário
    } catch (e) {
      print('Erro ao inicializar serviços: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao inicializar serviços: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _loadCategories() async {
    try {
      safeSetState(() {
        _model.isLoadingCategories = true;
      });
      final categories = await _photoService.getAvailableCategories();
      safeSetState(() {
        _model.availableCategories = categories;
        _model.isLoadingCategories = false;
      });
    } catch (e) {
      print('Erro ao carregar categorias: $e');
      safeSetState(() {
        _model.isLoadingCategories = false;
      });
    }
  }

  Future<void> _loadFilteredPhotos({bool refresh = false}) async {
    if (_model.isLoading || !_servicesInitialized) return;

    safeSetState(() {
      _model.isLoading = true;
      if (refresh) {
        _model.currentPage = 0;
        _model.photos = [];
        _model.hasMore = true;
      }
    });

    try {
      final newPhotos = await _photoService.getFilteredSharedPhotos(
        dateFrom: _model.dateFrom,
        dateTo: _model.dateTo,
        minScore: _model.minScore,
        categoria: _model.categoria,
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
        _model.totalResults = _model.photos.length;
      });
    } catch (e) {
      print('Erro ao carregar fotos filtradas: $e');
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
        _loadFilteredPhotos();
      }
    }
  }

  void _applyFilters() {
    _loadFilteredPhotos(refresh: true);
  }

  void _clearFilters() {
    // Limpar filtros e voltar à tela inicial sem carregar fotos
    safeSetState(() {
      _model.dateFrom = null;
      _model.dateTo = null;
      _model.minScore = null;
      _model.categoria = null;
      _model.photos = [];
      _model.currentPage = 0;
      _model.hasMore = true;
      _model.totalResults = 0;
      _model.isLoading = false;
    });
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
          // Nota no canto inferior esquerdo
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

  bool _hasActiveFilters() {
    return _model.dateFrom != null ||
        _model.dateTo != null ||
        _model.minScore != null ||
        (_model.categoria != null && _model.categoria!.isNotEmpty);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        drawer: null, // Garantir que não há drawer
        endDrawer: InspirarFiltersDrawer(
          model: _model,
          onApplyFilters: _applyFilters,
          onClearFilters: _clearFilters,
        ),
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Header customizado
              Container(
                width: double.infinity,
                padding: EdgeInsetsDirectional.fromSTEB(20, 16, 16, 16),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: FlutterFlowTheme.of(context).primaryText,
                            size: 24.0,
                          ),
                          onPressed: () {
                            context.safePop();
                          },
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 0.0, 0.0),
                          child: Text(
                            'Para se Inspirar',
                            style: FlutterFlowTheme.of(context).titleLarge.override(
                                  font: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: Stack(
                        children: [
                          Icon(
                            Icons.filter_list,
                            color: FlutterFlowTheme.of(context).primaryText,
                            size: 24.0,
                          ),
                          if (_hasActiveFilters())
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context).primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                      onPressed: () {
                        scaffoldKey.currentState?.openEndDrawer();
                      },
                    ),
                  ],
                ),
              ),
              // Contador de resultados
              if (_hasActiveFilters() || _model.photos.isNotEmpty)
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(20.0, 12.0, 20.0, 12.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        '${_model.totalResults} ${_model.totalResults == 1 ? 'foto encontrada' : 'fotos encontradas'}',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                              letterSpacing: 0.0,
                            ),
                      ),
                    ],
                  ),
                ),
              // Grade de fotos
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _hasActiveFilters()
                      ? () => _loadFilteredPhotos(refresh: true)
                      : () async {}, // Não fazer nada se não houver filtros
                  color: FlutterFlowTheme.of(context).primary,
                  child: _model.photos.isEmpty && _model.isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                        )
                      : _model.photos.isEmpty && !_model.isLoading
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.auto_awesome_outlined,
                                    size: 80,
                                    color: FlutterFlowTheme.of(context).primary.withOpacity(0.5),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(20, 24, 20, 0),
                                    child: Text(
                                      _hasActiveFilters()
                                          ? 'Nenhuma foto encontrada com os filtros aplicados.\nTente ajustar os filtros.'
                                          : 'O que você quer ver?\nFaça uma busca para se inspirar!',
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
                                  if (!_hasActiveFilters())
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(20, 32, 20, 0),
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          scaffoldKey.currentState?.openEndDrawer();
                                        },
                                        icon: Icon(
                                          Icons.filter_list,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        label: Text(
                                          'Filtrar Fotos',
                                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                font: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                color: Colors.white,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: FlutterFlowTheme.of(context).primary,
                                          padding: EdgeInsetsDirectional.fromSTEB(24, 14, 24, 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
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
            ],
          ),
        ),
      ),
    );
  }
}

