// lib/pages/user_profile/user_profile_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../services/supabase_service.dart';
import '../../services/photo_service.dart';
import '../../services/profile_service.dart';
import '../../services/ranking_service.dart';
import '../../services/photo_of_the_day_service.dart';
import '../../utils/logger.dart';
import '../../models/photo_model.dart';
import '../../components/photo_trophy_badge.dart';
import 'user_profile_model.dart';
export 'user_profile_model.dart';

class UserProfileWidget extends StatefulWidget {
  const UserProfileWidget({super.key});

  static String routeName = 'user_profile';
  static String routePath = '/user-profile/:userId';

  @override
  State<UserProfileWidget> createState() => _UserProfileWidgetState();
}

class _UserProfileWidgetState extends State<UserProfileWidget> {
  late UserProfileModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late PhotoService _photoService;
  late ProfileService _profileService;
  late RankingService _rankingService;
  PhotoOfTheDayService? _photoOfTheDayService;
  bool _servicesInitialized = false;
  final ScrollController _scrollController = ScrollController();
  final Map<String, bool> _photoOfDayCache = {};

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
    _model = createModel(context, () => UserProfileModel());
    _scrollController.addListener(_onScroll);
    _initializeServices();
  }

  String? get _userId {
    final state = GoRouterState.of(context);
    return state.pathParameters['userId'];
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _photoService = PhotoService(supabaseService);
      _profileService = ProfileService(supabaseService);
      _rankingService = RankingService(supabaseService);
      _photoOfTheDayService = PhotoOfTheDayService(supabaseService);

      setState(() {
        _servicesInitialized = true;
      });

      // Carregar dados do perfil e fotos em paralelo
      await Future.wait([
        _loadUserProfile(),
        _loadSharedPhotos(refresh: true),
      ]);
    } catch (e, stackTrace) {
      Logger.error('Erro ao inicializar serviços', e, stackTrace);
      safeSetState(() {
        _model.isLoading = false;
        _model.errorMessage = e.toString();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar perfil: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _loadUserProfile() async {
    final userId = _userId;
    if (userId == null) {
      safeSetState(() {
        _model.errorMessage = 'ID do usuário não fornecido';
        _model.isLoading = false;
      });
      return;
    }

    safeSetState(() {
      _model.isLoading = true;
      _model.errorMessage = null;
    });

    try {
      // Buscar dados públicos do perfil
      final profileData = await _profileService.getUserPublicProfile(userId);

      // Buscar posição no ranking
      final rankingPosition = await _rankingService.getUserRankingPosition(userId);

      safeSetState(() {
        _model.username = profileData['username'] as String?;
        _model.avatarUrl = profileData['avatar_url'] as String?;
        _model.totalPhotosEvaluated = profileData['total_photos_evaluated'] as int? ?? 0;
        _model.score = profileData['total_score'] as double?;
        _model.rankingPosition = rankingPosition;
        _model.isLoading = false;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar perfil do usuário', e, stackTrace);
      safeSetState(() {
        _model.isLoading = false;
        _model.errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadSharedPhotos({bool refresh = false}) async {
    final userId = _userId;
    if (userId == null || _model.isLoadingPhotos || !_servicesInitialized) return;

    safeSetState(() {
      _model.isLoadingPhotos = true;
      if (refresh) {
        _model.currentPage = 0;
        _model.photos = [];
        _model.hasMore = true;
      }
    });

    try {
      final newPhotos = await _photoService.getUserSharedPhotos(
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
        _model.isLoadingPhotos = false;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar fotos compartilhadas', e, stackTrace);
      safeSetState(() {
        _model.isLoadingPhotos = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (_model.hasMore && !_model.isLoadingPhotos) {
        _loadSharedPhotos();
      }
    }
  }

  Future<bool> _isPhotoOfTheDay(String photoId, DateTime photoDate) async {
    final cacheKey = '$photoId-${photoDate.toIso8601String().split('T')[0]}';
    if (_photoOfDayCache.containsKey(cacheKey)) {
      return _photoOfDayCache[cacheKey]!;
    }

    if (_photoOfTheDayService == null) return false;

    try {
      final isPhotoOfDay = await _photoOfTheDayService!.isPhotoOfTheDay(
        photoId,
        photoDate,
      );
      _photoOfDayCache[cacheKey] = isPhotoOfDay;
      return isPhotoOfDay;
    } catch (e) {
      Logger.debug('Erro ao verificar se foto é do dia: $e');
      return false;
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
          // Badge de troféu se for foto do dia
          FutureBuilder<bool>(
            future: _isPhotoOfTheDay(photo.id, photo.createdAt),
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return Positioned(
                  top: 8,
                  right: 8,
                  child: PhotoTrophyBadge(
                    size: TrophyBadgeSize.small,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        border: Border(
          bottom: BorderSide(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: FlutterFlowTheme.of(context).primary,
                width: 3,
              ),
            ),
            child: ClipOval(
              child: _model.avatarUrl != null && _model.avatarUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: _model.avatarUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: FlutterFlowTheme.of(context).alternate,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: FlutterFlowTheme.of(context).secondary,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: FlutterFlowTheme.of(context).alternate,
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: FlutterFlowTheme.of(context).secondary,
                        ),
                      ),
                    )
                  : Container(
                      color: FlutterFlowTheme.of(context).alternate,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: FlutterFlowTheme.of(context).secondary,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 16),
          // Nome do usuário
          Text(
            _model.username ?? 'Usuário',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                  ),
                  letterSpacing: 0.0,
                ),
          ),
          SizedBox(height: 24),
          // Estatísticas
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Total de fotos avaliadas
              _buildStatItem(
                icon: Icons.photo_camera_outlined,
                value: '${_model.totalPhotosEvaluated}',
                label: 'Fotos',
              ),
              // Posição no ranking
              _buildStatItem(
                icon: _model.rankingPosition != null && _model.rankingPosition! <= 3
                    ? Icons.emoji_events
                    : Icons.leaderboard,
                value: _model.rankingPosition != null
                    ? '#${_model.rankingPosition}'
                    : '-',
                label: 'Ranking',
                isHighlighted: _model.rankingPosition != null && _model.rankingPosition! <= 3,
              ),
              // Pontuação
              _buildStatItem(
                icon: Icons.star_rounded,
                value: _model.score != null
                    ? _model.score!.toStringAsFixed(1)
                    : '0.0',
                label: 'Pontuação',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
    bool isHighlighted = false,
  }) {
    final color = isHighlighted
        ? FlutterFlowTheme.of(context).primary
        : FlutterFlowTheme.of(context).primaryText;

    return Column(
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: FlutterFlowTheme.of(context).titleLarge.override(
                font: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                ),
                color: color,
                letterSpacing: 0.0,
              ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: FlutterFlowTheme.of(context).bodySmall.override(
                font: GoogleFonts.poppins(),
                color: FlutterFlowTheme.of(context).secondary,
                letterSpacing: 0.0,
              ),
        ),
      ],
    );
  }

  Widget _buildPhotoGrid() {
    if (_model.photos.isEmpty && _model.isLoadingPhotos) {
      return Center(
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(0, 40, 0, 40),
          child: CircularProgressIndicator(
            color: FlutterFlowTheme.of(context).primary,
          ),
        ),
      );
    }

    if (_model.photos.isEmpty && !_model.isLoadingPhotos) {
      return Center(
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(20, 40, 20, 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 64,
                color: FlutterFlowTheme.of(context).secondary,
              ),
              SizedBox(height: 16),
              Text(
                'Nenhuma foto compartilhada',
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).titleMedium.override(
                      font: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                      letterSpacing: 0.0,
                    ),
              ),
              SizedBox(height: 8),
              Text(
                'Este usuário ainda não compartilhou nenhuma foto',
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.poppins(),
                      color: FlutterFlowTheme.of(context).secondary,
                      letterSpacing: 0.0,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsetsDirectional.fromSTEB(2, 2, 2, 2),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 1.0,
      ),
      itemCount: _model.photos.length +
          (_model.isLoadingPhotos && _model.photos.isNotEmpty ? 1 : 0),
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
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          automaticallyImplyLeading: true,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 30.0,
            ),
            onPressed: () async {
              context.pop();
            },
          ),
          title: Text(
            _model.username ?? 'Perfil',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                  letterSpacing: 0.0,
                ),
          ),
          centerTitle: false,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: _model.isLoading && _model.username == null
              ? Center(
                  child: CircularProgressIndicator(
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                )
              : _model.errorMessage != null && _model.username == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: FlutterFlowTheme.of(context).error,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Erro ao carregar perfil',
                            style: FlutterFlowTheme.of(context).titleMedium.override(
                                  font: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  letterSpacing: 0.0,
                                ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
                            child: Text(
                              _model.errorMessage ?? 'Erro desconhecido',
                              textAlign: TextAlign.center,
                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.poppins(),
                                    color: FlutterFlowTheme.of(context).error,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0, 16, 0, 0),
                            child: FFButtonWidget(
                              onPressed: () {
                                context.pop();
                              },
                              text: 'Voltar',
                              options: FFButtonOptions(
                                height: 40,
                                padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                                iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                                color: FlutterFlowTheme.of(context).primary,
                                textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                      font: GoogleFonts.poppins(),
                                      color: Colors.white,
                                      letterSpacing: 0.0,
                                    ),
                                elevation: 0,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Header do perfil
                        _buildProfileHeader(),
                        // Grid de fotos
                        Expanded(
                          child: _buildPhotoGrid(),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
