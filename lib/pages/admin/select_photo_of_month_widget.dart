// lib/pages/admin/select_photo_of_month_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../services/photo_awards_service.dart';
import '../../services/report_service.dart';
import '../../models/photo_model.dart';
import '../../models/photo_of_week_month_models.dart';
import '../../utils/logger.dart';
import 'select_photo_of_month_model.dart';
export 'select_photo_of_month_model.dart';

class SelectPhotoOfMonthWidget extends StatefulWidget {
  const SelectPhotoOfMonthWidget({super.key});

  static String routeName = 'selectPhotoOfMonth';
  static String routePath = '/admin/select-photo-of-month';

  @override
  State<SelectPhotoOfMonthWidget> createState() => _SelectPhotoOfMonthWidgetState();
}

class _SelectPhotoOfMonthWidgetState extends State<SelectPhotoOfMonthWidget> {
  late SelectPhotoOfMonthModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late PhotoAwardsService _awardsService;
  ReportService? _reportService;
  bool _servicesInitialized = false;
  bool _isAdmin = false;
  DateTime _monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<PhotoModel> _candidatePhotos = [];
  PhotoOfTheMonthModel? _currentMonth;
  bool _isLoading = false;
  bool _isSelecting = false;
  bool _isRemoving = false;

  String get _monthLabel =>
      DateFormat('MMMM yyyy', 'pt_BR').format(_monthStart);

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SelectPhotoOfMonthModel());
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _awardsService = PhotoAwardsService(supabaseService);
      _reportService = ReportService(supabaseService);

      final isAdmin = await _reportService!.isCurrentUserAdmin();
      if (!isAdmin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Acesso negado. Apenas administradores podem acessar esta página.',
              ),
              backgroundColor: FlutterFlowTheme.of(context).error,
            ),
          );
          context.safePop();
        }
        return;
      }

      setState(() {
        _isAdmin = true;
        _servicesInitialized = true;
      });

      await _loadAll();
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

  Future<void> _loadAll() async {
    if (!_servicesInitialized) return;
    setState(() => _isLoading = true);
    try {
      final candidates = await _awardsService.getCandidatePhotosForMonth(
        _monthStart.year,
        _monthStart.month,
      );
      final current = await _awardsService.getPhotoOfTheMonth(_monthStart);
      setState(() {
        _candidatePhotos = candidates;
        _currentMonth = current;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar mês', e, stackTrace);
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _monthStart,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
      helpText: 'Selecione qualquer dia do mês',
    );
    if (picked != null && mounted) {
      setState(() {
        _monthStart = DateTime(picked.year, picked.month, 1);
      });
      await _loadAll();
    }
  }

  Future<void> _removeSelection() async {
    if (_currentMonth == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover seleção'),
        content: Text('Remover a foto do mês de $_monthLabel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _isRemoving = true);
    try {
      await _awardsService.removePhotoOfTheMonth(_monthStart);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Seleção removida.'),
            backgroundColor: FlutterFlowTheme.of(context).success,
          ),
        );
      }
      await _loadAll();
    } catch (e, stackTrace) {
      Logger.error('Erro ao remover foto do mês', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRemoving = false);
    }
  }

  Future<void> _selectPhoto(PhotoModel photo) async {
    final has = _currentMonth != null;
    final message = has
        ? 'Já existe foto do mês ($_monthLabel). Substituir?'
        : 'Selecionar esta foto como foto do mês ($_monthLabel)?';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSelecting = true);
    try {
      await _awardsService.selectPhotoOfTheMonth(photo.id, _monthStart);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Foto do mês selecionada!'),
            backgroundColor: FlutterFlowTheme.of(context).success,
          ),
        );
      }
      await _loadAll();
    } catch (e, stackTrace) {
      Logger.error('Erro ao selecionar foto do mês', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSelecting = false);
    }
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isAdmin) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final featured = _currentMonth?.photoData;

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
            'Foto do Mês',
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
                child: InkWell(
                  onTap: _pickMonth,
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
                              _monthLabel,
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
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
                child: Container(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: FlutterFlowTheme.of(context).primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Candidatas: fotos da semana já escolhidas para semanas que intersectam este mês.',
                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                fontFamily: 'Poppins',
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (featured != null)
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FlutterFlowTheme.of(context).alternate),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selecionada',
                          style: FlutterFlowTheme.of(context).titleSmall.override(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: featured.thumbnailUrl ?? featured.imageUrl,
                                width: 72,
                                height: 72,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                featured.username ?? 'Usuário',
                                style: FlutterFlowTheme.of(context).bodyMedium,
                              ),
                            ),
                            TextButton(
                              onPressed: _isRemoving ? null : _removeSelection,
                              child: _isRemoving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Remover'),
                            ),
                          ],
                        ),
                      ],
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
                    : _candidatePhotos.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhuma foto da semana neste mês. Defina antes as fotos da semana.',
                              textAlign: TextAlign.center,
                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                    color: FlutterFlowTheme.of(context).secondaryText,
                                  ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
                            itemCount: _candidatePhotos.length,
                            itemBuilder: (context, index) =>
                                _buildPhotoCard(_candidatePhotos[index]),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoCard(PhotoModel photo) {
    return GestureDetector(
      onTap: () => context.push('/photo-detail/${photo.id}'),
      child: Container(
        margin: const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 16),
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
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: CachedNetworkImage(
                imageUrl: photo.thumbnailUrl ?? photo.imageUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: FlutterFlowTheme.of(context).alternate,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: FlutterFlowTheme.of(context).primary,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: FlutterFlowTheme.of(context).alternate,
                  child: Icon(
                    Icons.broken_image,
                    size: 48,
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage: photo.userAvatarUrl != null
                            ? CachedNetworkImageProvider(photo.userAvatarUrl!)
                            : null,
                        child: photo.userAvatarUrl == null
                            ? const Icon(Icons.person, size: 16)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          photo.username ?? 'Usuário',
                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                fontFamily: 'Poppins',
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSelecting ? null : () => _selectPhoto(photo),
                      icon: _isSelecting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(FontAwesomeIcons.trophy),
                      label: const Text('Selecionar como Foto do Mês'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FlutterFlowTheme.of(context).primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
    );
  }
}
