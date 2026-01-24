// lib/pages/checkout_webview/checkout_webview_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/logger.dart';
import 'checkout_webview_model.dart';
export 'checkout_webview_model.dart';

class CheckoutWebViewWidget extends StatefulWidget {
  const CheckoutWebViewWidget({
    super.key,
    required this.url,
  });

  final String url;

  static String routeName = 'checkout_webview';
  static String routePath = '/checkout-webview';

  @override
  State<CheckoutWebViewWidget> createState() => _CheckoutWebViewWidgetState();
}

class _CheckoutWebViewWidgetState extends State<CheckoutWebViewWidget> {
  late CheckoutWebViewModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late WebViewController _webViewController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CheckoutWebViewModel());
    _initializeWebView();
  }

  void _initializeWebView() {
    try {
      final uri = Uri.parse(widget.url);
      
      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            },
            onPageFinished: (String url) {
              setState(() {
                _isLoading = false;
              });
            },
            onWebResourceError: (WebResourceError error) {
              Logger.error('Erro ao carregar página no WebView', error.description, StackTrace.current);
              setState(() {
                _isLoading = false;
                _errorMessage = 'Erro ao carregar página: ${error.description}';
              });
            },
            onHttpError: (HttpResponseError error) {
              Logger.error('Erro HTTP no WebView', 'Status: ${error.response?.statusCode}', StackTrace.current);
              setState(() {
                _isLoading = false;
                _errorMessage = 'Erro ao carregar página (${error.response?.statusCode})';
              });
            },
          ),
        )
        ..loadRequest(uri);

      Logger.info('WebView inicializado com URL: ${widget.url}');
    } catch (e, stackTrace) {
      Logger.error('Erro ao inicializar WebView', e, stackTrace);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao inicializar checkout: $e';
      });
    }
  }

  Future<void> _openInExternalBrowser() async {
    try {
      final uri = Uri.parse(widget.url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Não foi possível abrir no navegador'),
              backgroundColor: FlutterFlowTheme.of(context).error,
            ),
          );
        }
      }
    } catch (e) {
      Logger.error('Erro ao abrir no navegador externo', e, StackTrace.current);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir no navegador: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _reload() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _webViewController.reload();
    } catch (e) {
      Logger.error('Erro ao recarregar página', e, StackTrace.current);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erro ao recarregar página: $e';
      });
    }
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
            'Checkout',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                  letterSpacing: 0.0,
                ),
          ),
          centerTitle: false,
          elevation: 0.0,
          actions: [
            if (_errorMessage != null)
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: FlutterFlowTheme.of(context).primaryText,
                ),
                onPressed: _reload,
                tooltip: 'Recarregar',
              ),
          ],
        ),
        body: SafeArea(
          top: true,
          child: _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(20, 20, 20, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: FlutterFlowTheme.of(context).error,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Erro ao carregar checkout',
                          style: FlutterFlowTheme.of(context).titleMedium.override(
                                font: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                                letterSpacing: 0.0,
                              ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(0, 8, 0, 0),
                          child: Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.poppins(),
                                  color: FlutterFlowTheme.of(context).error,
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(0, 24, 0, 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              FFButtonWidget(
                                onPressed: _reload,
                                text: 'Tentar Novamente',
                                options: FFButtonOptions(
                                  height: 40,
                                  padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                                  iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                                  color: FlutterFlowTheme.of(context).primary,
                                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                        font: GoogleFonts.poppins(),
                                        color: Colors.white,
                                        letterSpacing: 0.0,
                                      ),
                                  elevation: 0,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              SizedBox(width: 12),
                              FFButtonWidget(
                                onPressed: _openInExternalBrowser,
                                text: 'Abrir no Navegador',
                                options: FFButtonOptions(
                                  height: 40,
                                  padding: EdgeInsetsDirectional.fromSTEB(24, 0, 24, 0),
                                  iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                                  color: FlutterFlowTheme.of(context).secondaryBackground,
                                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                        font: GoogleFonts.poppins(),
                                        color: FlutterFlowTheme.of(context).primaryText,
                                        letterSpacing: 0.0,
                                      ),
                                  elevation: 0,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    WebViewWidget(controller: _webViewController),
                    if (_isLoading)
                      Container(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
