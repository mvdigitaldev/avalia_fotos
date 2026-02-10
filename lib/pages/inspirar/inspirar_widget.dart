// lib/pages/inspirar/inspirar_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../services/photo_service.dart';
import '../../services/plan_service.dart';
import '../../utils/logger.dart';
import '../../utils/plans_navigation_helper.dart';
import 'inspirar_model.dart';
export 'inspirar_model.dart';

class InspirarWidget extends StatefulWidget {
  const InspirarWidget({super.key});

  static String routeName = 'inspirar';
  static String routePath = '/inspirar';

  @override
  State<InspirarWidget> createState() => _InspirarWidgetState();
}

class _InspirarWidgetState extends State<InspirarWidget> {
  late InspirarModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late PhotoService _photoService;
  PlanService? _planService;
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => InspirarModel());
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _photoService = PhotoService(supabaseService);
      _planService = PlanService(supabaseService);

      final userId = supabaseService.currentUser?.id;
      if (userId != null) {
        final isFree = await _planService!.isUserOnFreePlan(userId);
        safeSetState(() {
          _model.isFreeUser = isFree;
        });
        if (!isFree) {
          await _loadCategories();
        }
      } else {
        safeSetState(() {
          _model.isFreeUser = true;
        });
      }

      setState(() {
        _servicesInitialized = true;
      });
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

  Future<void> _loadCategories() async {
    try {
      safeSetState(() {
        _model.isLoadingCategories = true;
      });
      final categories = await _photoService.getAvailableCategories();
      safeSetState(() {
        _model.availableCategories = categories;
        _model.isLoadingCategories = false;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar categorias', e, stackTrace);
      safeSetState(() {
        _model.isLoadingCategories = false;
      });
    }
  }

  void _onCategoryTap(String categoria) {
    context.push('/inspirar-categoria?categoria=${Uri.encodeQueryComponent(categoria)}');
  }

  @override
  void dispose() {
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
                padding: EdgeInsetsDirectional.fromSTEB(20, 16, 16, 16),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back,
                        color: FlutterFlowTheme.of(context).primaryText,
                        size: 24.0,
                      ),
                      onPressed: () => context.safePop(),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 0.0, 0.0),
                      child: Text(
                        'Para se Inspirar',
                        style: FlutterFlowTheme.of(context).titleLarge.override(
                              font: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                              letterSpacing: 0.0,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              // Conteúdo
              Expanded(
                child: !_servicesInitialized
                    ? Center(
                        child: CircularProgressIndicator(
                          color: FlutterFlowTheme.of(context).primary,
                        ),
                      )
                    : _model.isFreeUser == true
                        ? _buildUpgradeMessage()
                        : _buildCategoriesContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUpgradeMessage() {
    return Center(
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 80,
              color: FlutterFlowTheme.of(context).primary.withOpacity(0.6),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0, 24, 0, 0),
              child: Text(
                'Migre para um plano pago para ter acesso ao conteúdo inspirador!',
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).titleMedium.override(
                      font: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                      ),
                      color: FlutterFlowTheme.of(context).primaryText,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0, 24, 0, 0),
              child: ElevatedButton.icon(
                onPressed: () => PlansNavigationHelper.navigateToPlans(context),
                icon: Icon(
                  Icons.star_outline,
                  color: Colors.white,
                  size: 20,
                ),
                label: Text(
                  'Ver Planos',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                        color: Colors.white,
                        letterSpacing: 0.0,
                      ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlutterFlowTheme.of(context).primary,
                  padding: EdgeInsetsDirectional.fromSTEB(24, 14, 24, 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesContent() {
    if (_model.isLoadingCategories) {
      return Center(
        child: CircularProgressIndicator(
          color: FlutterFlowTheme.of(context).primary,
        ),
      );
    }

    if (_model.availableCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 80,
              color: FlutterFlowTheme.of(context).primary.withOpacity(0.5),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 24, 20, 0),
              child: Text(
                'Nenhuma categoria disponível no momento.',
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).titleMedium.override(
                      font: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                      ),
                      color: FlutterFlowTheme.of(context).primaryText,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCategories,
      color: FlutterFlowTheme.of(context).primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsetsDirectional.fromSTEB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _model.availableCategories.map((categoria) {
            return Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 12),
              child: GestureDetector(
                onTap: () => _onCategoryTap(categoria),
                child: Container(
                  constraints: BoxConstraints(minHeight: 80),
                  padding: EdgeInsetsDirectional.fromSTEB(16, 20, 16, 20),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 4,
                      color: Color(0x1A000000),
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primary.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.photo_library_outlined,
                        color: FlutterFlowTheme.of(context).primary,
                        size: 24,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(12, 0, 0, 0),
                        child: Text(
                          categoria,
                          style: FlutterFlowTheme.of(context).titleSmall.override(
                                font: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                                letterSpacing: 0.0,
                              ),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: FlutterFlowTheme.of(context).secondaryText,
                    ),
                  ],
                ),
              ),
            ),
          );
          }).toList(),
        ),
      ),
    );
  }
}

