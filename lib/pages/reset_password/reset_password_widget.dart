// lib/pages/reset_password/reset_password_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import '../../services/auth_service.dart';
import '../../utils/logger.dart';
import 'reset_password_model.dart';
export 'reset_password_model.dart';

class ResetPasswordWidget extends StatefulWidget {
  const ResetPasswordWidget({super.key});

  static String routeName = 'resetPassword';
  static String routePath = '/reset-password';

  @override
  State<ResetPasswordWidget> createState() => _ResetPasswordWidgetState();
}

class _ResetPasswordWidgetState extends State<ResetPasswordWidget> {
  late ResetPasswordModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late AuthService _authService;
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ResetPasswordModel());

    _model.passwordController ??= TextEditingController();
    _model.passwordFocusNode ??= FocusNode();

    _model.confirmPasswordController ??= TextEditingController();
    _model.confirmPasswordFocusNode ??= FocusNode();

    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      setState(() {
        _authService = AuthService(supabaseService);
        _servicesInitialized = true;
      });
      _checkPasswordRecoverySession();
    } catch (e, stackTrace) {
      Logger.error('Erro ao inicializar serviços', e, stackTrace);
      safeSetState(() {
        _model.errorMessage = 'Erro ao inicializar serviços: $e';
        _model.isLoading = false;
      });
    }
  }

  Future<void> _checkPasswordRecoverySession() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      final session = supabaseService.client.auth.currentSession;
      
      // Verificar se há uma sessão de recuperação de senha ativa
      // O Supabase cria uma sessão temporária quando o usuário clica no link de recuperação
      if (session == null) {
        safeSetState(() {
          _model.errorMessage = 'Link de recuperação inválido ou expirado. Por favor, solicite um novo link.';
          _model.isLoading = false;
        });
      } else {
        safeSetState(() {
          _model.isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Erro ao verificar sessão de recuperação', e);
      safeSetState(() {
        _model.errorMessage = 'Erro ao verificar sessão de recuperação: $e';
        _model.isLoading = false;
      });
    }
  }

  Future<void> _resetPassword() async {
    if (!_servicesInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aguarde, inicializando serviços...'),
          backgroundColor: FlutterFlowTheme.of(context).warning,
        ),
      );
      return;
    }

    final password = _model.passwordController?.text.trim() ?? '';
    final confirmPassword = _model.confirmPasswordController?.text.trim() ?? '';

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor, digite a nova senha'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A senha deve ter pelo menos 6 caracteres'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('As senhas não coincidem'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    safeSetState(() {
      _model.isLoading = true;
      _model.errorMessage = null;
    });

    try {
      final supabaseService = await SupabaseService.getInstance();
      await supabaseService.client.auth.updateUser(
        UserAttributes(password: password),
      );

      Logger.info('Senha redefinida com sucesso');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Senha redefinida com sucesso! Redirecionando para login...'),
            backgroundColor: FlutterFlowTheme.of(context).success,
            duration: Duration(seconds: 2),
          ),
        );

        // Aguardar um pouco antes de redirecionar
        await Future.delayed(Duration(seconds: 2));

        // Fazer logout da sessão temporária de recuperação
        await _authService.signOut();

        if (mounted) {
          context.go('/login');
        }
      }
    } catch (e) {
      Logger.error('Erro ao redefinir senha', e);
      safeSetState(() {
        _model.isLoading = false;
        _model.errorMessage = 'Erro ao redefinir senha: ${e.toString()}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao redefinir senha: ${e.toString()}'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
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
              Icons.arrow_back_ios,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 24.0,
            ),
            onPressed: () => context.go('/login'),
          ),
          title: Text(
            'Redefinir Senha',
            style: FlutterFlowTheme.of(context).titleLarge.override(
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
          child: _model.isLoading && _model.errorMessage == null
              ? Center(
                  child: CircularProgressIndicator(
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                )
              : _model.errorMessage != null && !_servicesInitialized
                  ? Center(
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: FlutterFlowTheme.of(context).error,
                              size: 64,
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                              child: Text(
                                _model.errorMessage!,
                                textAlign: TextAlign.center,
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                      font: GoogleFonts.poppins(),
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(0.0, 24.0, 0.0, 0.0),
                              child: FFButtonWidget(
                                onPressed: () => context.go('/login'),
                                text: 'Voltar para Login',
                                options: FFButtonOptions(
                                  height: 40.0,
                                  padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                                  color: FlutterFlowTheme.of(context).primary,
                                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                        font: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        color: Colors.white,
                                        letterSpacing: 0.0,
                                      ),
                                  borderRadius: BorderRadius.circular(8.0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(20.0, 24.0, 20.0, 24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Digite sua nova senha',
                              style: FlutterFlowTheme.of(context).headlineSmall.override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    letterSpacing: 0.0,
                                  ),
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 0.0),
                              child: Text(
                                'Sua senha deve ter pelo menos 6 caracteres',
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                      font: GoogleFonts.poppins(),
                                      color: FlutterFlowTheme.of(context).secondary,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(0.0, 24.0, 0.0, 0.0),
                              child: TextFormField(
                                controller: _model.passwordController,
                                focusNode: _model.passwordFocusNode,
                                obscureText: !_model.passwordVisibility,
                                decoration: InputDecoration(
                                  labelText: 'Nova Senha',
                                  hintText: 'Digite sua nova senha',
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context).alternate,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context).primary,
                                      width: 2.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context).error,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context).error,
                                      width: 2.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  filled: true,
                                  fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                                  suffixIcon: InkWell(
                                    onTap: () => safeSetState(
                                      () => _model.passwordVisibility = !_model.passwordVisibility,
                                    ),
                                    focusNode: FocusNode(skipTraversal: true),
                                    child: Icon(
                                      _model.passwordVisibility
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: FlutterFlowTheme.of(context).secondary,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                      font: GoogleFonts.poppins(),
                                      letterSpacing: 0.0,
                                    ),
                                validator: _model.passwordControllerValidator?.asValidator(context),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                              child: TextFormField(
                                controller: _model.confirmPasswordController,
                                focusNode: _model.confirmPasswordFocusNode,
                                obscureText: !_model.confirmPasswordVisibility,
                                decoration: InputDecoration(
                                  labelText: 'Confirmar Nova Senha',
                                  hintText: 'Digite novamente a nova senha',
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context).alternate,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context).primary,
                                      width: 2.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context).error,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context).error,
                                      width: 2.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  filled: true,
                                  fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                                  suffixIcon: InkWell(
                                    onTap: () => safeSetState(
                                      () => _model.confirmPasswordVisibility = !_model.confirmPasswordVisibility,
                                    ),
                                    focusNode: FocusNode(skipTraversal: true),
                                    child: Icon(
                                      _model.confirmPasswordVisibility
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: FlutterFlowTheme.of(context).secondary,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                      font: GoogleFonts.poppins(),
                                      letterSpacing: 0.0,
                                    ),
                                validator: _model.confirmPasswordControllerValidator?.asValidator(context),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(0.0, 24.0, 0.0, 0.0),
                              child: FFButtonWidget(
                                onPressed: _model.isLoading ? null : _resetPassword,
                                text: _model.isLoading ? 'Redefinindo...' : 'Redefinir Senha',
                                options: FFButtonOptions(
                                  width: double.infinity,
                                  height: 50.0,
                                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                  color: FlutterFlowTheme.of(context).primary,
                                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                        font: GoogleFonts.poppins(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        color: Colors.white,
                                        letterSpacing: 0.0,
                                      ),
                                  elevation: 0.0,
                                  borderRadius: BorderRadius.circular(8.0),
                                  disabledColor: FlutterFlowTheme.of(context).alternate,
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
}
