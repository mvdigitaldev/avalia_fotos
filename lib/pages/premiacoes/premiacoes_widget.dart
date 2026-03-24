// lib/pages/premiacoes/premiacoes_widget.dart
import 'dart:typed_data';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../../services/supabase_service.dart';
import '../../services/photo_of_the_day_service.dart';
import '../../services/photo_awards_service.dart';
import '../../services/plan_service.dart';
import '../../services/auth_service.dart';
import '../../models/photo_of_the_day_model.dart';
import '../../models/photo_of_week_month_models.dart';
import '../../utils/logger.dart';
import '../../utils/plans_navigation_helper.dart';
import '../../components/photo_trophy_badge.dart';
import 'premiacoes_model.dart';
export 'premiacoes_model.dart';

class PremiacoesWidget extends StatefulWidget {
  const PremiacoesWidget({super.key});

  static String routeName = 'premiacoes';
  static String routePath = '/premiacoes';

  @override
  State<PremiacoesWidget> createState() => _PremiacoesWidgetState();
}

class _PremiacoesWidgetState extends State<PremiacoesWidget>
    with SingleTickerProviderStateMixin {
  PremiacoesModel? _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late PhotoOfTheDayService _photoOfTheDayService;
  PhotoAwardsService? _photoAwardsService;
  PlanService? _planService;
  AuthService? _authService;
  bool _servicesInitialized = false;
  bool _hasActivePlan = false;
  bool _isCheckingPlan = true;
  DateTime _selectedDate = DateTime.now();
  PhotoOfTheDayModel? _photoOfTheDay;
  bool _isLoading = false;
  Map<DateTime, String> _calendarPhotos = {};
  DateTime _currentMonth = DateTime.now();
  late TabController _tabController;
  DateTime _selectedWeekDay = DateTime.now();
  DateTime _selectedMonthFirst =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  PhotoOfTheWeekModel? _photoOfTheWeek;
  PhotoOfTheMonthModel? _photoOfTheMonth;
  bool _loadingWeek = false;
  bool _loadingMonth = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _currentMonth = DateTime.now();
    _selectedWeekDay = DateTime.now();
    _selectedMonthFirst =
        DateTime(DateTime.now().year, DateTime.now().month, 1);
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (!_servicesInitialized || !_hasActivePlan) return;
    if (_tabController.index == 1) {
      _loadPhotoOfTheWeek();
    } else if (_tabController.index == 2) {
      _loadPhotoOfTheMonth();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Agora context está disponível
    if (_model == null) {
      _model = createModel(context, () => PremiacoesModel());
      _checkDeepLink();
      _initializeServices();
    }
  }

  void _checkDeepLink() {
    final state = GoRouterState.of(context);
    final dateParam = state.uri.queryParameters['date'];
    if (dateParam != null) {
      try {
        final date = DateTime.parse(dateParam);
        _selectedDate = date;
        _currentMonth = DateTime(date.year, date.month);
      } catch (e) {
        Logger.warning('Data inválida no deep link: $dateParam');
      }
    }
    final tab = state.uri.queryParameters['tab'];
    final weekParam = state.uri.queryParameters['week'];
    final monthParam = state.uri.queryParameters['month'];
    if (tab == 'week') {
      _tabController.index = 1;
      if (weekParam != null) {
        try {
          _selectedWeekDay = DateTime.parse(weekParam);
        } catch (e) {
          Logger.warning('Semana inválida no deep link: $weekParam');
        }
      }
    } else if (tab == 'month') {
      _tabController.index = 2;
      if (monthParam != null) {
        try {
          final d = DateTime.parse(monthParam);
          _selectedMonthFirst = DateTime(d.year, d.month, 1);
        } catch (e) {
          Logger.warning('Mês inválido no deep link: $monthParam');
        }
      }
    }
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _photoOfTheDayService = PhotoOfTheDayService(supabaseService);
      _photoAwardsService = PhotoAwardsService(supabaseService);
      _planService = PlanService(supabaseService);
      _authService = AuthService(supabaseService);
      
      // Verificar se o usuário tem plano ativo
      await _checkUserHasActivePlan();
      
      if (!_hasActivePlan) {
        setState(() {
          _isCheckingPlan = false;
        });
        return;
      }
      
      setState(() {
        _servicesInitialized = true;
        _isCheckingPlan = false;
      });
      await _loadPhotoOfTheDay();
      await _loadCalendar();
      if (_tabController.index == 1) {
        await _loadPhotoOfTheWeek();
      } else if (_tabController.index == 2) {
        await _loadPhotoOfTheMonth();
      }
    } catch (e, stackTrace) {
      Logger.error('Erro ao inicializar serviços', e, stackTrace);
      setState(() {
        _isCheckingPlan = false;
      });
    }
  }

  Future<void> _checkUserHasActivePlan() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      final currentUser = supabaseService.currentUser;
      if (currentUser == null) {
        setState(() {
          _hasActivePlan = false;
        });
        return;
      }

      final userPlan = await _planService!.getUserPlan(currentUser.id);
      final hasActivePlan = userPlan != null && !userPlan.plan.isFree;
      
      setState(() {
        _hasActivePlan = hasActivePlan;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao verificar plano ativo do usuário', e, stackTrace);
      setState(() {
        _hasActivePlan = false;
      });
    }
  }

  Future<void> _loadPhotoOfTheDay() async {
    if (!_servicesInitialized) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final photo = await _photoOfTheDayService.getPhotoOfTheDay(_selectedDate);
      setState(() {
        _photoOfTheDay = photo;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar foto do dia', e, stackTrace);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCalendar() async {
    if (!_servicesInitialized) return;

    try {
      final photos = await _photoOfTheDayService.getPhotosOfTheDayCalendar(
        _currentMonth.year,
        _currentMonth.month,
      );
      setState(() {
        _calendarPhotos = photos;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar calendário', e, stackTrace);
    }
  }

  Future<void> _downloadPhotoWithSeloUrl(String? urlImagemSelo, String fileBaseName) async {
    if (urlImagemSelo == null || urlImagemSelo.trim().isEmpty) return;
    if (!mounted) return;

    try {
      final response = await http.get(Uri.parse(urlImagemSelo));
      if (response.statusCode != 200) {
        throw Exception('Falha ao baixar imagem: ${response.statusCode}');
      }
      final bytes = Uint8List.fromList(response.bodyBytes);
      final result = await ImageGallerySaverPlus.saveImage(
        bytes,
        quality: 100,
        name: fileBaseName,
      );
      if (!mounted) return;
      if (result['isSuccess'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Foto baixada com sucesso!'),
            backgroundColor: FlutterFlowTheme.of(context).success,
          ),
        );
      } else {
        throw Exception(result['error'] ?? 'Erro ao salvar na galeria');
      }
    } catch (e, stackTrace) {
      Logger.error('Erro ao baixar foto com selo', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao baixar foto: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _loadPhotoOfTheWeek() async {
    if (!_servicesInitialized || _photoAwardsService == null) return;
    setState(() => _loadingWeek = true);
    try {
      final w = await _photoAwardsService!.getPhotoOfTheWeek(_selectedWeekDay);
      setState(() {
        _photoOfTheWeek = w;
        _loadingWeek = false;
      });
    } catch (e, st) {
      Logger.error('Erro ao carregar foto da semana', e, st);
      setState(() => _loadingWeek = false);
    }
  }

  Future<void> _loadPhotoOfTheMonth() async {
    if (!_servicesInitialized || _photoAwardsService == null) return;
    setState(() => _loadingMonth = true);
    try {
      final m =
          await _photoAwardsService!.getPhotoOfTheMonth(_selectedMonthFirst);
      setState(() {
        _photoOfTheMonth = m;
        _loadingMonth = false;
      });
    } catch (e, st) {
      Logger.error('Erro ao carregar foto do mês', e, st);
      setState(() => _loadingMonth = false);
    }
  }

  Future<void> _pickWeekForPremiacoes() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedWeekDay,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() => _selectedWeekDay = picked);
      await _loadPhotoOfTheWeek();
    }
  }

  Future<void> _pickMonthForPremiacoes() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonthFirst,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
      helpText: 'Selecione qualquer dia do mês',
    );
    if (picked != null) {
      setState(() {
        _selectedMonthFirst = DateTime(picked.year, picked.month, 1);
      });
      await _loadPhotoOfTheMonth();
    }
  }

  Future<void> _showCalendarDialog() async {
    // Carregar calendário para o mês atual antes de abrir o dialog
    await _loadCalendar();

    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) => _CalendarDialog(
        selectedDate: _selectedDate,
        calendarPhotos: _calendarPhotos,
        photoOfTheDayService: _photoOfTheDayService,
        onDateSelected: (date) {
          Navigator.of(context).pop(date);
        },
      ),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _currentMonth = DateTime(picked.year, picked.month);
      });
      await _loadPhotoOfTheDay();
      await _loadCalendar();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _model?.maybeDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 24,
            ),
            onPressed: () => context.safePop(),
          ),
          title: Text(
            'Premiações',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.0,
                ),
          ),
          centerTitle: true,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Dia'),
              Tab(text: 'Semana'),
              Tab(text: 'Mês'),
            ],
          ),
        ),
        body: SafeArea(
          top: true,
          child: _isCheckingPlan
              ? Center(
                  child: CircularProgressIndicator(
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                )
              : !_hasActivePlan
                  ? _buildNoPlanView()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildDayPremiacaoTab(),
                        _buildWeekPremiacaoTab(),
                        _buildMonthPremiacaoTab(),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildDayPremiacaoTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
          child: InkWell(
            onTap: _showCalendarDialog,
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: FlutterFlowTheme.of(context).alternate,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: FlutterFlowTheme.of(context).primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDate),
                        style: FlutterFlowTheme.of(context).titleMedium.override(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.0,
                            ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: FlutterFlowTheme.of(context).secondaryText,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                )
              : _photoOfTheDay == null || _photoOfTheDay!.photoData == null
                  ? _buildEmptyState()
                  : _buildPhotoOfTheDayCard(),
        ),
      ],
    );
  }

  Widget _buildWeekPremiacaoTab() {
    final start = PhotoAwardsService.weekStartMonday(_selectedWeekDay);
    final end = start.add(const Duration(days: 6));
    final label =
        '${DateFormat('dd/MM', 'pt_BR').format(start)} – ${DateFormat('dd/MM/yyyy', 'pt_BR').format(end)}';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
          child: InkWell(
            onTap: _pickWeekForPremiacoes,
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: FlutterFlowTheme.of(context).alternate,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_view_week,
                        color: FlutterFlowTheme.of(context).primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: FlutterFlowTheme.of(context).titleMedium.override(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.0,
                            ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: FlutterFlowTheme.of(context).secondaryText,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: _loadingWeek
              ? Center(
                  child: CircularProgressIndicator(
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                )
              : _photoOfTheWeek == null || _photoOfTheWeek!.photoData == null
                  ? _buildEmptyWeekState()
                  : _buildPhotoOfTheWeekCard(),
        ),
      ],
    );
  }

  Widget _buildMonthPremiacaoTab() {
    final label =
        DateFormat('MMMM yyyy', 'pt_BR').format(_selectedMonthFirst);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
          child: InkWell(
            onTap: _pickMonthForPremiacoes,
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: FlutterFlowTheme.of(context).alternate,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_month,
                        color: FlutterFlowTheme.of(context).primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        label,
                        style: FlutterFlowTheme.of(context).titleMedium.override(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.0,
                            ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: FlutterFlowTheme.of(context).secondaryText,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: _loadingMonth
              ? Center(
                  child: CircularProgressIndicator(
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                )
              : _photoOfTheMonth == null || _photoOfTheMonth!.photoData == null
                  ? _buildEmptyMonthState()
                  : _buildPhotoOfTheMonthCard(),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.trophy,
            size: 64,
            color: FlutterFlowTheme.of(context).secondaryText.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma foto do dia selecionada',
            style: FlutterFlowTheme.of(context).titleMedium.override(
                  fontFamily: 'Poppins',
                  color: FlutterFlowTheme.of(context).secondaryText,
                  letterSpacing: 0.0,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Selecione outra data para ver fotos premiadas',
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  fontFamily: 'Poppins',
                  color: FlutterFlowTheme.of(context).secondaryText,
                  letterSpacing: 0.0,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWeekState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.trophy,
            size: 64,
            color: FlutterFlowTheme.of(context).secondaryText.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma foto da semana selecionada',
            style: FlutterFlowTheme.of(context).titleMedium.override(
                  fontFamily: 'Poppins',
                  color: FlutterFlowTheme.of(context).secondaryText,
                  letterSpacing: 0.0,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Escolha outra semana ou aguarde a seleção do admin',
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  fontFamily: 'Poppins',
                  color: FlutterFlowTheme.of(context).secondaryText,
                  letterSpacing: 0.0,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMonthState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FontAwesomeIcons.trophy,
            size: 64,
            color: FlutterFlowTheme.of(context).secondaryText.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma foto do mês selecionada',
            style: FlutterFlowTheme.of(context).titleMedium.override(
                  fontFamily: 'Poppins',
                  color: FlutterFlowTheme.of(context).secondaryText,
                  letterSpacing: 0.0,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Escolha outro mês ou aguarde a seleção do admin',
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  fontFamily: 'Poppins',
                  color: FlutterFlowTheme.of(context).secondaryText,
                  letterSpacing: 0.0,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoOfTheDayCard() {
    final pd = _photoOfTheDay?.photoData;
    if (pd == null) return const SizedBox.shrink();
    return _buildPremiadaCard(
      awardTitle: 'Foto do Dia',
      periodLabel: DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDate),
      photoData: pd,
      urlImagemSelo: _photoOfTheDay?.urlImagemSelo,
      badgeKind: TrophyAwardKind.day,
      downloadBaseName:
          'foto_do_dia_${DateFormat('yyyyMMdd', 'pt_BR').format(_selectedDate)}',
    );
  }

  Widget _buildPhotoOfTheWeekCard() {
    final pd = _photoOfTheWeek?.photoData;
    if (pd == null) return const SizedBox.shrink();
    final start = PhotoAwardsService.weekStartMonday(_selectedWeekDay);
    final end = start.add(const Duration(days: 6));
    final label =
        '${DateFormat('dd/MM', 'pt_BR').format(start)} – ${DateFormat('dd/MM/yyyy', 'pt_BR').format(end)}';
    return _buildPremiadaCard(
      awardTitle: 'Foto da Semana',
      periodLabel: label,
      photoData: pd,
      urlImagemSelo: _photoOfTheWeek?.urlImagemSelo,
      badgeKind: TrophyAwardKind.week,
      downloadBaseName:
          'foto_semana_${DateFormat('yyyyMMdd', 'pt_BR').format(start)}',
    );
  }

  Widget _buildPhotoOfTheMonthCard() {
    final pd = _photoOfTheMonth?.photoData;
    if (pd == null) return const SizedBox.shrink();
    return _buildPremiadaCard(
      awardTitle: 'Foto do Mês',
      periodLabel:
          DateFormat('MMMM yyyy', 'pt_BR').format(_selectedMonthFirst),
      photoData: pd,
      urlImagemSelo: _photoOfTheMonth?.urlImagemSelo,
      badgeKind: TrophyAwardKind.month,
      downloadBaseName:
          'foto_mes_${_selectedMonthFirst.year}${_selectedMonthFirst.month.toString().padLeft(2, '0')}',
    );
  }

  Widget _buildPremiadaCard({
    required String awardTitle,
    required String periodLabel,
    required PhotoData photoData,
    required String? urlImagemSelo,
    required TrophyAwardKind badgeKind,
    required String downloadBaseName,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Trophy Header
          Container(
            width: double.infinity,
            padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  FlutterFlowTheme.of(context).primary,
                  FlutterFlowTheme.of(context).primary.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  FontAwesomeIcons.trophy,
                  size: 48,
                  color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  awardTitle,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  periodLabel,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Photo Image
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: photoData.imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 300,
                    color: FlutterFlowTheme.of(context).alternate,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: FlutterFlowTheme.of(context).primary,
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 300,
                    color: FlutterFlowTheme.of(context).alternate,
                    child: Icon(
                      Icons.broken_image,
                      size: 48,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: PhotoTrophyBadge(
                    size: TrophyBadgeSize.large,
                    kind: badgeKind,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Botão de download (apenas se url_imagem_selo estiver preenchido)
          if (urlImagemSelo != null && urlImagemSelo.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 24),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _downloadPhotoWithSeloUrl(
                    urlImagemSelo,
                    downloadBaseName,
                  ),
                  icon: Icon(
                    FontAwesomeIcons.download,
                    size: 20,
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                  label: Text(
                    'Baixar foto com selo',
                    style: FlutterFlowTheme.of(context).titleSmall.override(
                          fontFamily: 'Poppins',
                          color: FlutterFlowTheme.of(context).primary,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.0,
                        ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                      color: FlutterFlowTheme.of(context).primary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

          // Author Info
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: FlutterFlowTheme.of(context).alternate,
                backgroundImage: photoData.userAvatarUrl != null
                    ? CachedNetworkImageProvider(photoData.userAvatarUrl!)
                    : null,
                child: photoData.userAvatarUrl == null
                    ? Icon(
                        Icons.person,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      photoData.username ?? 'Usuário',
                      style: FlutterFlowTheme.of(context).titleMedium.override(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.0,
                          ),
                    ),
                    Text(
                      'Fotógrafo premiado',
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            fontFamily: 'Poppins',
                            color: FlutterFlowTheme.of(context).secondaryText,
                            letterSpacing: 0.0,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Score
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: FlutterFlowTheme.of(context).alternate,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star,
                  color: const Color(0xFFFFD700),
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  photoData.score.toStringAsFixed(1),
                  style: GoogleFonts.poppins(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: FlutterFlowTheme.of(context).primaryText,
                  ),
                ),
                Text(
                  ' / 10',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Positive Points
          if (photoData.positivePoints.isNotEmpty) ...[
            Text(
              'Pontos Positivos',
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.0,
                  ),
            ),
            const SizedBox(height: 12),
            ...photoData.positivePoints.map((point) => Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: FlutterFlowTheme.of(context).success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          point,
                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                fontFamily: 'Poppins',
                                letterSpacing: 0.0,
                              ),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 24),
          ],

          // Improvement Points
          if (photoData.improvementPoints.isNotEmpty) ...[
            Text(
              'Pontos de Melhoria',
              style: FlutterFlowTheme.of(context).titleMedium.override(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.0,
                  ),
            ),
            const SizedBox(height: 12),
            ...photoData.improvementPoints.map((point) => Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: FlutterFlowTheme.of(context).warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          point,
                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                fontFamily: 'Poppins',
                                letterSpacing: 0.0,
                              ),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 24),
          ],

          // Observação
          if (photoData.observacao != null && photoData.observacao!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: FlutterFlowTheme.of(context).secondaryBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: FlutterFlowTheme.of(context).alternate,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Observação',
                    style: FlutterFlowTheme.of(context).titleSmall.override(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.0,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    photoData.observacao!,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'Poppins',
                          letterSpacing: 0.0,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoPlanView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.medal,
              size: 64,
              color: FlutterFlowTheme.of(context).secondaryText,
            ),
            const SizedBox(height: 24),
            Text(
              'Participe das Premiações!',
              style: FlutterFlowTheme.of(context).headlineMedium.override(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.0,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Para participar e visualizar as fotos do dia premiadas, você precisa fazer uma assinatura de um plano pago.',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'Poppins',
                    letterSpacing: 0.0,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => PlansNavigationHelper.navigateToPlans(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: FlutterFlowTheme.of(context).primary,
                padding: const EdgeInsetsDirectional.fromSTEB(24, 12, 24, 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Assinar Plano',
                style: FlutterFlowTheme.of(context).titleMedium.override(
                      fontFamily: 'Poppins',
                      color: FlutterFlowTheme.of(context).primaryBackground,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget de calendário customizado para dialog
class _CalendarDialog extends StatefulWidget {
  final DateTime selectedDate;
  final Map<DateTime, String> calendarPhotos;
  final Function(DateTime) onDateSelected;
  final PhotoOfTheDayService photoOfTheDayService;

  const _CalendarDialog({
    required this.selectedDate,
    required this.calendarPhotos,
    required this.onDateSelected,
    required this.photoOfTheDayService,
  });

  @override
  State<_CalendarDialog> createState() => _CalendarDialogState();
}

class _CalendarDialogState extends State<_CalendarDialog> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;
  Map<DateTime, String> _calendarPhotos = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    _currentMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _calendarPhotos = Map.from(widget.calendarPhotos);
  }

  Future<void> _changeMonth(int delta) async {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta);
      _isLoading = true;
    });
    
    // Carregar dados do novo mês
    try {
      final photos = await widget.photoOfTheDayService.getPhotosOfTheDayCalendar(
        _currentMonth.year,
        _currentMonth.month,
      );
      setState(() {
        _calendarPhotos = photos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Month Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left,
                    color: FlutterFlowTheme.of(context).primaryText,
                  ),
                  onPressed: _isLoading ? null : () => _changeMonth(-1),
                ),
                _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        DateFormat('MMMM yyyy', 'pt_BR').format(_currentMonth),
                        style: FlutterFlowTheme.of(context).titleMedium.override(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.0,
                            ),
                      ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    color: FlutterFlowTheme.of(context).primaryText,
                  ),
                  onPressed: _isLoading ? null : () => _changeMonth(1),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Weekday Headers
            Row(
              children: ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
                  .map((day) => Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: FlutterFlowTheme.of(context).bodySmall.override(
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),

            // Calendar Days
            ...List.generate(
              (daysInMonth + firstWeekday - 1) ~/ 7 + 1,
              (weekIndex) {
                return Row(
                  children: List.generate(7, (dayIndex) {
                    final dayNumber = weekIndex * 7 + dayIndex - firstWeekday + 2;
                    if (dayNumber < 1 || dayNumber > daysInMonth) {
                      return const Expanded(child: SizedBox());
                    }

                    final dayDate = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
                    final isSelected = dayDate.year == _selectedDate.year &&
                        dayDate.month == _selectedDate.month &&
                        dayDate.day == _selectedDate.day;
                    
                    // Normalizar a data para comparação (remover hora)
                    final normalizedDayDate = DateTime(dayDate.year, dayDate.month, dayDate.day);
                    final hasPhoto = _calendarPhotos.keys.any((date) =>
                        date.year == normalizedDayDate.year &&
                        date.month == normalizedDayDate.month &&
                        date.day == normalizedDayDate.day);
                    
                    final isToday = dayDate.year == DateTime.now().year &&
                        dayDate.month == DateTime.now().month &&
                        dayDate.day == DateTime.now().day;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDate = dayDate;
                          });
                          widget.onDateSelected(dayDate);
                        },
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          height: 40,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? FlutterFlowTheme.of(context).primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: isToday
                                ? Border.all(
                                    color: FlutterFlowTheme.of(context).primary,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                dayNumber.toString(),
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                      fontFamily: 'Poppins',
                                      color: isSelected
                                          ? Colors.white
                                          : FlutterFlowTheme.of(context).primaryText,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                              if (hasPhoto)
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Icon(
                                    FontAwesomeIcons.trophy,
                                    size: 10,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFFFFD700),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            const SizedBox(height: 16),
            // Botão de fechar
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: FlutterFlowTheme.of(context).primary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Fechar',
                style: FlutterFlowTheme.of(context).titleMedium.override(
                      fontFamily: 'Poppins',
                      color: FlutterFlowTheme.of(context).primaryBackground,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

