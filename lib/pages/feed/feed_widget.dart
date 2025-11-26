import '/components/opcoes_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';
import '../../services/supabase_service.dart';
import '../../services/photo_service.dart';
import '../../services/auth_service.dart';
import '../../models/photo_model.dart';
import '../../models/comment_model.dart';
import 'feed_model.dart';
export 'feed_model.dart';

class FeedWidget extends StatefulWidget {
  const FeedWidget({super.key});

  static String routeName = 'feed';
  static String routePath = '/feed';

  @override
  State<FeedWidget> createState() => _FeedWidgetState();
}

class _FeedWidgetState extends State<FeedWidget> {
  late FeedModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late PhotoService _photoService;
  late AuthService _authService;
  bool _servicesInitialized = false;
  final ScrollController _scrollController = ScrollController();
  String? _currentUsername;
  
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
    _model = createModel(context, () => FeedModel());
    _scrollController.addListener(_onScroll);
    _initializeTimeagoLocale();
    _initializeServices();
  }

  void _initializeTimeagoLocale() {
    // Configurar locale pt_BR para timeago
    timeago.setLocaleMessages('pt_BR', timeago.PtBrMessages());
    timeago.setDefaultLocale('pt_BR');
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _photoService = PhotoService(supabaseService);
      _authService = AuthService(supabaseService);
      
      // Buscar username do usuário atual
      final userProfile = await _authService.getCurrentUserProfile();
      if (userProfile != null) {
        setState(() {
          _currentUsername = userProfile.username;
        });
      }
      
      setState(() {
        _servicesInitialized = true;
      });
      // Carregar feed após inicializar serviços
      _loadFeed();
    } catch (e) {
      print('Erro ao inicializar serviços: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao inicializar serviços: $e'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    }
  }

  Future<void> _loadFeed({bool refresh = false}) async {
    if (_model.isLoading || !_servicesInitialized) {
      print('Feed não carregado: isLoading=${_model.isLoading}, servicesInitialized=$_servicesInitialized');
      return;
    }

    safeSetState(() {
      _model.isLoading = true;
      if (refresh) {
        _model.currentPage = 0;
        _model.photos = [];
        _model.hasMore = true;
      }
    });

    try {
      print('Carregando feed: page=${_model.currentPage}, offset=${_model.currentPage * _model.pageSize}');
      final newPhotos = await _photoService.getFeedPhotos(
        limit: _model.pageSize,
        offset: _model.currentPage * _model.pageSize,
      );

      print('Fotos recebidas: ${newPhotos.length}');
      for (final photo in newPhotos) {
        print('Foto ID: ${photo.id}');
        print('URL da imagem: ${photo.imageUrl}');
        print('URL válida: ${photo.imageUrl.isNotEmpty}');
        print('---');
      }

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
    } catch (e) {
      print('Erro ao carregar feed: $e');
      safeSetState(() {
        _model.isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar feed: $e'),
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
        _loadFeed();
      }
    }
  }

  Future<void> _toggleLike(PhotoModel photo) async {
    try {
      await _photoService.toggleLike(photo.id);
      safeSetState(() {
        final index = _model.photos.indexWhere((p) => p.id == photo.id);
        if (index != -1) {
          final updatedPhoto = photo.copyWith(
            isLiked: !(photo.isLiked ?? false),
            likesCount: photo.isLiked == true
                ? photo.likesCount - 1
                : photo.likesCount + 1,
          );
          _model.photos[index] = updatedPhoto;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao curtir foto: $e'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    }
  }

  Future<void> _sharePhoto(PhotoModel photo) async {
    try {
      final url = photo.imageUrl;
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao compartilhar: $e'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    try {
      // Usar locale pt_BR para português brasileiro
      return timeago.format(dateTime, locale: 'pt_BR');
    } catch (e) {
      // Fallback para formato simples se timeago falhar
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    String greeting;
    
    if (hour >= 4 && hour < 12) {
      greeting = 'Bom dia';
    } else if (hour >= 12 && hour < 18) {
      greeting = 'Boa tarde';
    } else {
      // 18h até 4h da manhã
      greeting = 'Boa noite';
    }
    
    final username = _currentUsername ?? 'Usuário';
    return '$greeting, $username! 👋🏼';
  }

  Future<void> _showCommentsBottomSheet(PhotoModel photo) async {
    final comments = await _photoService.getComments(photo.id);
    final commentModels = comments.map((c) => CommentModel.fromJson(c)).toList();
    final currentUserId = _authService.currentUser?.id;
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsBottomSheet(
        photo: photo,
        initialComments: commentModels,
        photoService: _photoService,
        currentUserId: currentUserId,
        onCommentAdded: () {
          // Recarregar comentários e atualizar contador
          _refreshPhotoComments(photo.id);
        },
      ),
    );
  }

  Future<void> _refreshPhotoComments(String photoId) async {
    try {
      // Buscar foto atualizada para pegar o novo contador de comentários
      final updatedPhoto = await _photoService.getPhotoById(photoId);
      safeSetState(() {
        final index = _model.photos.indexWhere((p) => p.id == photoId);
        if (index != -1) {
          _model.photos[index] = updatedPhoto;
        }
      });
    } catch (e) {
      print('Erro ao atualizar comentários: $e');
    }
  }

  String _getMotivationalPhrase() {
    final hour = DateTime.now().hour;
    
    // Frases motivacionais sobre fotografia para cada hora do dia
    final phrases = [
      // 0h - 1h
      'Cada foto conta uma história única!',
      'A fotografia é a arte de capturar momentos eternos!',
      // 2h - 3h
      'Seus olhos veem o que outros não conseguem!',
      'Cada clique é uma oportunidade de criar arte!',
      // 4h - 5h
      'O amanhecer traz novas perspectivas para suas fotos!',
      'Comece o dia capturando a beleza ao seu redor!',
      // 6h - 7h
      'A luz da manhã é perfeita para fotografar!',
      'Cada foto é uma janela para o mundo!',
      // 8h - 9h
      'Transforme momentos comuns em memórias extraordinárias!',
      'A fotografia faz parte de você!',
      // 10h - 11h
      'Seu olhar único transforma o mundo em arte!',
      'Cada foto é uma expressão da sua criatividade!',
      // 12h - 13h
      'O meio-dia traz luzes intensas e sombras marcantes!',
      'Capture a energia do dia em suas fotos!',
      // 14h - 15h
      'A tarde é perfeita para explorar novos ângulos!',
      'Cada momento merece ser fotografado!',
      // 16h - 17h
      'A luz dourada da tarde realça cada detalhe!',
      'Sua paixão pela fotografia inspira outros!',
      // 18h - 19h
      'O pôr do sol é o momento mágico para fotografar!',
      'Cada foto é uma obra de arte em potencial!',
      // 20h - 21h
      'A noite revela uma perspectiva diferente do mundo!',
      'Sua criatividade não tem limites!',
      // 22h - 23h
      'Cada foto que você tira é única e especial!',
      'A fotografia é sua forma de ver e compartilhar o mundo!',
    ];
    
    // Retornar frase baseada na hora (24 frases para 24 horas)
    return phrases[hour];
  }

  Widget _buildImageWidget(PhotoModel photo) {
    if (photo.imageUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: MediaQuery.sizeOf(context).height * 0.5,
        color: FlutterFlowTheme.of(context).alternate,
        child: Center(
          child: Icon(
            Icons.image_not_supported,
            size: 48.0,
            color: FlutterFlowTheme.of(context).secondary,
          ),
        ),
      );
    }

    // Usar CachedNetworkImage para todas as plataformas (melhor cache e compatibilidade)
    return CachedNetworkImage(
      imageUrl: photo.imageUrl,
      width: double.infinity,
      height: MediaQuery.sizeOf(context).height * 0.5,
      fit: BoxFit.cover,
      cacheManager: _photoCacheManager,
      memCacheWidth: (MediaQuery.sizeOf(context).width * 2).toInt(),
      memCacheHeight: (MediaQuery.sizeOf(context).height * 0.5 * 2).toInt(),
      fadeInDuration: const Duration(milliseconds: 300),
      fadeOutDuration: const Duration(milliseconds: 100),
      placeholder: (context, url) => Container(
        width: double.infinity,
        height: MediaQuery.sizeOf(context).height * 0.5,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).alternate,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FlutterFlowTheme.of(context).alternate,
              FlutterFlowTheme.of(context).alternate.withOpacity(0.8),
            ],
          ),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: FlutterFlowTheme.of(context).primary,
            strokeWidth: 2.0,
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        print('Erro ao carregar imagem no mobile: $url');
        print('Erro: $error');
        // Tentar Image.network como fallback
        return Image.network(
          url,
          width: double.infinity,
          height: MediaQuery.sizeOf(context).height * 0.5,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: double.infinity,
              height: MediaQuery.sizeOf(context).height * 0.5,
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).alternate,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 48.0,
                    color: FlutterFlowTheme.of(context).secondary,
                  ),
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(20.0, 8.0, 20.0, 0.0),
                    child: Text(
                      'Erro ao carregar imagem',
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            font: GoogleFonts.poppins(),
                            color: FlutterFlowTheme.of(context).secondary,
                            fontSize: 12.0,
                          ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      httpHeaders: {
        'Accept': 'image/*',
      },
    );
  }

  Widget _buildPhotoCard(PhotoModel photo) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(),
      margin: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 24.0),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 12.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                photo.userAvatarUrl != null
                    ? CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(photo.userAvatarUrl!),
                        radius: 12.0,
                      )
                    : FaIcon(
                        FontAwesomeIcons.userCircle,
                        color: FlutterFlowTheme.of(context).primaryText,
                        size: 24.0,
                      ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 0.0, 0.0),
                  child: Text(
                    photo.username ?? 'Usuário',
                    style: FlutterFlowTheme.of(context).titleSmall.override(
                          font: GoogleFonts.poppins(),
                          fontSize: 14.0,
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 10.0, 0.0),
                  child: Icon(
                    Icons.circle,
                    color: FlutterFlowTheme.of(context).primaryText,
                    size: 8.0,
                  ),
                ),
                Expanded(
                  child: Text(
                    _formatTimeAgo(photo.createdAt),
                    style: GoogleFonts.poppins(
                      color: FlutterFlowTheme.of(context).secondary,
                      fontSize: 10.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildImageWidget(photo),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20.0, 12.0, 20.0, 12.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 5.0),
                  child: Text(
                    'Nota',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.poppins(),
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(5.0, 0.0, 0.0, 0.0),
                    child: Text(
                      photo.score.toStringAsFixed(2),
                      style: FlutterFlowTheme.of(context).headlineSmall.override(
                            font: GoogleFonts.poppins(),
                            letterSpacing: 0.0,
                          ),
                    ),
                  ),
                ),
                if (photo.recado != null && photo.recado!.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFF81FDF4),
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                    child: Align(
                      alignment: AlignmentDirectional(0.0, 0.0),
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(8.0, 4.0, 8.0, 4.0),
                        child: Text(
                          photo.recado!,
                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                font: GoogleFonts.poppins(),
                                color: FlutterFlowTheme.of(context).success,
                                letterSpacing: 0.0,
                              ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                InkWell(
                  onTap: () => _toggleLike(photo),
                  child: Icon(
                    photo.isLiked == true
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: photo.isLiked == true
                        ? FlutterFlowTheme.of(context).error
                        : FlutterFlowTheme.of(context).primaryText,
                    size: 24.0,
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(4.0, 0.0, 8.0, 0.0),
                  child: Text(
                    '${photo.likesCount}',
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          font: GoogleFonts.poppins(),
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
                InkWell(
                  onTap: () => _showCommentsBottomSheet(photo),
                  child: Icon(
                    Icons.mode_comment_outlined,
                    color: FlutterFlowTheme.of(context).primaryText,
                    size: 24.0,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(4.0, 0.0, 8.0, 0.0),
                    child: Text(
                      '${photo.commentsCount}',
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            font: GoogleFonts.poppins(),
                            letterSpacing: 0.0,
                          ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => _sharePhoto(photo),
                  child: Icon(
                    Icons.share_outlined,
                    color: FlutterFlowTheme.of(context).primaryText,
                    size: 24.0,
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(4.0, 0.0, 0.0, 0.0),
                  child: Text(
                    'Compartilhar',
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          font: GoogleFonts.poppins(),
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(0.0, 24.0, 0.0, 24.0),
            child: Container(
              width: MediaQuery.sizeOf(context).width * 0.9,
              height: 1.0,
              decoration: BoxDecoration(
                color: Color(0x28868686),
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
        endDrawer: Drawer(
          elevation: 16.0,
          child: wrapWithModel(
            model: _model.opcoesModel,
            updateCallback: () => safeSetState(() {}),
            child: OpcoesWidget(),
          ),
        ),
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: double.infinity,
                height: 70.0,
                decoration: BoxDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            20.0, 0.0, 20.0, 0.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .override(
                                        font: GoogleFonts.poppins(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .fontStyle,
                                      ),
                                ),
                                Text(
                                  _getMotivationalPhrase(),
                                  style: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .override(
                                        font: GoogleFonts.poppins(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodySmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodySmall
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .secondary,
                                        fontSize: 10.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontStyle,
                                      ),
                                ),
                              ],
                            ),
                            InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                scaffoldKey.currentState!.openEndDrawer();
                              },
                              child: Icon(
                                Icons.menu,
                                color: FlutterFlowTheme.of(context).primaryText,
                                size: 24.0,
                              ),
                            ),
                          ],
                        ),
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
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _loadFeed(refresh: true),
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    20.0, 20.0, 20.0, 20.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Feed',
                                      style: FlutterFlowTheme.of(context)
                                          .headlineSmall
                                          .override(
                                            font: GoogleFonts.poppins(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .headlineSmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .headlineSmall
                                                      .fontStyle,
                                            ),
                                            letterSpacing: 0.0,
                                          ),
                                    ),
                                    FFButtonWidget(
                                      onPressed: () {
                                        _loadFeed(refresh: true);
                                      },
                                      text: 'Atualizar',
                                      options: FFButtonOptions(
                                        height: 30.0,
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            16.0, 0.0, 16.0, 0.0),
                                        iconPadding:
                                            EdgeInsetsDirectional.fromSTEB(
                                                0.0, 0.0, 0.0, 0.0),
                                        color:
                                            FlutterFlowTheme.of(context).primary,
                                        textStyle: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .override(
                                              font: GoogleFonts.poppins(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .titleSmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .titleSmall
                                                        .fontStyle,
                                              ),
                                              color: FlutterFlowTheme.of(context)
                                                  .primaryBackground,
                                              letterSpacing: 0.0,
                                            ),
                                        elevation: 0.0,
                                        borderRadius: BorderRadius.circular(8.0),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Indicador de carregamento inicial
                              if (_model.photos.isEmpty && _model.isLoading)
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 40.0, 0.0, 40.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              // Mensagem quando não há fotos
                              if (_model.photos.isEmpty && !_model.isLoading && _servicesInitialized)
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      20.0, 40.0, 20.0, 40.0),
                                  child: Text(
                                    'Nenhuma foto compartilhada ainda.\nSeja o primeiro a compartilhar!',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.poppins(),
                                          color: FlutterFlowTheme.of(context)
                                              .secondary,
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                ),
                              // Lista de fotos
                              ..._model.photos.map((photo) => _buildPhotoCard(photo)),
                              // Indicador de carregamento ao rolar para baixo
                              if (_model.isLoading && _model.photos.isNotEmpty)
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 20.0, 0.0, 20.0),
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
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

// Widget do Bottom Sheet de Comentários
class _CommentsBottomSheet extends StatefulWidget {
  final PhotoModel photo;
  final List<CommentModel> initialComments;
  final PhotoService photoService;
  final VoidCallback onCommentAdded;
  final String? currentUserId;

  const _CommentsBottomSheet({
    required this.photo,
    required this.initialComments,
    required this.photoService,
    required this.onCommentAdded,
    required this.currentUserId,
  });

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<CommentModel> _comments = [];
  bool _isLoading = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _comments = widget.initialComments;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final comments = await widget.photoService.getComments(widget.photo.id);
      setState(() {
        _comments = comments.map((c) => CommentModel.fromJson(c)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar comentários: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await widget.photoService.addComment(
        photoId: widget.photo.id,
        content: content,
      );

      _commentController.clear();
      await _loadComments();
      widget.onCommentAdded();

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
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _deleteComment(CommentModel comment) async {
    // Mostrar diálogo de confirmação
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
      await widget.photoService.deleteComment(comment.id, widget.photo.id);
      await _loadComments();
      widget.onCommentAdded();
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

  bool _canDeleteComment(CommentModel comment) {
    // Pode deletar se for o dono da foto ou o autor do comentário
    return widget.currentUserId != null &&
        (widget.currentUserId == widget.photo.userId ||
            widget.currentUserId == comment.userId);
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

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: FlutterFlowTheme.of(context).alternate,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Comentários (${widget.photo.commentsCount})',
                    style: FlutterFlowTheme.of(context).titleMedium.override(
                          font: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
              ],
            ),
          ),
          // Lista de comentários
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: FlutterFlowTheme.of(context).primary,
                    ),
                  )
                : _comments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.comment_outlined,
                              size: 64,
                              color: FlutterFlowTheme.of(context).secondary,
                            ),
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 0),
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
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final comment = _comments[index];
                          final canDelete = _canDeleteComment(comment);
                          
                          return Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Avatar
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
                                        // Nome e tempo
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
                                            if (canDelete)
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
                                        // Conteúdo do comentário
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
                          );
                        },
                      ),
          ),
          // Campo de input para novo comentário
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).primaryBackground,
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
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Adicione um comentário...',
                      hintStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.poppins(),
                            color: FlutterFlowTheme.of(context).secondary,
                            letterSpacing: 0.0,
                          ),
                      filled: true,
                      fillColor: FlutterFlowTheme.of(context).secondaryBackground,
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
                  child: _isSubmitting
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
          ),
        ],
      ),
    );
  }
}
