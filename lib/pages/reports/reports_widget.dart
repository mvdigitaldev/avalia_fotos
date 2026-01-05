// lib/pages/reports/reports_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../services/supabase_service.dart';
import '../../services/report_service.dart';
import '../../services/photo_service.dart';
import '../../models/report_model.dart';
import '../../models/photo_model.dart';
import '../../utils/logger.dart';
import 'reports_model.dart';
export 'reports_model.dart';

class ReportsWidget extends StatefulWidget {
  const ReportsWidget({super.key});

  static String routeName = 'reports';
  static String routePath = '/reports';

  @override
  State<ReportsWidget> createState() => _ReportsWidgetState();
}

class _ReportsWidgetState extends State<ReportsWidget> {
  ReportsModel _model = ReportsModel();
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late ReportService _reportService;
  late PhotoService _photoService;
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    _model = ReportsModel();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _reportService = ReportService(supabaseService);
      _photoService = PhotoService(supabaseService);
      
      // Verificar se é admin
      final isAdmin = await _reportService.isCurrentUserAdmin();
      if (!isAdmin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Acesso negado. Apenas administradores podem acessar esta página.'),
              backgroundColor: FlutterFlowTheme.of(context).error,
            ),
          );
          context.pop();
        }
        return;
      }

      if (mounted) {
        setState(() {
          _servicesInitialized = true;
        });
      }
      
      await _loadPendingCount();
      await _loadReports();
    } catch (e, stackTrace) {
      Logger.error('Erro ao inicializar serviços', e, stackTrace);
      safeSetState(() {
        _model.isLoading = false;
        _model.errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadPendingCount() async {
    try {
      final count = await _reportService.getPendingReportsCount();
      if (mounted) {
        setState(() {
          _model.pendingCount = count;
        });
      }
    } catch (e) {
      Logger.error('Erro ao carregar contagem de denúncias pendentes', e, StackTrace.current);
    }
  }

  Future<void> _loadReports() async {
      setState(() {
        _model.isLoading = true;
        _model.errorMessage = null;
      });

    try {
      final reports = await _reportService.getReports(
        status: _model.selectedFilter,
        limit: 100,
      );

      setState(() {
        _model.reports = reports;
        _model.isLoading = false;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar denúncias', e, stackTrace);
      if (mounted) {
        setState(() {
          _model.isLoading = false;
          _model.errorMessage = e.toString();
        });
      }
    }
  }

  Future<void> _approveReport(ReportModel report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Aprovar Denúncia'),
        content: Text('Tem certeza que deseja aprovar esta denúncia e deletar o conteúdo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: FlutterFlowTheme.of(context).error,
            ),
            child: Text('Deletar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _reportService.approveReport(report.id);
      await _loadReports();
      await _loadPendingCount();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Denúncia aprovada e conteúdo deletado'),
            backgroundColor: FlutterFlowTheme.of(context).success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aprovar denúncia: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _rejectReport(ReportModel report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Descartar Denúncia'),
        content: Text('Tem certeza que deseja descartar esta denúncia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Descartar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _reportService.rejectReport(report.id);
      await _loadReports();
      await _loadPendingCount();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Denúncia descartada'),
            backgroundColor: FlutterFlowTheme.of(context).success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao descartar denúncia: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
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
          automaticallyImplyLeading: true,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 30.0,
            ),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Denúncias',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  fontFamily: 'Poppins',
                  letterSpacing: 0.0,
                ),
          ),
          centerTitle: false,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: !_servicesInitialized
              ? Center(child: CircularProgressIndicator())
              : _model.isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _model.errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Erro: ${_model.errorMessage}'),
                              SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadReports,
                                child: Text('Tentar Novamente'),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          children: [
                            // Filtros
                            Container(
                              padding: EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ChoiceChip(
                                      label: Text('Pendentes (${_model.pendingCount})'),
                                      selected: _model.selectedFilter == ReportStatus.pending,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _model.selectedFilter = ReportStatus.pending;
                                          });
                                          _loadReports();
                                        }
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: ChoiceChip(
                                      label: Text('Aprovadas'),
                                      selected: _model.selectedFilter == ReportStatus.approved,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _model.selectedFilter = ReportStatus.approved;
                                          });
                                          _loadReports();
                                        }
                                      },
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: ChoiceChip(
                                      label: Text('Rejeitadas'),
                                      selected: _model.selectedFilter == ReportStatus.rejected,
                                      onSelected: (selected) {
                                        if (selected) {
                                          setState(() {
                                            _model.selectedFilter = ReportStatus.rejected;
                                          });
                                          _loadReports();
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Lista de denúncias
                            Expanded(
                              child: _model.reports.isEmpty
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.report_problem_outlined,
                                            size: 64,
                                            color: FlutterFlowTheme.of(context).secondary,
                                          ),
                                          Padding(
                                            padding: EdgeInsetsDirectional.fromSTEB(0, 16, 0, 0),
                                            child: Text(
                                              'Nenhuma denúncia encontrada',
                                              style: FlutterFlowTheme.of(context).titleMedium,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : RefreshIndicator(
                                      onRefresh: _loadReports,
                                      child: ListView.builder(
                                        padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
                                        itemCount: _model.reports.length,
                                        itemBuilder: (context, index) {
                                          final report = _model.reports[index];
                                          return _buildReportCard(report);
                                        },
                                      ),
                                    ),
                            ),
                          ],
                        ),
        ),
      ),
    );
  }

  Widget _buildReportCard(ReportModel report) {
    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 16),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagem do post (se for foto e ainda existir)
                if (report.photoId != null && report.photoImageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: report.photoImageUrl!,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (report.photoId == null && report.reportType == ReportType.photo)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).alternate.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: FlutterFlowTheme.of(context).secondary,
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.image_not_supported,
                      color: FlutterFlowTheme.of(context).secondary,
                      size: 32,
                    ),
                  ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Denúncia de ${report.reportType == ReportType.photo ? "Foto" : "Comentário"}',
                        style: FlutterFlowTheme.of(context).titleMedium.override(
                              font: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                              letterSpacing: 0.0,
                            ),
                      ),
                      if (report.photoId == null || report.commentId == null) ...[
                        SizedBox(height: 4),
                        Container(
                          padding: EdgeInsetsDirectional.fromSTEB(6, 4, 6, 4),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).warning.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Conteúdo já foi deletado',
                            style: FlutterFlowTheme.of(context).bodySmall.override(
                                  font: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                  color: FlutterFlowTheme.of(context).warning,
                                  fontSize: 10.0,
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ),
                      ],
                      SizedBox(height: 4),
                      Text(
                        'Motivo: ${ReportReasons.displayNames[report.reason] ?? report.reason}',
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.poppins(),
                              letterSpacing: 0.0,
                            ),
                      ),
                      if (report.description != null && report.description!.isNotEmpty) ...[
                        SizedBox(height: 4),
                        Text(
                          report.description!,
                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                font: GoogleFonts.poppins(),
                                color: FlutterFlowTheme.of(context).secondary,
                                letterSpacing: 0.0,
                              ),
                        ),
                      ],
                      if (report.commentId != null && report.commentContent != null) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).alternate.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            report.commentContent!,
                            style: FlutterFlowTheme.of(context).bodySmall.override(
                                  font: GoogleFonts.poppins(),
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ),
                      ],
                      if (report.commentId == null && report.reportType == ReportType.comment) ...[
                        SizedBox(height: 8),
                        Container(
                          padding: EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).alternate.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).secondary,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: FlutterFlowTheme.of(context).secondary,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Conteúdo do comentário não está mais disponível (foi deletado)',
                                  style: FlutterFlowTheme.of(context).bodySmall.override(
                                        font: GoogleFonts.poppins(),
                                        color: FlutterFlowTheme.of(context).secondary,
                                        fontSize: 11.0,
                                        letterSpacing: 0.0,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      SizedBox(height: 8),
                      Text(
                        'Denunciado por: ${report.reporterUsername ?? "Usuário"}',
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              font: GoogleFonts.poppins(),
                              color: FlutterFlowTheme.of(context).secondary,
                              letterSpacing: 0.0,
                            ),
                      ),
                      Text(
                        timeago.format(report.createdAt, locale: 'pt_BR'),
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              font: GoogleFonts.poppins(),
                              color: FlutterFlowTheme.of(context).secondary,
                              letterSpacing: 0.0,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (report.status == ReportStatus.pending) ...[
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _rejectReport(report),
                    child: Text('Descartar'),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _approveReport(report),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlutterFlowTheme.of(context).error,
                      foregroundColor: Colors.white,
                      padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
                      minimumSize: Size(0, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Deletar Post',
                      style: FlutterFlowTheme.of(context).titleSmall.override(
                            font: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                            color: Colors.white,
                            letterSpacing: 0.0,
                          ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(height: 8),
              Container(
                padding: EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
                decoration: BoxDecoration(
                  color: report.status == ReportStatus.approved
                      ? FlutterFlowTheme.of(context).success.withOpacity(0.1)
                      : FlutterFlowTheme.of(context).secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Status: ${report.status.displayName}',
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                        color: report.status == ReportStatus.approved
                            ? FlutterFlowTheme.of(context).success
                            : FlutterFlowTheme.of(context).secondary,
                        letterSpacing: 0.0,
                      ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }
}

