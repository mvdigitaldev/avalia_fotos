// lib/pages/premiacoes/premiacoes_widget.dart
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
import '../../services/plan_service.dart';
import '../../services/auth_service.dart';
import '../../models/photo_of_the_day_model.dart';
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

class _PremiacoesWidgetState extends State<PremiacoesWidget> {
  PremiacoesModel? _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late PhotoOfTheDayService _photoOfTheDayService;
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

  @override
  void initState() {
    super.initState();
    // Apenas inicializações que não dependem de context
    _selectedDate = DateTime.now();
    _currentMonth = DateTime.now();
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
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _photoOfTheDayService = PhotoOfTheDayService(supabaseService);
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

  Future<void> _downloadPhotoWithSelo() async {
    final urlImagemSelo = _photoOfTheDay?.urlImagemSelo;
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
        name: 'foto_do_dia_${DateFormat('yyyyMMdd', 'pt_BR').format(_selectedDate)}',
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
      Logger.error('Erro ao baixar foto do dia', e, stackTrace);
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
            'Foto do Dia',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.0,
                ),
          ),
          centerTitle: true,
          elevation: 0,
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
                  : Column(
                      children: [
                        // Date Picker Button
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

                        // Photo of the Day Display
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
                    ),
        ),
      ),
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

  Widget _buildPhotoOfTheDayCard() {
    final photoData = _photoOfTheDay!.photoData!;

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
                  'Foto do Dia',
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDate),
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
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Botão de download (apenas se url_imagem_selo estiver preenchido)
          if (_photoOfTheDay!.urlImagemSelo != null &&
              _photoOfTheDay!.urlImagemSelo!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 24),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _downloadPhotoWithSelo,
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

