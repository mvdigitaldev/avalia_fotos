import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/supabase_service.dart';
import '../../services/storage_service.dart';
import '../../services/ai_evaluation_service.dart';
import '../../models/photo_model.dart';
import 'avalia_model.dart';
export 'avalia_model.dart';

class AvaliaWidget extends StatefulWidget {
  const AvaliaWidget({super.key});

  static String routeName = 'avalia';
  static String routePath = '/avalia';

  @override
  State<AvaliaWidget> createState() => _AvaliaWidgetState();
}

class _AvaliaWidgetState extends State<AvaliaWidget> {
  late AvaliaModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late StorageService _storageService;
  late AIEvaluationService _aiService;
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AvaliaModel());

    _model.switchValue = true;
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _storageService = StorageService(supabaseService);
      _aiService = AIEvaluationService(supabaseService);
      setState(() {
        _servicesInitialized = true;
      });
    } catch (e) {
      print('Erro ao inicializar serviços: $e');
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _storageService.pickImage();
      if (image != null) {
        safeSetState(() {
          _model.selectedImage = File(image.path);
          _model.evaluatedPhoto = null;
          _model.errorMessage = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao selecionar imagem: $e'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    }
  }

  Future<void> _evaluatePhoto() async {
    if (_model.selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecione uma imagem primeiro')),
      );
      return;
    }

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

      // Upload da imagem
      final imageUrl = await _storageService.uploadPhoto(
        imageFile: _model.selectedImage!,
        userId: userId,
      );

      // Avaliar foto
      final photo = await _aiService.evaluatePhoto(
        imageFile: _model.selectedImage!,
        imageUrl: imageUrl,
        isShared: _model.switchValue ?? false,
      );

      safeSetState(() {
        _model.evaluatedPhoto = photo;
        _model.isLoading = false;
      });
    } catch (e) {
      safeSetState(() {
        _model.isLoading = false;
        _model.errorMessage = e.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao avaliar foto: $e'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
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
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          20.0, 20.0, 20.0, 20.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Icon(
                            Icons.smart_toy_outlined,
                            color: FlutterFlowTheme.of(context).primaryText,
                            size: 24.0,
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  8.0, 0.0, 0.0, 0.0),
                              child: Text(
                                'Avalia',
                                style: FlutterFlowTheme.of(context)
                                    .titleLarge
                                    .override(
                                      font: GoogleFonts.poppins(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleLarge
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleLarge
                                          .fontStyle,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      height: 1.0,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            FlutterFlowTheme.of(context).primary,
                            Color(0x00FF4C00)
                          ],
                          stops: [0.0, 1.0],
                          begin: AlignmentDirectional(1.0, 0.0),
                          end: AlignmentDirectional(-1.0, 0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      // Formulário de upload (mostrar apenas quando não está carregando e não há resultado)
                      if (!_model.isLoading && _model.evaluatedPhoto == null)
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                20.0, 24.0, 20.0, 24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Avaliação da sua foto',
                                  style: FlutterFlowTheme.of(context)
                                      .titleLarge
                                      .override(
                                        font: GoogleFonts.poppins(
                                          fontWeight: FlutterFlowTheme.of(context)
                                              .titleLarge
                                              .fontWeight,
                                          fontStyle: FlutterFlowTheme.of(context)
                                              .titleLarge
                                              .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleLarge
                                            .fontStyle,
                                      ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 2.0, 0.0, 12.0),
                                  child: Text(
                                    'Faça o upload para avaliar sua foto!',
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.poppins(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .secondary,
                                        fontSize: 12.0,
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
                              GestureDetector(
                                onTap: _model.selectedImage == null && !_model.isLoading
                                    ? () => _pickImage()
                                    : null,
                                child: Stack(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: Color(0x0E868686),
                                      borderRadius: BorderRadius.circular(14.0),
                                      border: Border.all(
                                        color: Color(0x26868686),
                                      ),
                                    ),
                                      child: _model.selectedImage != null
                                          ? ClipRRect(
                                              borderRadius: BorderRadius.circular(14.0),
                                              child: Image.file(
                                                _model.selectedImage!,
                                                fit: BoxFit.cover,
                                                height: 300.0,
                                              ),
                                            )
                                          : Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 32.0, 0.0, 46.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        children: [
                                          Icon(
                                            Icons.image_outlined,
                                            color: Color(0x4F868686),
                                            size: 200.0,
                                          ),
                                          Text(
                                            'Clique aqui para fazer\no upload da imagem',
                                            textAlign: TextAlign.center,
                                            style: FlutterFlowTheme.of(context)
                                                .labelLarge
                                                .override(
                                                  font: GoogleFonts.poppins(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelLarge
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .labelLarge
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondary,
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelLarge
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .labelLarge
                                                          .fontStyle,
                                                ),
                                          ),
                                        ],
                                      ),
                                            ),
                                    ),
                                    if (_model.selectedImage != null)
                                      Positioned(
                                        top: 8.0,
                                        right: 8.0,
                                        child: IconButton(
                                          icon: Icon(Icons.close, color: Colors.white),
                                          onPressed: () {
                                            safeSetState(() {
                                              _model.selectedImage = null;
                                              _model.evaluatedPhoto = null;
                                            });
                                          },
                                    ),
                                  ),
                                ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 24.0, 0.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Switch.adaptive(
                                      value: _model.switchValue!,
                                      onChanged: (newValue) async {
                                        safeSetState(() =>
                                            _model.switchValue = newValue!);
                                      },
                                      activeColor:
                                          FlutterFlowTheme.of(context).primary,
                                      activeTrackColor:
                                          FlutterFlowTheme.of(context).primary,
                                      inactiveTrackColor:
                                          FlutterFlowTheme.of(context)
                                              .secondary,
                                      inactiveThumbColor:
                                          FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 0.0, 0.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Compartilhar foto',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font:
                                                            GoogleFonts.poppins(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyMedium
                                                                .fontStyle,
                                                      ),
                                            ),
                                            Text(
                                              'Ao deixar essa opção ativada, sua foto irá aparecer no ranking de fotos e no feed',
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .bodyMedium
                                                  .override(
                                                    font: GoogleFonts.poppins(
                                                      fontWeight:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontWeight,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .fontStyle,
                                                    ),
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .secondary,
                                                    fontSize: 10.0,
                                                    letterSpacing: 0.0,
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontStyle,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 24.0, 0.0, 0.0),
                                child: FFButtonWidget(
                                  onPressed: (_model.selectedImage != null && 
                                             !_model.isLoading && 
                                             _servicesInitialized)
                                      ? () => _evaluatePhoto()
                                      : null,
                                  text: _model.isLoading 
                                      ? 'Avaliando...' 
                                      : 'Avaliar Foto',
                                  options: FFButtonOptions(
                                    width: double.infinity,
                                    height: 40.0,
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        16.0, 0.0, 16.0, 0.0),
                                    iconPadding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 0.0),
                                    color: FlutterFlowTheme.of(context).primary,
                                    textStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .override(
                                          font: GoogleFonts.poppins(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontStyle,
                                          ),
                                          color: Colors.white,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontStyle,
                                        ),
                                    elevation: 0.0,
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 12.0, 0.0, 12.0),
                                    child: Text(
                                      'Tamanho máximo permitido de 10mb\nFormatos permitidos: JPG, PNG e WEBP',
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.poppins(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .secondary,
                                            fontSize: 10.0,
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              ],
                            ),
                          ),
                        ),
                      // Animação durante avaliação (mostrar apenas quando está carregando)
                      if (_model.isLoading)
                        Container(
                          width: double.infinity,
                          height: MediaQuery.sizeOf(context).height * 0.7,
                          decoration: BoxDecoration(),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                20.0, 40.0, 20.0, 20.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Lottie.asset(
                                  'assets/jsons/robot_working_on_machine_analyzing.json',
                                  width: 299.6,
                                  height: 297.73,
                                  fit: BoxFit.contain,
                                  animate: true,
                                  repeat: true,
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 24.0, 0.0, 0.0),
                                  child: Text(
                                    'Analisando sua foto',
                                    style: FlutterFlowTheme.of(context)
                                        .titleLarge
                                        .override(
                                          font: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                          ),
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 8.0, 0.0, 0.0),
                                  child: Text(
                                    'Aguarde alguns instantes',
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.poppins(),
                                          color: FlutterFlowTheme.of(context)
                                              .secondary,
                                          fontSize: 14.0,
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Resultado da avaliação (mostrar apenas quando não está carregando e há resultado)
                      if (_model.evaluatedPhoto != null && !_model.isLoading)
                        Container(
                          width: double.infinity,
                          margin: EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 20.0),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).secondaryBackground,
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).primary.withOpacity(0.2),
                              width: 1.0,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(24.0, 24.0, 24.0, 24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Imagem avaliada
                                if (_model.selectedImage != null)
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 24.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12.0),
                                      child: Image.file(
                                        _model.selectedImage!,
                                        width: double.infinity,
                                        height: 300.0,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                // Nota em destaque
                                Container(
                                  width: 120.0,
                                  height: 120.0,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context).primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${_model.evaluatedPhoto!.score.toStringAsFixed(2)}',
                                          style: FlutterFlowTheme.of(context)
                                              .displayMedium
                                              .override(
                                                font: GoogleFonts.poppins(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                color: Colors.white,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                        Text(
                                          '/ 10',
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                font: GoogleFonts.poppins(),
                                                color: Colors.white.withOpacity(0.8),
                                                fontSize: 14.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Recado
                                if (_model.evaluatedPhoto!.recado != null)
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                                    child: Container(
                                      padding: EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 16.0, 8.0),
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context).primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20.0),
                                      ),
                                      child: Text(
                                        _model.evaluatedPhoto!.recado!,
                                        style: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .override(
                                              font: GoogleFonts.poppins(
                                                fontWeight: FontWeight.w600,
                                              ),
                                              color: FlutterFlowTheme.of(context).primary,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                  ),
                                // Observação
                                if (_model.evaluatedPhoto!.observacao != null && _model.evaluatedPhoto!.observacao!.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 0.0),
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context).primaryBackground,
                                        borderRadius: BorderRadius.circular(12.0),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Observação:',
                                            style: FlutterFlowTheme.of(context)
                                                .titleSmall
                                                .override(
                                                  font: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  letterSpacing: 0.0,
                                                ),
                                          ),
                                          Padding(
                                            padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 0.0),
                                            child: Text(
                                              _model.evaluatedPhoto!.observacao!,
                                              style: FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .override(
                                                    font: GoogleFonts.poppins(),
                                                    letterSpacing: 0.0,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (_model.evaluatedPhoto!.positivePoints.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 20.0, 0.0, 0.0),
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context).success.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12.0),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Pontos Positivos:',
                                            style: FlutterFlowTheme.of(context)
                                                .titleSmall
                                                .override(
                                                  font: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  color: FlutterFlowTheme.of(context).success,
                                                  letterSpacing: 0.0,
                                                ),
                                          ),
                                          ..._model.evaluatedPhoto!.positivePoints
                                              .map((point) => Padding(
                                                    padding: EdgeInsetsDirectional
                                                        .fromSTEB(0.0, 8.0, 0.0, 0.0),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Icon(
                                                          Icons.check_circle,
                                                          color: FlutterFlowTheme.of(
                                                                  context)
                                                              .success,
                                                          size: 20.0,
                                                        ),
                                                        Expanded(
                                                          child: Padding(
                                                            padding: EdgeInsetsDirectional
                                                                .fromSTEB(8.0, 0.0, 0.0, 0.0),
                                                            child: Text(
                                                              point,
                                                              style: FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .override(
                                                                    font: GoogleFonts
                                                                        .poppins(),
                                                                    letterSpacing: 0.0,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )),
                                        ],
                                      ),
                                    ),
                                  ),
                                if (_model.evaluatedPhoto!.improvementPoints.isNotEmpty)
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 16.0, 0.0, 0.0),
                                    child: Container(
                                      width: double.infinity,
                                      padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context).warning.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12.0),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Pontos de Melhoria:',
                                            style: FlutterFlowTheme.of(context)
                                                .titleSmall
                                                .override(
                                                  font: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  color: FlutterFlowTheme.of(context).warning,
                                                  letterSpacing: 0.0,
                                                ),
                                          ),
                                          ..._model.evaluatedPhoto!.improvementPoints
                                              .map((point) => Padding(
                                                    padding: EdgeInsetsDirectional
                                                        .fromSTEB(0.0, 8.0, 0.0, 0.0),
                                                    child: Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment.start,
                                                      children: [
                                                        Icon(
                                                          Icons.info_outline,
                                                          color: FlutterFlowTheme.of(
                                                                  context)
                                                              .warning,
                                                          size: 20.0,
                                                        ),
                                                        Expanded(
                                                          child: Padding(
                                                            padding: EdgeInsetsDirectional
                                                                .fromSTEB(8.0, 0.0, 0.0, 0.0),
                                                            child: Text(
                                                              point,
                                                              style: FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .override(
                                                                    font: GoogleFonts
                                                                        .poppins(),
                                                                    letterSpacing: 0.0,
                                                                  ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )),
                                        ],
                                      ),
                                    ),
                                  ),
                                // Botão para analisar outra foto
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 24.0, 0.0, 0.0),
                                  child: FFButtonWidget(
                                    onPressed: () {
                                      safeSetState(() {
                                        _model.selectedImage = null;
                                        _model.evaluatedPhoto = null;
                                        _model.errorMessage = null;
                                      });
                                    },
                                    text: 'Analisar Outra Foto',
                                    options: FFButtonOptions(
                                      width: double.infinity,
                                      height: 50.0,
                                      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                      iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                                      color: FlutterFlowTheme.of(context).primary,
                                      textStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .override(
                                            font: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            color: Colors.white,
                                            letterSpacing: 0.0,
                                          ),
                                      elevation: 0,
                                      borderRadius: BorderRadius.circular(12.0),
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
