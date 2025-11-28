// lib/pages/historico/historico_widget.dart
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
import '../../utils/logger.dart';
import '../../models/photo_model.dart';
import 'historico_model.dart';
export 'historico_model.dart';

class HistoricoWidget extends StatefulWidget {
  const HistoricoWidget({super.key});

  static String routeName = 'historico';
  static String routePath = '/historico';

  @override
  State<HistoricoWidget> createState() => _HistoricoWidgetState();
}

class _HistoricoWidgetState extends State<HistoricoWidget> {
  late HistoricoModel _model;

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
    _model = createModel(context, () => HistoricoModel());
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
      await _loadPhotos();
      await _loadTotalPhotos();
    } catch (e, stackTrace) {
      Logger.error('Erro ao inicializar serviços', e, stackTrace);
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

  Future<void> _loadTotalPhotos() async {
    try {
      final count = await _photoService.getUserPhotosCount();
      safeSetState(() {
        _model.totalPhotos = count;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar total de fotos', e, stackTrace);
    }
  }

  Future<void> _loadPhotos({bool refresh = false}) async {
    if (_model.isLoading || !_servicesInitialized) return;

    final userId = _photoService.currentUserId;
    if (userId == null) return;

    safeSetState(() {
      _model.isLoading = true;
      if (refresh) {
        _model.currentPage = 0;
        _model.photos = [];
        _model.hasMore = true;
      }
    });

    try {
      final newPhotos = await _photoService.getUserPhotos(
        userId: userId,
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

      // Atualizar total após carregar
      if (refresh) {
        await _loadTotalPhotos();
      }
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
      if (_model.hasMore && !_model.isLoading && !_model.isSelectionMode) {
        _loadPhotos();
      }
    }
  }

  void _toggleSelectionMode() {
    safeSetState(() {
      _model.isSelectionMode = !_model.isSelectionMode;
      if (!_model.isSelectionMode) {
        _model.selectedPhotoIds.clear();
      }
    });
  }

  void _togglePhotoSelection(String photoId) {
    if (!_model.isSelectionMode) return;

    safeSetState(() {
      if (_model.selectedPhotoIds.contains(photoId)) {
        _model.selectedPhotoIds.remove(photoId);
      } else {
        _model.selectedPhotoIds.add(photoId);
      }
    });
  }

  Future<void> _deleteSelectedPhotos() async {
    if (_model.selectedPhotoIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Excluir fotos',
          style: FlutterFlowTheme.of(context).titleMedium.override(
                font: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
                letterSpacing: 0.0,
              ),
        ),
        content: Text(
          'Tem certeza que deseja excluir ${_model.selectedPhotoIds.length} ${_model.selectedPhotoIds.length == 1 ? 'foto' : 'fotos'}? Esta ação não pode ser desfeita.',
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                font: GoogleFonts.poppins(),
                letterSpacing: 0.0,
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancelar',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.poppins(),
                    color: FlutterFlowTheme.of(context).secondary,
                    letterSpacing: 0.0,
                  ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Excluir',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                    color: FlutterFlowTheme.of(context).error,
                    letterSpacing: 0.0,
                  ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final photoIds = _model.selectedPhotoIds.toList();
      final deletedIds = await _photoService.deletePhotos(photoIds);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${deletedIds.length} ${deletedIds.length == 1 ? 'foto excluída' : 'fotos excluídas'} com sucesso!',
            ),
            backgroundColor: FlutterFlowTheme.of(context).success,
          ),
        );
      }

      // Recarregar lista
      safeSetState(() {
        _model.selectedPhotoIds.clear();
        _model.isSelectionMode = false;
        _model.currentPage = 0;
        _model.photos = [];
        _model.hasMore = true;
      });

      await _loadPhotos(refresh: true);
      await _loadTotalPhotos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir fotos: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  void _navigateToPhotoDetail(String photoId) {
    if (_model.isSelectionMode) return;
    context.push('/photo-detail/$photoId');
  }

  Widget _buildPhotoThumbnail(PhotoModel photo) {
    final isSelected = _model.selectedPhotoIds.contains(photo.id);
    final opacity = _model.isSelectionMode
        ? (isSelected ? 1.0 : 0.5)
        : 1.0;

    return GestureDetector(
      onTap: () {
        if (_model.isSelectionMode) {
          _togglePhotoSelection(photo.id);
        } else {
          _navigateToPhotoDetail(photo.id);
        }
      },
      child: Stack(
        children: [
          Opacity(
            opacity: opacity,
            child: CachedNetworkImage(
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
          // Ícone de check quando selecionado
          if (_model.isSelectionMode && isSelected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        floatingActionButton: _model.isSelectionMode &&
                _model.selectedPhotoIds.isNotEmpty
            ? Stack(
                clipBehavior: Clip.none,
                children: [
                  FloatingActionButton(
                    onPressed: _deleteSelectedPhotos,
                    backgroundColor: FlutterFlowTheme.of(context).error,
                    child: Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                    ),
                  ),
                  // Badge com contador de fotos selecionadas
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Container(
                      padding: EdgeInsetsDirectional.fromSTEB(6, 2, 6, 2),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                      ),
                      constraints: BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      child: Center(
                        child: Text(
                          '${_model.selectedPhotoIds.length}',
                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                font: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                ),
                                color: Colors.white,
                                fontSize: 12,
                                letterSpacing: 0.0,
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : null,
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Header
              Container(
                width: double.infinity,
                decoration: BoxDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 20.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Icon(
                            Icons.history,
                            color: FlutterFlowTheme.of(context).primaryText,
                            size: 24.0,
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 0.0, 0.0),
                              child: Text(
                                'Histórico',
                                style: FlutterFlowTheme.of(context)
                                    .titleLarge
                                    .override(
                                      font: GoogleFonts.poppins(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleLarge
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleLarge
                                          .fontStyle,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      height: 1.0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            FlutterFlowTheme.of(context).primary,
                            Color(0x00FF4C00)
                          ],
                          stops: [0.0, 1.0],
                          begin: AlignmentDirectional(1.0, 0.0),
                          end: AlignmentDirectional(-1.0, 0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Contador e botão de seleção (acima da grade)
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(20.0, 12.0, 20.0, 12.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_model.totalPhotos} ${_model.totalPhotos == 1 ? 'foto' : 'fotos'}',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                            letterSpacing: 0.0,
                          ),
                    ),
                    TextButton(
                      onPressed: _toggleSelectionMode,
                      child: Text(
                        _model.isSelectionMode ? 'Cancelar' : 'Selecionar',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                              color: FlutterFlowTheme.of(context).primary,
                              letterSpacing: 0.0,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              // Grade de fotos
              Expanded(
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
                                  Icons.photo_library_outlined,
                                  size: 64,
                                  color: FlutterFlowTheme.of(context).secondary,
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
                                  child: Text(
                                    'Nenhuma foto avaliada ainda.\nComece avaliando suas fotos!',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                          font: GoogleFonts.poppins(),
                                          color: FlutterFlowTheme.of(context).secondary,
                                          letterSpacing: 0.0,
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
            ],
          ),
        ),
      ),
    );
  }
}
