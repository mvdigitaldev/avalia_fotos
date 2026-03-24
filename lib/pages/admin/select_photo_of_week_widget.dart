// lib/pages/admin/select_photo_of_week_widget.dart
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
import 'select_photo_of_week_model.dart';
export 'select_photo_of_week_model.dart';

class SelectPhotoOfWeekWidget extends StatefulWidget {
  const SelectPhotoOfWeekWidget({super.key});

  static String routeName = 'selectPhotoOfWeek';
  static String routePath = '/admin/select-photo-of-week';

  @override
  State<SelectPhotoOfWeekWidget> createState() => _SelectPhotoOfWeekWidgetState();
}

class _SelectPhotoOfWeekWidgetState extends State<SelectPhotoOfWeekWidget> {
  late SelectPhotoOfWeekModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late PhotoAwardsService _awardsService;
  ReportService? _reportService;
  bool _servicesInitialized = false;
  bool _isAdmin = false;
  DateTime _weekAnyDay = DateTime.now();
  List<PhotoModel> _candidatePhotos = [];
  PhotoOfTheWeekModel? _currentWeek;
  bool _isLoading = false;
  bool _isSelecting = false;
  bool _isRemoving = false;

  DateTime get _weekMonday => PhotoAwardsService.weekStartMonday(_weekAnyDay);

  String get _weekRangeLabel {
    final start = _weekMonday;
    final end = start.add(const Duration(days: 6));
    return '${DateFormat('dd/MM', 'pt_BR').format(start)} – ${DateFormat('dd/MM/yyyy', 'pt_BR').format(end)}';
  }

  String get _weekMetaSubtitle {
    final m = PhotoAwardsService.isoWeekMeta(_weekAnyDay);
    return 'Semana ${m.week} de ${m.weekYear} (segunda a domingo)';
  }

  String get _candidatasInfoDetail {
    if (_isLoading) return 'Carregando…';
    final n = _candidatePhotos.length;
    if (n == 0) {
      return 'Nenhum dia deste período tem foto do dia cadastrada ainda.';
    }
    if (n < 7) {
      return 'Há $n dia(s) com foto do dia neste período (até 7). Você já pode escolher a foto da semana entre essas fotos.';
    }
    return 'Os 7 dias têm foto do dia; escolha uma delas como foto da semana.';
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SelectPhotoOfWeekModel());
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
      final candidates = await _awardsService.getCandidatePhotosForWeek(_weekAnyDay);
      final current = await _awardsService.getPhotoOfTheWeek(_weekAnyDay);
      setState(() {
        _candidatePhotos = candidates;
        _currentWeek = current;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar semana', e, stackTrace);
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

  Future<void> _pickWeek() async {
    final now = DateTime.now();
    final initial = PhotoAwardsService.isoWeekMeta(_weekAnyDay);
    int selYear = initial.weekYear;
    int selWeek = initial.week;

    int capFor(int year) {
      final total = PhotoAwardsService.isoWeeksInIsoYear(year);
      final maxW = PhotoAwardsService.maxSelectableIsoWeekForYear(year, now);
      return total < maxW ? total : maxW;
    }

    selWeek = selWeek.clamp(1, capFor(selYear));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final lastYear = PhotoAwardsService.isoWeekMeta(now).weekYear;
        final years = List.generate(lastYear - 2020 + 1, (i) => 2020 + i);

        return StatefulBuilder(
          builder: (context, setLocal) {
            final cap = capFor(selYear);
            final weeks = List.generate(cap, (i) => i + 1);

            return AlertDialog(
              title: const Text('Escolher semana'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Cada opção mostra o intervalo de segunda a domingo.',
                      style: FlutterFlowTheme.of(context).bodySmall,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      value: selYear,
                      decoration: const InputDecoration(
                        labelText: 'Ano',
                        border: OutlineInputBorder(),
                      ),
                      items: years
                          .map(
                            (y) => DropdownMenuItem(value: y, child: Text('$y')),
                          )
                          .toList(),
                      onChanged: (y) {
                        if (y == null) return;
                        setLocal(() {
                          selYear = y;
                          final c = capFor(y);
                          if (selWeek > c) selWeek = c;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: selWeek,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Semana do ano (com datas)',
                        border: OutlineInputBorder(),
                      ),
                      items: weeks
                          .map(
                            (w) => DropdownMenuItem(
                              value: w,
                              child: Text(
                                PhotoAwardsService.weekOptionLabel(selYear, w),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (w) {
                        if (w == null) return;
                        setLocal(() => selWeek = w);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    setState(() {
                      _weekAnyDay =
                          PhotoAwardsService.mondayOfIsoWeek(selYear, selWeek);
                    });
                    _loadAll();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _removeSelection() async {
    if (_currentWeek == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover seleção'),
        content: Text('Remover a foto da semana de $_weekRangeLabel?'),
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
      await _awardsService.removePhotoOfTheWeek(_weekAnyDay);
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
      Logger.error('Erro ao remover foto da semana', e, stackTrace);
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
    final has = _currentWeek != null;
    final message = has
        ? 'Já existe foto da semana ($_weekRangeLabel). Substituir?'
        : 'Selecionar esta foto como foto da semana ($_weekRangeLabel)?';
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
      await _awardsService.selectPhotoOfTheWeek(photo.id, _weekAnyDay);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Foto da semana selecionada!'),
            backgroundColor: FlutterFlowTheme.of(context).success,
          ),
        );
      }
      await _loadAll();
    } catch (e, stackTrace) {
      Logger.error('Erro ao selecionar foto da semana', e, stackTrace);
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

    final featured = _currentWeek?.photoData;

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
            'Foto da Semana',
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
                  onTap: _pickWeek,
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
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_view_week,
                                color: FlutterFlowTheme.of(context).primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _weekRangeLabel,
                                      style: FlutterFlowTheme.of(context).titleMedium.override(
                                            fontFamily: 'Poppins',
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.0,
                                          ),
                                    ),
                                    Text(
                                      _weekMetaSubtitle,
                                      style: FlutterFlowTheme.of(context).labelSmall.override(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: FlutterFlowTheme.of(context).primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Candidatas são as fotos já marcadas como foto do dia em algum dia entre $_weekRangeLabel (segunda a domingo). Não é obrigatório ter os sete dias. $_candidatasInfoDetail',
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
                            child: Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                              child: Text(
                                'Nenhuma candidata ainda. Não há foto do dia cadastrada em nenhum dia entre $_weekRangeLabel. Defina a foto do dia nesses dias para elas aparecerem aqui.',
                                textAlign: TextAlign.center,
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                      color: FlutterFlowTheme.of(context).secondaryText,
                                    ),
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
                      label: const Text('Selecionar como Foto da Semana'),
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
