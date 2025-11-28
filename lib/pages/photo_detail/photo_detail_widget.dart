// lib/pages/photo_detail/photo_detail_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../services/photo_service.dart';
import '../../services/auth_service.dart';
import '../../utils/logger.dart';
import '../../models/comment_model.dart';
import 'photo_detail_model.dart';
export 'photo_detail_model.dart';

class PhotoDetailWidget extends StatefulWidget {
  const PhotoDetailWidget({super.key});

  static String routeName = 'photoDetail';
  static String routePath = '/photo-detail/:photoId';

  @override
  State<PhotoDetailWidget> createState() => _PhotoDetailWidgetState();
}

class _PhotoDetailWidgetState extends State<PhotoDetailWidget> {
  late PhotoDetailModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late PhotoService _photoService;
  late AuthService _authService;
  bool _servicesInitialized = false;
  final ScrollController _scrollController = ScrollController();

  // Cache manager customizado para fotos
  static final CacheManager _photoCacheManager = CacheManager(
    Config(
      'photoCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 100,
    ),
  );

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PhotoDetailModel());
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _photoService = PhotoService(supabaseService);
      _authService = AuthService(supabaseService);
      setState(() {
        _servicesInitialized = true;
      });
      _loadPhotoDetails();
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

  String? get _photoId {
    final state = GoRouterState.of(context);
    return state.pathParameters['photoId'];
  }

  Future<void> _loadPhotoDetails() async {
    if (_photoId == null || !_servicesInitialized) return;

    safeSetState(() {
      _model.isLoading = true;
      _model.errorMessage = null;
    });

    try {
      // Carregar foto e comentários em paralelo
      final photoFuture = _photoService.getPhotoById(_photoId!);
      final commentsFuture = _photoService.getComments(_photoId!);

      final photo = await photoFuture;
      final comments = await commentsFuture;

      final commentModels = comments.map((c) => CommentModel.fromJson(c)).toList();

      safeSetState(() {
        _model.photo = photo;
        _model.comments = commentModels;
        _model.isLoading = false;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar detalhes da foto', e, stackTrace);
      safeSetState(() {
        _model.isLoading = false;
        _model.errorMessage = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar foto: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_model.photo == null) return;

    try {
      await _photoService.toggleLike(_model.photo!.id);
      await _loadPhotoDetails(); // Recarregar para atualizar estado do like
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao curtir foto: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    if (_model.photo == null || _photoId == null) return;

    final content = _model.commentController?.text.trim() ?? '';
    if (content.isEmpty) return;

    safeSetState(() {
      _model.isSubmittingComment = true;
    });

    try {
      await _photoService.addComment(
        photoId: _photoId!,
        content: content,
      );

      _model.commentController?.clear();
      await _loadPhotoDetails();

      if (mounted) {
        // Scroll para o topo para ver o novo comentário
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao adicionar comentário: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    } finally {
      if (mounted) {
        safeSetState(() {
          _model.isSubmittingComment = false;
        });
      }
    }
  }

  Future<void> _deleteComment(CommentModel comment) async {
    if (_model.photo == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Excluir comentário',
          style: FlutterFlowTheme.of(context).titleMedium.override(
                font: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                ),
                letterSpacing: 0.0,
              ),
        ),
        content: Text(
          'Tem certeza que deseja excluir este comentário?',
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
      await _photoService.deleteComment(comment.id, _model.photo!.id);
      await _loadPhotoDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao excluir comentário: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _sharePhoto() async {
    if (_model.photo == null) return;

    try {
      final url = _model.photo!.imageUrl;
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao compartilhar: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    try {
      return timeago.format(dateTime, locale: 'pt_BR');
    } catch (e) {
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inDays > 0) {
        return '${difference.inDays} ${difference.inDays == 1 ? 'dia' : 'dias'} atrás';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${difference.inHours == 1 ? 'hora' : 'horas'} atrás';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minuto' : 'minutos'} atrás';
      } else {
        return 'Agora';
      }
    }
  }

  bool _canDeleteComment(CommentModel comment) {
    final currentUserId = _authService.currentUser?.id;
    return currentUserId != null &&
        (currentUserId == _model.photo?.userId ||
            currentUserId == comment.userId);
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
        body: SafeArea(
          top: true,
          child: _model.isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                )
              : _model.photo == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: FlutterFlowTheme.of(context).error,
                          ),
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
                            child: Text(
                              _model.errorMessage ?? 'Foto não encontrada',
                              textAlign: TextAlign.center,
                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.poppins(),
                                    color: FlutterFlowTheme.of(context).secondary,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(20, 24, 20, 0),
                            child: FFButtonWidget(
                              onPressed: () => context.pop(),
                              text: 'Voltar',
                              options: FFButtonOptions(
                                height: 40,
                                padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                                color: FlutterFlowTheme.of(context).primary,
                                textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                      font: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                      ),
                                      color: Colors.white,
                                      letterSpacing: 0.0,
                                    ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Header customizado
                        _buildHeader(),
                        // Conteúdo scrollável
                        Expanded(
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            child: Column(
                              children: [
                                // Imagem em destaque
                                _buildPhotoImage(),
                                // Card de avaliação
                                _buildEvaluationCard(),
                                // Pontos positivos
                                if (_model.photo!.positivePoints.isNotEmpty)
                                  _buildPositivePoints(),
                                // Pontos de melhoria
                                if (_model.photo!.improvementPoints.isNotEmpty)
                                  _buildImprovementPoints(),
                                // Seção de interações
                                _buildInteractionsSection(),
                                // Lista de comentários
                                _buildCommentsSection(),
                                // Espaço para o campo de input fixo
                                const SizedBox(height: 80),
                              ],
                            ),
                          ),
                        ),
                        // Campo de input fixo na parte inferior
                        _buildCommentInput(),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        border: Border(
          bottom: BorderSide(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
            color: FlutterFlowTheme.of(context).primaryText,
          ),
          // Avatar do usuário
          if (_model.photo!.userAvatarUrl != null &&
              _model.photo!.userAvatarUrl!.isNotEmpty)
            CircleAvatar(
              radius: 20,
              backgroundImage: CachedNetworkImageProvider(
                _model.photo!.userAvatarUrl!,
              ),
            )
          else
            CircleAvatar(
              radius: 20,
              backgroundColor: FlutterFlowTheme.of(context).alternate,
              child: Text(
                (_model.photo!.username ?? 'U')[0].toUpperCase(),
                style: GoogleFonts.poppins(
                  color: FlutterFlowTheme.of(context).primaryText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _model.photo!.username ?? 'Usuário',
                    style: FlutterFlowTheme.of(context).titleSmall.override(
                          font: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                          letterSpacing: 0.0,
                        ),
                  ),
                  Text(
                    _formatTimeAgo(_model.photo!.createdAt),
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          font: GoogleFonts.poppins(),
                          color: FlutterFlowTheme.of(context).secondary,
                          fontSize: 10.0,
                          letterSpacing: 0.0,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoImage() {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).alternate,
      ),
      child: _model.photo!.imageUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: _model.photo!.imageUrl,
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.4,
              fit: BoxFit.cover,
              cacheManager: _photoCacheManager,
              placeholder: (context, url) => Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.4,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).alternate,
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: double.infinity,
                height: MediaQuery.of(context).size.height * 0.4,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).alternate,
                ),
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: FlutterFlowTheme.of(context).secondary,
                  ),
                ),
              ),
            )
          : Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.4,
              color: FlutterFlowTheme.of(context).alternate,
              child: Center(
                child: Icon(
                  Icons.image_not_supported,
                  size: 48,
                  color: FlutterFlowTheme.of(context).secondary,
                ),
              ),
            ),
    );
  }

  Widget _buildEvaluationCard() {
    final score = _model.photo!.score;
    final primaryColor = FlutterFlowTheme.of(context).primary;
    
    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 0),
      padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor,
                primaryColor.withOpacity(0.9),
                primaryColor.withOpacity(0.85),
              ],
            ),
          ),
          child: Column(
            children: [
              // Seção da nota com design moderno
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(24, 32, 24, 24),
                child: Column(
                  children: [
                    // Nota em destaque
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          score.toStringAsFixed(2),
                          style: GoogleFonts.poppins(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.0,
                            letterSpacing: -2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 0, 12),
                          child: Text(
                            '/ 10',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Conteúdo do card com fundo branco/claro
              Container(
                width: double.infinity,
                padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                ),
                child: Column(
                  children: [
                    // Recado com design moderno
                    if (_model.photo!.recado != null && _model.photo!.recado!.isNotEmpty)
                      Container(
                        padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              primaryColor.withOpacity(0.12),
                              primaryColor.withOpacity(0.06),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: primaryColor.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          _model.photo!.recado!,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                            letterSpacing: 0.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    // Observação com design moderno
                    if (_model.photo!.observacao != null &&
                        _model.photo!.observacao!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(0, 20, 0, 0),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 20),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).primaryBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).alternate.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline,
                                    color: primaryColor,
                                    size: 20,
                                  ),
                                  Padding(
                                    padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 0, 0),
                                    child: Text(
                                      'Observação:',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: FlutterFlowTheme.of(context).primaryText,
                                        letterSpacing: 0.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
                                child: Text(
                                  _model.photo!.observacao!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    height: 1.5,
                                    color: FlutterFlowTheme.of(context).primaryText,
                                    letterSpacing: 0.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Categoria com design moderno
                    if (_model.photo!.categoria != null &&
                        _model.photo!.categoria!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(0, 20, 0, 0),
                        child: Container(
                          padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                FlutterFlowTheme.of(context).success.withOpacity(0.15),
                                FlutterFlowTheme.of(context).success.withOpacity(0.08),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).success.withOpacity(0.3),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: FlutterFlowTheme.of(context).success.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.category_outlined,
                                size: 16,
                                color: FlutterFlowTheme.of(context).success,
                              ),
                              Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 0, 0),
                                child: Text(
                                  _model.photo!.categoria!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: FlutterFlowTheme.of(context).success,
                                    letterSpacing: 0.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPositivePoints() {
    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 0),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pontos Positivos:',
            style: FlutterFlowTheme.of(context).titleSmall.override(
                  font: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                  color: FlutterFlowTheme.of(context).success,
                  letterSpacing: 0.0,
                ),
          ),
          ..._model.photo!.positivePoints.map((point) => Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: FlutterFlowTheme.of(context).success,
                      size: 20,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 0, 0),
                        child: Text(
                          point,
                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                font: GoogleFonts.poppins(),
                                letterSpacing: 0.0,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildImprovementPoints() {
    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pontos de Melhoria:',
            style: FlutterFlowTheme.of(context).titleSmall.override(
                  font: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                  color: FlutterFlowTheme.of(context).warning,
                  letterSpacing: 0.0,
                ),
          ),
          ..._model.photo!.improvementPoints.map((point) => Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: FlutterFlowTheme.of(context).warning,
                      size: 20,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 0, 0),
                        child: Text(
                          point,
                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                font: GoogleFonts.poppins(),
                                letterSpacing: 0.0,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildInteractionsSection() {
    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 0),
      padding: const EdgeInsetsDirectional.fromSTEB(0, 16, 0, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1,
          ),
          bottom: BorderSide(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          InkWell(
            onTap: _toggleLike,
            child: Column(
              children: [
                Icon(
                  _model.photo!.isLiked == true
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: _model.photo!.isLiked == true
                      ? FlutterFlowTheme.of(context).error
                      : FlutterFlowTheme.of(context).primaryText,
                  size: 28,
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
                  child: Text(
                    '${_model.photo!.likesCount}',
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          font: GoogleFonts.poppins(),
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Icon(
                Icons.mode_comment_outlined,
                color: FlutterFlowTheme.of(context).primaryText,
                size: 28,
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
                child: Text(
                  '${_model.photo!.commentsCount}',
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.poppins(),
                        letterSpacing: 0.0,
                      ),
                ),
              ),
            ],
          ),
          InkWell(
            onTap: _sharePhoto,
            child: Column(
              children: [
                Icon(
                  Icons.share_outlined,
                  color: FlutterFlowTheme.of(context).primaryText,
                  size: 28,
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
                  child: Text(
                    'Compartilhar',
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          font: GoogleFonts.poppins(),
                          fontSize: 10.0,
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection() {
    if (_model.comments.isEmpty) {
      return Container(
        margin: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 0),
        padding: const EdgeInsetsDirectional.fromSTEB(20, 40, 20, 40),
        child: Column(
          children: [
            Icon(
              Icons.comment_outlined,
              size: 64,
              color: FlutterFlowTheme.of(context).secondary,
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(0, 16, 0, 0),
              child: Text(
                'Nenhum comentário ainda.\nSeja o primeiro a comentar!',
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
      );
    }

    return Container(
      margin: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 16),
            child: Text(
              'Comentários (${_model.comments.length})',
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    font: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                    letterSpacing: 0.0,
                  ),
            ),
          ),
          ..._model.comments.map((comment) => Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: FlutterFlowTheme.of(context).alternate,
                      backgroundImage: comment.userAvatarUrl != null &&
                              comment.userAvatarUrl!.isNotEmpty
                          ? CachedNetworkImageProvider(comment.userAvatarUrl!)
                          : null,
                      child: comment.userAvatarUrl == null ||
                              comment.userAvatarUrl!.isEmpty
                          ? Text(
                              (comment.username ?? 'U')[0].toUpperCase(),
                              style: GoogleFonts.poppins(
                                color: FlutterFlowTheme.of(context).primaryText,
                                fontWeight: FontWeight.w600,
                              ),
                            )
                          : null,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 0, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    comment.username ?? 'Usuário',
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                ),
                                Text(
                                  _formatTimeAgo(comment.createdAt),
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                        font: GoogleFonts.poppins(),
                                        color: FlutterFlowTheme.of(context).secondary,
                                        fontSize: 10.0,
                                        letterSpacing: 0.0,
                                      ),
                                ),
                                if (_canDeleteComment(comment))
                                  Padding(
                                    padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 0, 0),
                                    child: InkWell(
                                      onTap: () => _deleteComment(comment),
                                      child: Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: FlutterFlowTheme.of(context).error,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
                              child: Text(
                                comment.content,
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.poppins(),
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        border: Border(
          top: BorderSide(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _model.commentController,
              focusNode: _model.commentFocusNode,
              decoration: InputDecoration(
                hintText: 'Adicione um comentário...',
                hintStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.poppins(),
                      color: FlutterFlowTheme.of(context).secondary,
                      letterSpacing: 0.0,
                    ),
                filled: true,
                fillColor: FlutterFlowTheme.of(context).primaryBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: FlutterFlowTheme.of(context).primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
              ),
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.poppins(),
                    letterSpacing: 0.0,
                  ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submitComment(),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 0, 0),
            child: _model.isSubmittingComment
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FlutterFlowTheme.of(context).primary,
                    ),
                  )
                : IconButton(
                    icon: Icon(
                      Icons.send,
                      color: FlutterFlowTheme.of(context).primary,
                    ),
                    onPressed: _submitComment,
                  ),
          ),
        ],
      ),
    );
  }
}

