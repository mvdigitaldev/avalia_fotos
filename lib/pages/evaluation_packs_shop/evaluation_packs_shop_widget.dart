// lib/pages/evaluation_packs_shop/evaluation_packs_shop_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../services/evaluation_pack_service.dart';
import '../../utils/logger.dart';
import '../../components/evaluation_pack_card.dart';
import '../../models/evaluation_pack_model.dart';
import 'evaluation_packs_shop_model.dart';
export 'evaluation_packs_shop_model.dart';

class EvaluationPacksShopWidget extends StatefulWidget {
  const EvaluationPacksShopWidget({super.key});

  static String routeName = 'evaluation_packs_shop';
  static String routePath = '/evaluation-packs-shop';

  @override
  State<EvaluationPacksShopWidget> createState() =>
      _EvaluationPacksShopWidgetState();
}

class _EvaluationPacksShopWidgetState extends State<EvaluationPacksShopWidget> {
  late EvaluationPacksShopModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late EvaluationPackService _evaluationPackService;
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EvaluationPacksShopModel());
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _evaluationPackService = EvaluationPackService(supabaseService);
      final userId = supabaseService.currentUser?.id;
      if (userId == null) {
        safeSetState(() {
          _model.isLoading = false;
          _model.errorMessage = 'Usuário não autenticado';
        });
        return;
      }

      setState(() {
        _servicesInitialized = true;
      });
      await _loadData();
    } catch (e, stackTrace) {
      Logger.error('Erro ao inicializar serviços', e, stackTrace);
      safeSetState(() {
        _model.isLoading = false;
        _model.errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadData() async {
    if (!_servicesInitialized) return;

    safeSetState(() {
      _model.isLoading = true;
      _model.errorMessage = null;
    });

    try {
      final supabaseService = await SupabaseService.getInstance();
      final userId = supabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('Usuário não autenticado');
      }

      final packs = await _evaluationPackService.getActivePacks();
      final extraCount = await _evaluationPackService.getUserExtraCount(userId);

      safeSetState(() {
        _model.packs = packs;
        _model.extraCount = extraCount;
        _model.isLoading = false;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar pacotes', e, stackTrace);
      safeSetState(() {
        _model.isLoading = false;
        _model.errorMessage = e.toString();
      });
    }
  }

  void _purchasePack(EvaluationPackModel pack) {
    final linkCheckout = pack.linkCheckout;
    if (linkCheckout == null || linkCheckout.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Link de checkout não disponível para este pacote.',
          ),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    context.push(
      '/checkout-webview?url=${Uri.encodeComponent(linkCheckout)}',
    );
  }

  @override
  void dispose() {
    _model.maybeDispose();
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
            'Avaliações Extras',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                  letterSpacing: 0.0,
                ),
          ),
          centerTitle: false,
          elevation: 0.0,
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
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Erro ao carregar pacotes',
                              style: FlutterFlowTheme.of(context).titleMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _model.errorMessage!,
                              style: FlutterFlowTheme.of(context).bodySmall,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FFButtonWidget(
                              onPressed: _loadData,
                              text: 'Tentar Novamente',
                              options: FFButtonOptions(
                                height: 40,
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                    24, 0, 24, 0),
                                color: FlutterFlowTheme.of(context).primary,
                                textStyle: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .override(
                                      font: GoogleFonts.poppins(),
                                      color: Colors.white,
                                    ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: FlutterFlowTheme.of(context).primary,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            20, 20, 20, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBalanceCard(),
                            const SizedBox(height: 24),
                            Text(
                              'Escolha um pacote',
                              style: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    letterSpacing: 0.0,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Compre avaliações extras para continuar avaliando suas fotos',
                              style: FlutterFlowTheme.of(context).bodySmall.override(
                                    font: GoogleFonts.poppins(),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                            const SizedBox(height: 20),
                            if (_model.packs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 32),
                                child: Center(
                                  child: Text(
                                    'Nenhum pacote disponível no momento.',
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.poppins(),
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                        ),
                                  ),
                                ),
                              )
                            else
                              ..._model.packs.map(
                                (pack) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: EvaluationPackCard(
                                    pack: pack,
                                    onTap: () => _purchasePack(pack),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    final hasExtras = _model.extraCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlutterFlowTheme.of(context).primary,
            FlutterFlowTheme.of(context).primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: FlutterFlowTheme.of(context).primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.photo_camera,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasExtras ? 'Suas avaliações extras' : 'Você não tem avaliações disponíveis',
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.poppins(
                          fontWeight: hasExtras ? FontWeight.normal : FontWeight.w600,
                        ),
                        color: Colors.white.withOpacity(0.9),
                      ),
                ),
                const SizedBox(height: 4),
                if (hasExtras)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${_model.extraCount}',
                        style: FlutterFlowTheme.of(context).headlineLarge.override(
                              font: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                              ),
                              color: Colors.white,
                              fontSize: 32,
                            ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'disponíveis',
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              font: GoogleFonts.poppins(),
                              color: Colors.white.withOpacity(0.8),
                            ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Sem avaliações — compre um pacote para continuar',
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          font: GoogleFonts.poppins(),
                          color: Colors.white.withOpacity(0.9),
                          letterSpacing: 0.0,
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
