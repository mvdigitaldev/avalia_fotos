import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../main.dart';
import '../../services/supabase_service.dart';
import '../../utils/logger.dart';
import '../../services/notification_service.dart';
import 'opcoes_model.dart';
export 'opcoes_model.dart';

class OpcoesWidget extends StatefulWidget {
  const OpcoesWidget({super.key});

  @override
  State<OpcoesWidget> createState() => _OpcoesWidgetState();
}

class _OpcoesWidgetState extends State<OpcoesWidget> {
  late OpcoesModel _model;

  String? planName;
  DateTime? expiresAt;
  bool habilitarPlanos = false;
  bool isLoadingPlan = true;
  bool isFreePlan = false;
  int _unreadCount = 0;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => OpcoesModel());
    _loadPlanInfo();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await NotificationService().getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadCount = count;
        });
      }
    } catch (e) {
      Logger.error('Erro ao carregar contagem de notificações', e);
    }
  }

  Future<void> _loadPlanInfo() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      final client = supabaseService.client;
      final currentUser = supabaseService.currentUser;

      if (currentUser == null) {
        setState(() {
          isLoadingPlan = false;
        });
        return;
      }

      // Buscar plano do usuário
      final planResponse = await client
          .from('user_plans')
          .select('''
            expires_at,
            plans:plan_id (
              name
            )
          ''')
          .eq('user_id', currentUser.id)
          .eq('is_active', true)
          .order('started_at', ascending: false)
          .limit(1)
          .maybeSingle();

      // Buscar configuração habilitar_planos
      final configResponse = await client
          .from('system_configuration')
          .select('habilitar_planos')
          .limit(1)
          .maybeSingle();

      String? name;
      DateTime? expiration;
      bool planIsFree = false;

      if (planResponse != null) {
        final planData = planResponse['plans'];
        if (planData is Map<String, dynamic>) {
          name = planData['name'] as String?;
          planIsFree = name?.toLowerCase() == 'free';
        } else if (planData is List && planData.isNotEmpty) {
          name = (planData[0] as Map<String, dynamic>)['name'] as String?;
          planIsFree = name?.toLowerCase() == 'free';
        }

        final expiresAtStr = planResponse['expires_at'] as String?;
        if (expiresAtStr != null && expiresAtStr.isNotEmpty) {
          expiration = DateTime.parse(expiresAtStr);
        }
      }

      bool enablePlans = false;
      if (configResponse != null) {
        enablePlans = configResponse['habilitar_planos'] as bool? ?? false;
      }

      setState(() {
        planName = name;
        expiresAt = expiration;
        habilitarPlanos = enablePlans;
        isFreePlan = planIsFree;
        isLoadingPlan = false;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar informações do plano', e, stackTrace);
      setState(() {
        isLoadingPlan = false;
      });
    }
  }

  String _formatExpirationDate(DateTime? date) {
    if (date == null) return 'N/A';
    
    // Formato: "dd mmm yy" (ex: "24 Nov 25")
    final months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 
                    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
    
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year.toString().substring(2);
    
    return '$day $month $year';
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20.0, 46.0, 20.0, 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 24.0),
              child: Text(
                'Opções',
                style: FlutterFlowTheme.of(context).headlineMedium.override(
                      font: GoogleFonts.poppins(
                        fontWeight: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontWeight,
                        fontStyle: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontStyle,
                      ),
                      letterSpacing: 0.0,
                      fontWeight: FlutterFlowTheme.of(context)
                          .headlineMedium
                          .fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                    ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop(); // Fechar drawer
                  context.push('/perfil');
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0x11868686),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(12.0, 8.0, 12.0, 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Icon(
                          Icons.person,
                          color: FlutterFlowTheme.of(context).primary,
                          size: 24.0,
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                4.0, 0.0, 0.0, 0.0),
                            child: Text(
                              'Perfil',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_right_sharp,
                          color: FlutterFlowTheme.of(context).primary,
                          size: 24.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop(); // Fechar drawer
                  context.push('/notifications');
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0x11868686),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(12.0, 8.0, 12.0, 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Stack(
                          children: [
                            Icon(
                              Icons.notifications_outlined,
                              color: FlutterFlowTheme.of(context).primary,
                              size: 24.0,
                            ),
                            if (_unreadCount > 0)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 12,
                                    minHeight: 12,
                                  ),
                                  child: Text(
                                    '$_unreadCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                4.0, 0.0, 0.0, 0.0),
                            child: Text(
                              'Notificações',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_right_sharp,
                          color: FlutterFlowTheme.of(context).primary,
                          size: 24.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
              child: InkWell(
                onTap: () {
                  context.push('/conquistas');
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0x11868686),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(12.0, 8.0, 12.0, 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Icon(
                          Icons.emoji_events,
                          color: FlutterFlowTheme.of(context).primary,
                          size: 24.0,
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                4.0, 0.0, 0.0, 0.0),
                            child: Text(
                              'Conquistas',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_right_sharp,
                          color: FlutterFlowTheme.of(context).primary,
                          size: 24.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop(); // Fechar drawer
                  context.push('/inspirar');
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0x11868686),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(12.0, 8.0, 12.0, 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: FlutterFlowTheme.of(context).primary,
                          size: 24.0,
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                4.0, 0.0, 0.0, 0.0),
                            child: Text(
                              'Para se Inspirar',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_right_sharp,
                          color: FlutterFlowTheme.of(context).primary,
                          size: 24.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
              child: InkWell(
                onTap: () {
                  final currentBrightness = Theme.of(context).brightness;
                  final newThemeMode = currentBrightness == Brightness.dark
                      ? ThemeMode.light
                      : ThemeMode.dark;
                  MyApp.of(context).setThemeMode(newThemeMode);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0x11868686),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(12.0, 8.0, 12.0, 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Icon(
                          Theme.of(context).brightness == Brightness.dark
                              ? Icons.light_mode
                              : Icons.mode_night,
                          color: FlutterFlowTheme.of(context).primary,
                          size: 24.0,
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                4.0, 0.0, 0.0, 0.0),
                            child: Text(
                              Theme.of(context).brightness == Brightness.dark
                                  ? 'Light mode'
                                  : 'Dark mode',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_right_sharp,
                          color: FlutterFlowTheme.of(context).primary,
                          size: 24.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop(); // Fechar drawer
                  context.push('/tutorial-suporte');
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0x11868686),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(12.0, 8.0, 12.0, 8.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Icon(
                          Icons.question_mark_sharp,
                          color: FlutterFlowTheme.of(context).primary,
                          size: 24.0,
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                4.0, 0.0, 0.0, 0.0),
                            child: Text(
                              'Tutorial e suporte',
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                            ),
                          ),
                        ),
                        Icon(
                          Icons.arrow_right_sharp,
                          color: FlutterFlowTheme.of(context).primary,
                          size: 24.0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isLoadingPlan)
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(0x11868686),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: Color(0x4E868686),
                            width: 1.0,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              12.0, 8.0, 12.0, 8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: FlutterFlowTheme.of(context).primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else if (planName != null)
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 8.0),
                      child: InkWell(
                        onTap: habilitarPlanos
                            ? () {
                                Navigator.of(context).pop(); // Fechar drawer
                                context.push('/plans');
                              }
                            : null,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Color(0x11868686),
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: Color(0x4E868686),
                              width: 1.0,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                12.0, 8.0, 12.0, 8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Icon(
                                  Icons.monetization_on_rounded,
                                  color: FlutterFlowTheme.of(context).primaryText,
                                  size: 32.0,
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        4.0, 0.0, 0.0, 0.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsetsDirectional.fromSTEB(
                                              4.0, 0.0, 0.0, 0.0),
                                          child: Text(
                                            'Plano $planName',
                                            style: FlutterFlowTheme.of(context)
                                                .bodySmall
                                                .override(
                                                  font: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.bold,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(context)
                                                            .bodySmall
                                                            .fontStyle,
                                                  ),
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.bold,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(context)
                                                          .bodySmall
                                                          .fontStyle,
                                                ),
                                          ),
                                        ),
                                        Padding(
                                          padding: EdgeInsetsDirectional.fromSTEB(
                                              4.0, 0.0, 0.0, 0.0),
                                          child: Text(
                                            isFreePlan
                                                ? 'Clique para escolher um plano'
                                                : 'Vencimento dia ${_formatExpirationDate(expiresAt)}',
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
                                                  fontSize: 10.0,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(context)
                                                          .bodySmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(context)
                                                          .bodySmall
                                                          .fontStyle,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_right_sharp,
                                  color: FlutterFlowTheme.of(context).primaryText,
                                  size: 24.0,
                                ),
                              ],
                            ),
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
