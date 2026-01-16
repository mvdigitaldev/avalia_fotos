// lib/pages/admin/send_push_notification_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../services/supabase_service.dart';
import '../../services/report_service.dart';
import '../../utils/logger.dart';
import 'send_push_notification_model.dart';
export 'send_push_notification_model.dart';

class SendPushNotificationWidget extends StatefulWidget {
  const SendPushNotificationWidget({super.key});

  static String routeName = 'sendPushNotification';
  static String routePath = '/admin/send-push-notification';

  @override
  State<SendPushNotificationWidget> createState() => _SendPushNotificationWidgetState();
}

class _SendPushNotificationWidgetState extends State<SendPushNotificationWidget> {
  SendPushNotificationModel? _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  ReportService? _reportService;
  bool _servicesInitialized = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    // Inicializações que não dependem de context
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Agora context está disponível
    if (_model == null) {
      _model = createModel(context, () => SendPushNotificationModel());

      _model!.titleFocusNode ??= FocusNode();
      _model!.titleController ??= TextEditingController();
      _model!.contentFocusNode ??= FocusNode();
      _model!.contentController ??= TextEditingController();

      _model!.titleControllerValidator ??= (value) {
        if (value == null || value.isEmpty) {
          return 'O título é obrigatório';
        }
        return null;
      };

      _model!.contentControllerValidator ??= (value) {
        if (value == null || value.isEmpty) {
          return 'O conteúdo é obrigatório';
        }
        return null;
      };

      _initializeServices();
    }
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _reportService = ReportService(supabaseService);

      // Verificar se é admin
      final isAdmin = await _reportService!.isCurrentUserAdmin();
      if (!isAdmin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Acesso negado. Apenas administradores podem acessar esta página.'),
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

  Future<void> _sendNotification() async {
    if (!_servicesInitialized || !_isAdmin || _model == null) return;

    // Validar campos
    if (_model!.titleControllerValidator != null) {
      final titleValidation = _model!.titleControllerValidator!(_model!.titleController!.text);
      if (titleValidation != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(titleValidation),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
        return;
      }
    }

    if (_model!.contentControllerValidator != null) {
      final contentValidation = _model!.contentControllerValidator!(_model!.contentController!.text);
      if (contentValidation != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(contentValidation),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
        return;
      }
    }

    setState(() {
      _model!.isLoading = true;
      _model!.errorMessage = null;
    });

    try {
      final supabaseService = await SupabaseService.getInstance();
      final client = supabaseService.client;

      // Chamar Edge Function para enviar notificação
      await client.functions.invoke(
        'send-push-notification',
        body: {
          'title': _model!.titleController!.text.trim(),
          'body': _model!.contentController!.text.trim(),
          'broadcast': true,
          'data': {
            'type': 'admin_broadcast',
          },
        },
      );

      Logger.info('Notificação push enviada com sucesso');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notificação enviada com sucesso para todos os usuários!'),
            backgroundColor: FlutterFlowTheme.of(context).success,
            duration: const Duration(seconds: 3),
          ),
        );

        // Limpar campos após sucesso
        _model!.titleController?.clear();
        _model!.contentController?.clear();
      }
    } catch (e, stackTrace) {
      Logger.error('Erro ao enviar notificação push', e, stackTrace);
      setState(() {
        _model!.errorMessage = 'Erro ao enviar notificação: ${e.toString()}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar notificação: ${e.toString()}'),
            backgroundColor: FlutterFlowTheme.of(context).error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _model!.isLoading = false;
        });
      }
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
          backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
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
            'Enviar Notificação',
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
          child: _servicesInitialized && _isAdmin
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Campo Título
                      Text(
                        'Título da Notificação',
                        style: FlutterFlowTheme.of(context).titleMedium.override(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.0,
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _model!.titleController,
                        focusNode: _model!.titleFocusNode,
                        validator: _model!.titleControllerValidator,
                        decoration: InputDecoration(
                          hintText: 'Digite o título da notificação',
                          hintStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                                fontFamily: 'Poppins',
                                color: FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                              ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).alternate,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).error,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).error,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                          contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
                        ),
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Poppins',
                              letterSpacing: 0.0,
                            ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),

                      // Campo Conteúdo
                      Text(
                        'Conteúdo da Notificação',
                        style: FlutterFlowTheme.of(context).titleMedium.override(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.0,
                            ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _model!.contentController,
                        focusNode: _model!.contentFocusNode,
                        validator: _model!.contentControllerValidator,
                        decoration: InputDecoration(
                          hintText: 'Digite o conteúdo da notificação',
                          hintStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                                fontFamily: 'Poppins',
                                color: FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                              ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).alternate,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).primary,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).error,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: FlutterFlowTheme.of(context).error,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                          contentPadding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
                        ),
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Poppins',
                              letterSpacing: 0.0,
                            ),
                        maxLines: 6,
                      ),
                      const SizedBox(height: 32),

                      // Mensagem de erro (se houver)
                      if (_model!.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context).error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: FlutterFlowTheme.of(context).error,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _model!.errorMessage!,
                              style: FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Poppins',
                                    color: FlutterFlowTheme.of(context).error,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                        ),

                      // Botão Enviar
                      ElevatedButton(
                        onPressed: (_model!.isLoading || _model == null) ? null : _sendNotification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FlutterFlowTheme.of(context).primary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: _model!.isLoading
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    FlutterFlowTheme.of(context).primaryBackground,
                                  ),
                                ),
                              )
                            : Text(
                                'Enviar Notificação',
                                style: FlutterFlowTheme.of(context).titleMedium.override(
                                      fontFamily: 'Poppins',
                                      color: FlutterFlowTheme.of(context).primaryBackground,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                      ),
                    ],
                  ),
                )
              : const Center(
                  child: CircularProgressIndicator(),
                ),
        ),
      ),
    );
  }
}

