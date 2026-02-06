// lib/pages/admin/select_photo_of_day_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../services/photo_of_the_day_service.dart';
import '../../services/report_service.dart';
import '../../models/photo_model.dart';
import '../../utils/logger.dart';
import 'select_photo_of_day_model.dart';
export 'select_photo_of_day_model.dart';

class SelectPhotoOfDayWidget extends StatefulWidget {
  const SelectPhotoOfDayWidget({super.key});

  static String routeName = 'selectPhotoOfDay';
  static String routePath = '/admin/select-photo-of-day';

  @override
  State<SelectPhotoOfDayWidget> createState() => _SelectPhotoOfDayWidgetState();
}

class _SelectPhotoOfDayWidgetState extends State<SelectPhotoOfDayWidget> {
  late SelectPhotoOfDayModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late PhotoOfTheDayService _photoOfTheDayService;
  ReportService? _reportService;
  bool _servicesInitialized = false;
  bool _isAdmin = false;
  DateTime _selectedDate = DateTime.now();
  List<PhotoModel> _candidatePhotos = [];
  bool _isLoading = false;
  bool _isSelecting = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SelectPhotoOfDayModel());
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _photoOfTheDayService = PhotoOfTheDayService(supabaseService);
      _reportService = ReportService(supabaseService);

      // Verificar se é admin
      final isAdmin = await _reportService!.isCurrentUserAdmin();
      if (!isAdmin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Acesso negado. Apenas administradores podem acessar esta página.'),
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

      await _loadCandidatePhotos();
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

  Future<void> _loadCandidatePhotos() async {
    if (!_servicesInitialized) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final photos = await _photoOfTheDayService.getCandidatePhotos(_selectedDate);
      setState(() {
        _candidatePhotos = photos;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar fotos candidatas', e, stackTrace);
      setState(() {
        _isLoading = false;
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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadCandidatePhotos();
    }
  }

  Future<void> _selectPhotoAsPhotoOfDay(PhotoModel photo) async {
    // Verificar se já existe foto do dia para esta data
    final canUndo = await _photoOfTheDayService.canUndoSelection(_selectedDate);
    final message = canUndo
        ? 'Já existe uma foto do dia para ${DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDate)}. Deseja substituir?'
        : 'Deseja selecionar esta foto como foto do dia de ${DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDate)}?';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmar Seleção'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isSelecting = true;
    });

    try {
      await _photoOfTheDayService.selectPhotoOfTheDay(photo.id, _selectedDate);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Foto do dia selecionada com sucesso!'),
            backgroundColor: FlutterFlowTheme.of(context).success,
          ),
        );

        // Recarregar lista
        await _loadCandidatePhotos();
      }
    } catch (e, stackTrace) {
      Logger.error('Erro ao selecionar foto do dia', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao selecionar foto: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSelecting = false;
        });
      }
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
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
            'Selecionar Foto do Dia',
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
              // Date Picker
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
                child: InkWell(
                  onTap: _selectDate,
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

              // Info
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
                          'Fotos ordenadas por maior nota. Apenas fotos compartilhadas de usuários com plano pago.',
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

              // Photos List
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: FlutterFlowTheme.of(context).primary,
                        ),
                      )
                    : _candidatePhotos.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.photo_library_outlined,
                                  size: 64,
                                  color: FlutterFlowTheme.of(context).secondaryText.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Nenhuma foto encontrada',
                                  style: FlutterFlowTheme.of(context).titleMedium.override(
                                        fontFamily: 'Poppins',
                                        color: FlutterFlowTheme.of(context).secondaryText,
                                        letterSpacing: 0.0,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Não há fotos compartilhadas de usuários com plano pago nesta data.',
                                  style: FlutterFlowTheme.of(context).bodySmall.override(
                                        fontFamily: 'Poppins',
                                        color: FlutterFlowTheme.of(context).secondaryText,
                                        letterSpacing: 0.0,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
                            itemCount: _candidatePhotos.length,
                            itemBuilder: (context, index) {
                              final photo = _candidatePhotos[index];
                              return _buildPhotoCard(photo);
                            },
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
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Stack(
              children: [
                CachedNetworkImage(
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
                // Score Badge
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 12, 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star,
                          color: const Color(0xFFFFD700),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          photo.score.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Info
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: FlutterFlowTheme.of(context).alternate,
                      backgroundImage: photo.userAvatarUrl != null
                          ? CachedNetworkImageProvider(photo.userAvatarUrl!)
                          : null,
                      child: photo.userAvatarUrl == null
                          ? Icon(
                              Icons.person,
                              size: 16,
                              color: FlutterFlowTheme.of(context).secondaryText,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        photo.username ?? 'Usuário',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.0,
                            ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Stats
                Row(
                  children: [
                    Icon(
                      Icons.favorite,
                      size: 16,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${photo.likesCount}',
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            fontFamily: 'Poppins',
                            letterSpacing: 0.0,
                          ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.comment,
                      size: 16,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${photo.commentsCount}',
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            fontFamily: 'Poppins',
                            letterSpacing: 0.0,
                          ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Select Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isSelecting
                        ? null
                        : () => _selectPhotoAsPhotoOfDay(photo),
                    icon: _isSelecting
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(FontAwesomeIcons.trophy),
                    label: Text('Selecionar como Foto do Dia'),
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

