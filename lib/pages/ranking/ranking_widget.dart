import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../services/ranking_service.dart';
import '../../models/ranking_item_model.dart';
import '../../models/photo_model.dart';
import '../../components/ranking_user_card.dart';
import '../../components/ranking_photo_card.dart';
import '../../components/load_more_button.dart';
import '../../components/month_year_picker.dart';
import '../photo_detail/photo_detail_widget.dart';
import 'ranking_model.dart';
export 'ranking_model.dart';

class RankingWidget extends StatefulWidget {
  const RankingWidget({super.key});

  static String routeName = 'ranking';
  static String routePath = '/ranking';

  @override
  State<RankingWidget> createState() => _RankingWidgetState();
}

class _RankingWidgetState extends State<RankingWidget>
    with SingleTickerProviderStateMixin {
  late RankingModel _model;
  late TabController _tabController;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late RankingService _rankingService;
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => RankingModel());
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      // Recarregar dados quando trocar de tab
      if (!_tabController.indexIsChanging) {
        if (_tabController.index == 0 && _model.users.isEmpty && !_model.isLoadingUsers) {
          _loadUsersRanking(refresh: true);
        } else if (_tabController.index == 1 && _model.photos.isEmpty && !_model.isLoadingPhotos) {
          _loadPhotosRanking(refresh: true);
        }
      }
    });
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _rankingService = RankingService(supabaseService);
      setState(() {
        _servicesInitialized = true;
      });
      _loadUsersRanking(refresh: true);
      _loadPhotosRanking(refresh: true);
    } catch (e) {
      print('Erro ao inicializar serviços: $e');
      safeSetState(() {
        _model.errorMessage = 'Erro ao inicializar serviços: $e';
      });
    }
  }

  Future<void> _loadUsersRanking({bool refresh = false}) async {
    if (_model.isLoadingUsers || !_servicesInitialized) {
      print('Pulando carregamento: isLoadingUsers=${_model.isLoadingUsers}, initialized=$_servicesInitialized');
      return;
    }

    print('Iniciando carregamento de usuários: refresh=$refresh');

    if (mounted) {
      setState(() {
        _model.isLoadingUsers = true;
        _model.errorMessage = null;
        if (refresh) {
          _model.currentUsersPage = 0;
          _model.users = [];
          _model.hasMoreUsers = true;
        }
      });
    }

    try {
      final month = _model.selectedMonth.month;
      final year = _model.selectedMonth.year;
      final limit = 10;
      final offset = _model.currentUsersPage * limit;

      print('Chamando serviço: month=$month, year=$year, limit=$limit, offset=$offset');

      final users = await _rankingService.getTopUsersOfMonthPaginated(
        limit: limit,
        offset: offset,
        month: month,
        year: year,
      );

      print('Usuários carregados: ${users.length} para mês $month/$year');
      if (users.isNotEmpty) {
        print('Primeiro usuário: ${users.first.username} - ${users.first.score}');
      }

      if (mounted) {
        setState(() {
          if (refresh) {
            _model.users = users;
          } else {
            _model.users.addAll(users);
          }
          _model.hasMoreUsers = users.length == limit;
          _model.currentUsersPage++;
          _model.isLoadingUsers = false;
        });
        print('Estado atualizado: ${_model.users.length} usuários na lista');
      }
    } catch (e, stackTrace) {
      print('Erro ao carregar ranking de usuários: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _model.isLoadingUsers = false;
          _model.errorMessage = 'Erro ao carregar ranking: $e';
        });
      }
    }
  }

  Future<void> _loadPhotosRanking({bool refresh = false}) async {
    if (_model.isLoadingPhotos || !_servicesInitialized) return;

    safeSetState(() {
      _model.isLoadingPhotos = true;
      if (refresh) {
        _model.currentPhotosPage = 0;
        _model.photos = [];
        _model.hasMorePhotos = true;
      }
    });

    try {
      final month = _model.selectedMonth.month;
      final year = _model.selectedMonth.year;
      final limit = 10;
      final offset = _model.currentPhotosPage * limit;

      final photos = await _rankingService.getBestPhotosOfMonthPaginated(
        limit: limit,
        offset: offset,
        month: month,
        year: year,
      );

      safeSetState(() {
        if (refresh) {
          _model.photos = photos;
        } else {
          _model.photos.addAll(photos);
        }
        _model.hasMorePhotos = photos.length == limit;
        _model.currentPhotosPage++;
        _model.isLoadingPhotos = false;
      });
    } catch (e) {
      print('Erro ao carregar ranking de fotos: $e');
      safeSetState(() {
        _model.isLoadingPhotos = false;
        _model.errorMessage = 'Erro ao carregar ranking de fotos: $e';
      });
    }
  }

  void _onMonthChanged(DateTime newDate) {
    final now = DateTime.now();
    final isHistorical = newDate.year != now.year || newDate.month != now.month;
    
    if (mounted) {
      setState(() {
        _model.selectedMonth = newDate;
        _model.isHistoricalView = isHistorical;
      });
    }
    
    _loadUsersRanking(refresh: true);
    _loadPhotosRanking(refresh: true);
  }

  Widget _buildUsersTab() {
    if (_model.isLoadingUsers && _model.users.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(0.0, 40.0, 0.0, 40.0),
          child: Center(
            child: CircularProgressIndicator(
              color: FlutterFlowTheme.of(context).primary,
            ),
          ),
        ),
      );
    }

    if (_model.users.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(20.0, 40.0, 20.0, 40.0),
          child: Column(
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: FlutterFlowTheme.of(context).secondary,
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                child: Text(
                  'Nenhum usuário encontrado',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.poppins(),
                        color: FlutterFlowTheme.of(context).secondary,
                        letterSpacing: 0.0,
                      ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Criar lista de widgets de forma explícita
    final List<Widget> userWidgets = [];
    
    print('_buildUsersTab: Construindo ${_model.users.length} cards');
    
    for (var i = 0; i < _model.users.length; i++) {
      final user = _model.users[i];
      print('Criando card $i: userId=${user.userId}, username=${user.username}, position=${user.position}');
      
      try {
        userWidgets.add(
          RankingUserCard(
            key: ValueKey('user_${user.userId}_${user.position}_$i'),
            user: user,
            isTopThree: user.position <= 3,
          ),
        );
        print('Card $i criado com sucesso');
      } catch (e, stackTrace) {
        print('Erro ao criar card $i: $e');
        print('Stack trace: $stackTrace');
        // Adicionar um widget de erro como fallback
        userWidgets.add(
          Container(
            margin: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 12.0),
            padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Text(
              'Erro ao carregar usuário: ${user.username ?? "N/A"}',
              style: FlutterFlowTheme.of(context).bodyMedium,
            ),
          ),
        );
      }
    }
    
    // Adicionar botão carregar mais
    userWidgets.add(
      LoadMoreButton(
        onPressed: _model.hasMoreUsers && !_model.isLoadingUsers
            ? () => _loadUsersRanking()
            : null,
        isLoading: _model.isLoadingUsers,
        hasMore: _model.hasMoreUsers,
      ),
    );
    
    print('Total de widgets criados: ${userWidgets.length}');
    
    return ListView(
      padding: EdgeInsetsDirectional.fromSTEB(20.0, 16.0, 20.0, 16.0),
      physics: const AlwaysScrollableScrollPhysics(),
      children: userWidgets,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
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
                      padding: EdgeInsetsDirectional.fromSTEB(
                          20.0, 20.0, 20.0, 16.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Icon(
                            Icons.leaderboard,
                            color: FlutterFlowTheme.of(context).primaryText,
                            size: 24.0,
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  8.0, 0.0, 0.0, 0.0),
                              child: Text(
                                'Ranking',
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
                    // Seletor de mês/ano
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 16.0),
                      child: MonthYearPicker(
                        selectedDate: _model.selectedMonth,
                        onDateChanged: _onMonthChanged,
                        isHistorical: _model.isHistoricalView,
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
              // Tabs
              TabBar(
                controller: _tabController,
                labelColor: FlutterFlowTheme.of(context).primary,
                unselectedLabelColor: FlutterFlowTheme.of(context).secondary,
                labelStyle: FlutterFlowTheme.of(context).titleSmall.override(
                      font: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                      letterSpacing: 0.0,
                    ),
                unselectedLabelStyle: FlutterFlowTheme.of(context).titleSmall,
                indicatorColor: FlutterFlowTheme.of(context).primary,
                tabs: [
                  Tab(text: 'Usuários'),
                  Tab(text: 'Fotos'),
                ],
              ),
              // Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab Usuários
                    RefreshIndicator(
                      onRefresh: () => _loadUsersRanking(refresh: true),
                      child: _buildUsersTab(),
                    ),
                    // Tab Fotos
                    RefreshIndicator(
                      onRefresh: () => _loadPhotosRanking(refresh: true),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              20.0, 16.0, 20.0, 16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_model.isLoadingPhotos && _model.photos.isEmpty)
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 40.0, 0.0, 40.0),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      color: FlutterFlowTheme.of(context).primary,
                                    ),
                                  ),
                                )
                              else if (_model.photos.isEmpty)
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 40.0, 0.0, 40.0),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.photo_outlined,
                                        size: 64,
                                        color: FlutterFlowTheme.of(context).secondary,
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            0.0, 16.0, 0.0, 0.0),
                                        child: Text(
                                          'Nenhuma foto encontrada',
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
                                    ],
                                  ),
                                )
                              else
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 12.0,
                                    mainAxisSpacing: 12.0,
                                    childAspectRatio: 0.75,
                                  ),
                                  itemCount: _model.photos.length,
                                  itemBuilder: (context, index) {
                                    final photo = _model.photos[index];
                                    return RankingPhotoCard(
                                      photo: photo,
                                      position: index + 1,
                                      onTap: () {
                                        context.push('/photo-detail/${photo.id}');
                                      },
                                    );
                                  },
                                ),
                              if (_model.photos.isNotEmpty)
                                LoadMoreButton(
                                  onPressed: _model.hasMorePhotos && !_model.isLoadingPhotos
                                      ? () => _loadPhotosRanking()
                                      : null,
                                  isLoading: _model.isLoadingPhotos,
                                  hasMore: _model.hasMorePhotos,
                                ),
                            ],
                          ),
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
}
