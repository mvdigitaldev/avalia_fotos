// lib/pages/plans/plans_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/plan_service.dart';
import '../../services/payment_service.dart';
import '../../models/plan_model.dart';
import '../../models/user_plan_model.dart';
import '../../models/payment_history_model.dart';
import 'plans_model.dart';
export 'plans_model.dart';

class PlansWidget extends StatefulWidget {
  const PlansWidget({super.key});

  static String routeName = 'plans';
  static String routePath = '/plans';

  @override
  State<PlansWidget> createState() => _PlansWidgetState();
}

class _PlansWidgetState extends State<PlansWidget> with TickerProviderStateMixin {
  late PlansModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late PlanService _planService;
  late PaymentService _paymentService;
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PlansModel());
    _model.tabController = TabController(vsync: this, length: 2);
    _model.tabController?.addListener(() {
      if (_model.tabController != null && !_model.tabController!.indexIsChanging) {
        safeSetState(() {
          _model.selectedTabIndex = _model.tabController!.index;
        });
      }
    });
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _planService = PlanService(supabaseService);
      _paymentService = PaymentService(supabaseService);
      setState(() {
        _servicesInitialized = true;
      });
      await _loadPlans();
      await _loadPaymentHistory();
    } catch (e) {
      print('Erro ao inicializar serviços: $e');
      safeSetState(() {
        _model.isLoading = false;
        _model.errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadPaymentHistory() async {
    if (!_servicesInitialized) return;

    safeSetState(() {
      _model.isLoadingHistory = true;
    });

    try {
      final history = await _paymentService.getPaymentHistory();
      safeSetState(() {
        _model.paymentHistory = history;
        _model.isLoadingHistory = false;
      });
    } catch (e) {
      print('Erro ao carregar histórico de pagamentos: $e');
      safeSetState(() {
        _model.isLoadingHistory = false;
      });
    }
  }

  Future<void> _loadPlans() async {
    safeSetState(() {
      _model.isLoading = true;
      _model.errorMessage = null;
    });

    try {
      final userId = _planService.currentUserId;
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      final plans = await _planService.getAvailablePlans();
      final currentPlan = await _planService.getUserPlan(userId);

      // Filtrar plano Free da lista (usuários não podem migrar para Free)
      final paidPlans = plans.where((plan) => plan.name.toLowerCase() != 'free').toList();

      safeSetState(() {
        _model.availablePlans = paidPlans;
        _model.currentPlan = currentPlan;
        _model.isLoading = false;
      });
    } catch (e) {
      safeSetState(() {
        _model.isLoading = false;
        _model.errorMessage = e.toString();
      });
    }
  }

  Future<void> _openPlanLink(String? linkPlan) async {
    if (linkPlan == null || linkPlan.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Link do plano não disponível'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
      return;
    }

    try {
      final uri = Uri.parse(linkPlan);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Não foi possível abrir o link';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir link: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _upgradePlan(String planId) async {
    try {
      final userId = _planService.currentUserId;
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      await _planService.upgradePlan(userId, planId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plano atualizado com sucesso!'),
            backgroundColor: FlutterFlowTheme.of(context).success,
          ),
        );
      }

      await _loadPlans();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao fazer upgrade: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Widget _buildPlanCard(PlanModel plan) {
    final isCurrentPlan = _model.currentPlan?.plan.id == plan.id;
    
    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 16),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentPlan
              ? FlutterFlowTheme.of(context).primary
              : FlutterFlowTheme.of(context).alternate,
          width: isCurrentPlan ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan.name,
                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                        ),
                        letterSpacing: 0.0,
                      ),
                ),
                if (isCurrentPlan)
                  Container(
                    padding: EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Atual',
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            font: GoogleFonts.poppins(),
                            color: Colors.white,
                            fontSize: 10,
                            letterSpacing: 0.0,
                          ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0, 8, 0, 16),
              child: Text(
                plan.isFree
                    ? 'Grátis'
                    : 'R\$ ${plan.price!.toStringAsFixed(2)}/mês',
                style: FlutterFlowTheme.of(context).headlineMedium.override(
                      font: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                      ),
                      color: FlutterFlowTheme.of(context).primary,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFeatureRow(
                    plan.isUnlimitedEvaluations
                        ? 'Avaliações ilimitadas por mês'
                        : '${plan.monthlyEvaluationsLimit} avaliações por mês',
                  ),
                  _buildFeatureRow(
                    plan.isUnlimitedStorage
                        ? 'Armazenamento ilimitado'
                        : '${plan.storageLimit} fotos armazenadas',
                  ),
                ],
              ),
            ),
            if (!isCurrentPlan)
              FFButtonWidget(
                onPressed: () => _openPlanLink(plan.linkPlan),
                text: 'Escolher Plano',
                options: FFButtonOptions(
                  width: double.infinity,
                  height: 50,
                  padding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                  iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                  color: FlutterFlowTheme.of(context).primary,
                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                        color: Colors.white,
                        letterSpacing: 0.0,
                      ),
                  elevation: 0,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(String text) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0, 8, 0, 0),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: FlutterFlowTheme.of(context).success,
            size: 20,
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(8, 0, 0, 0),
            child: Text(
              text,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.poppins(),
                    letterSpacing: 0.0,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryTab() {
    if (_model.isLoadingHistory) {
      return Center(
        child: CircularProgressIndicator(
          color: FlutterFlowTheme.of(context).primary,
        ),
      );
    }

    if (_model.paymentHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: FlutterFlowTheme.of(context).secondary,
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0, 16, 0, 0),
              child: Text(
                'Nenhum pagamento encontrado',
                style: FlutterFlowTheme.of(context).titleMedium.override(
                      font: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                      ),
                      letterSpacing: 0.0,
                    ),
              ),
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
              child: Text(
                'Seu histórico de pagamentos aparecerá aqui',
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.poppins(),
                      color: FlutterFlowTheme.of(context).secondary,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPaymentHistory,
      color: FlutterFlowTheme.of(context).primary,
      child: ListView.builder(
        padding: EdgeInsetsDirectional.fromSTEB(20, 20, 20, 20),
        itemCount: _model.paymentHistory.length,
        itemBuilder: (context, index) {
          final payment = _model.paymentHistory[index];
          return _buildPaymentCard(payment);
        },
      ),
    );
  }

  Widget _buildPaymentCard(PaymentHistoryModel payment) {
    Color statusColor;
    IconData statusIcon;
    
    switch (payment.paymentStatus) {
      case 'paid':
        statusColor = FlutterFlowTheme.of(context).success;
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case 'refunded':
        statusColor = Colors.blue;
        statusIcon = Icons.refresh;
        break;
      case 'failed':
        statusColor = FlutterFlowTheme.of(context).error;
        statusIcon = Icons.error;
        break;
      case 'cancelled':
        statusColor = FlutterFlowTheme.of(context).secondary;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = FlutterFlowTheme.of(context).secondary;
        statusIcon = Icons.info;
    }

    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 16),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        payment.planName,
                        style: FlutterFlowTheme.of(context).titleMedium.override(
                              font: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                              letterSpacing: 0.0,
                            ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
                        child: Text(
                          payment.description ?? 'Pagamento do plano',
                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                font: GoogleFonts.poppins(),
                                color: FlutterFlowTheme.of(context).secondary,
                                letterSpacing: 0.0,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsetsDirectional.fromSTEB(8, 4, 8, 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        statusIcon,
                        color: statusColor,
                        size: 16,
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(4, 0, 0, 0),
                        child: Text(
                          payment.statusLabel,
                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                font: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                                color: statusColor,
                                fontSize: 11,
                                letterSpacing: 0.0,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0, 16, 0, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Valor',
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              font: GoogleFonts.poppins(),
                              color: FlutterFlowTheme.of(context).secondary,
                              letterSpacing: 0.0,
                            ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
                        child: Text(
                          'R\$ ${payment.amount.toStringAsFixed(2)}',
                          style: FlutterFlowTheme.of(context).titleLarge.override(
                                font: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                ),
                                color: FlutterFlowTheme.of(context).primary,
                                letterSpacing: 0.0,
                              ),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Método',
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              font: GoogleFonts.poppins(),
                              color: FlutterFlowTheme.of(context).secondary,
                              letterSpacing: 0.0,
                            ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
                        child: Text(
                          payment.methodLabel,
                          style: FlutterFlowTheme.of(context).bodyMedium.override(
                                font: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                                letterSpacing: 0.0,
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(
              height: 24,
              thickness: 1,
              color: FlutterFlowTheme.of(context).alternate,
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data do Pagamento',
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              font: GoogleFonts.poppins(),
                              color: FlutterFlowTheme.of(context).secondary,
                              fontSize: 11,
                              letterSpacing: 0.0,
                            ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
                        child: Text(
                          payment.paymentDate != null
                              ? DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(payment.paymentDate!)
                              : DateFormat('dd/MM/yyyy', 'pt_BR').format(payment.createdAt),
                          style: FlutterFlowTheme.of(context).bodySmall.override(
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vencimento',
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              font: GoogleFonts.poppins(),
                              color: FlutterFlowTheme.of(context).secondary,
                              fontSize: 11,
                              letterSpacing: 0.0,
                            ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
                        child: Text(
                          DateFormat('dd/MM/yyyy', 'pt_BR').format(payment.expiresAt),
                          style: FlutterFlowTheme.of(context).bodySmall.override(
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
              ],
            ),
            if (payment.transactionId != null)
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
                child: Row(
                  children: [
                    Icon(
                      Icons.receipt,
                      size: 16,
                      color: FlutterFlowTheme.of(context).secondary,
                    ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(8, 0, 0, 0),
                        child: Text(
                          'ID: ${payment.transactionId}',
                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                font: GoogleFonts.poppins(),
                                color: FlutterFlowTheme.of(context).secondary,
                                fontSize: 10,
                                letterSpacing: 0.0,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (payment.invoiceUrl != null && payment.invoiceUrl!.isNotEmpty)
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
                child: InkWell(
                  onTap: () async {
                    try {
                      final uri = Uri.parse(payment.invoiceUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Erro ao abrir recibo: $e'),
                            backgroundColor: FlutterFlowTheme.of(context).error,
                          ),
                        );
                      }
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.receipt_long,
                        size: 16,
                        color: FlutterFlowTheme.of(context).primary,
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(4, 0, 0, 0),
                        child: Text(
                          'Ver Recibo',
                          style: FlutterFlowTheme.of(context).bodySmall.override(
                                font: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                                color: FlutterFlowTheme.of(context).primary,
                                letterSpacing: 0.0,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
            'Planos',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  fontFamily: 'Poppins',
                  letterSpacing: 0.0,
                ),
          ),
          actions: [],
          centerTitle: false,
          elevation: 0.0,
          bottom: _model.tabController != null
              ? TabBar(
                  controller: _model.tabController!,
                  labelColor: FlutterFlowTheme.of(context).primary,
                  unselectedLabelColor: FlutterFlowTheme.of(context).secondary,
                  labelStyle: FlutterFlowTheme.of(context).titleSmall.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                        letterSpacing: 0.0,
                      ),
                  unselectedLabelStyle: FlutterFlowTheme.of(context).titleSmall.override(
                        font: GoogleFonts.poppins(),
                        letterSpacing: 0.0,
                      ),
                  indicatorColor: FlutterFlowTheme.of(context).primary,
                  tabs: [
                    Tab(text: 'Planos'),
                    Tab(text: 'Histórico'),
                  ],
                )
              : null,
        ),
        body: SafeArea(
          top: true,
          child: _model.isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                )
              : _model.errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Erro ao carregar planos',
                            style: FlutterFlowTheme.of(context).titleMedium.override(
                                  fontFamily: 'Poppins',
                                  letterSpacing: 0.0,
                                ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(20, 8, 20, 0),
                            child: Text(
                              _model.errorMessage!,
                              textAlign: TextAlign.center,
                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Poppins',
                                    color: FlutterFlowTheme.of(context).error,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(0, 16, 0, 0),
                            child: FFButtonWidget(
                              onPressed: _loadPlans,
                              text: 'Tentar Novamente',
                              options: FFButtonOptions(
                                height: 40,
                                padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                                iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                                color: FlutterFlowTheme.of(context).primary,
                                textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                      fontFamily: 'Poppins',
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
                  : _model.tabController != null
                      ? TabBarView(
                          controller: _model.tabController!,
                          children: [
                        // Aba de Planos
                        SingleChildScrollView(
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(20, 20, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Escolha o plano ideal para você',
                                  style: FlutterFlowTheme.of(context).titleLarge.override(
                                        font: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        letterSpacing: 0.0,
                                      ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(0, 8, 0, 24),
                                  child: Text(
                                    'Compare os planos e escolha o que melhor se adapta às suas necessidades',
                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                          font: GoogleFonts.poppins(),
                                          color: FlutterFlowTheme.of(context).secondary,
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                ),
                                ..._model.availablePlans.map((plan) => _buildPlanCard(plan)),
                              ],
                            ),
                          ),
                        ),
                        // Aba de Histórico
                        _buildPaymentHistoryTab(),
                          ],
                        )
                      : Center(
                          child: CircularProgressIndicator(
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                        ),
        ),
      ),
    );
  }
}

