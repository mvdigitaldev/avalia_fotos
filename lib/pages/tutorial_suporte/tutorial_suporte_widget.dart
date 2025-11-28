// lib/pages/tutorial_suporte/tutorial_suporte_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../services/supabase_service.dart';
import 'tutorial_suporte_model.dart';
export 'tutorial_suporte_model.dart';

class TutorialSuporteWidget extends StatefulWidget {
  const TutorialSuporteWidget({super.key});

  static String routeName = 'tutorial_suporte';
  static String routePath = '/tutorial-suporte';

  @override
  State<TutorialSuporteWidget> createState() => _TutorialSuporteWidgetState();
}

class _TutorialSuporteWidgetState extends State<TutorialSuporteWidget> {
  late TutorialSuporteModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  
  String? youtubeVideoUrl;
  String? whatsappUrl;
  String? comunidadeUrl;
  bool isLoading = true;
  String? errorMessage;
  bool hasActivePlan = false;

  // Extrair ID do vídeo do YouTube a partir da URL
  String? _extractYouTubeVideoId(String? url) {
    if (url == null || url.isEmpty) return null;
    
    try {
      final uri = Uri.parse(url);
      // Tentar pegar o parâmetro 'v' da URL
      final videoId = uri.queryParameters['v'] ?? 
                     uri.pathSegments.lastWhere(
                       (segment) => segment.isNotEmpty,
                       orElse: () => '',
                     );
      return videoId.isNotEmpty ? videoId : null;
    } catch (e) {
      print('Erro ao extrair ID do YouTube: $e');
      return null;
    }
  }

  Future<void> _openYouTubeVideo() async {
    if (youtubeVideoUrl == null || youtubeVideoUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link do vídeo não configurado'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    try {
      final url = Uri.parse(youtubeVideoUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Não foi possível abrir o vídeo';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir vídeo: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _openWhatsApp() async {
    if (whatsappUrl == null || whatsappUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link do WhatsApp não configurado'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    try {
      final url = Uri.parse(whatsappUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Não foi possível abrir o WhatsApp';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir WhatsApp: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _openComunidadeWhatsApp() async {
    if (comunidadeUrl == null || comunidadeUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link da comunidade não configurado'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    try {
      final url = Uri.parse(comunidadeUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Não foi possível abrir o WhatsApp';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao abrir comunidade: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TutorialSuporteModel());
    _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      final client = supabaseService.client;
      final currentUser = supabaseService.currentUser;

      // Buscar primeira linha da tabela system_configuration
      final responseList = await client
          .from('system_configuration')
          .select('link_youtube, link_whatsapp, link_comunidade')
          .limit(1);

      // Verificar se o usuário tem um plano ativo
      bool userHasActivePlan = false;
      if (currentUser != null) {
        try {
          final planResponse = await client
              .from('user_plans')
              .select('is_active')
              .eq('user_id', currentUser.id)
              .eq('is_active', true)
              .limit(1)
              .maybeSingle();

          userHasActivePlan = planResponse != null;
        } catch (e) {
          print('Erro ao verificar plano do usuário: $e');
          // Continuar mesmo se houver erro na verificação do plano
        }
      }

      if (responseList is List && responseList.isNotEmpty) {
        final response = responseList.first as Map<String, dynamic>;
        
        final youtubeLink = response['link_youtube'] as String?;
        final whatsappLink = response['link_whatsapp'] as String?;
        final comunidadeLink = response['link_comunidade'] as String?;
        
        setState(() {
          youtubeVideoUrl = youtubeLink?.isNotEmpty == true ? youtubeLink : null;
          whatsappUrl = whatsappLink?.isNotEmpty == true ? whatsappLink : null;
          comunidadeUrl = comunidadeLink?.isNotEmpty == true ? comunidadeLink : null;
          hasActivePlan = userHasActivePlan;
          isLoading = false;
          errorMessage = null;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Configuração não encontrada. Verifique se a tabela system_configuration possui dados.';
        });
      }
    } catch (e) {
      print('Erro ao carregar configuração: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Erro ao carregar configurações: $e';
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
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 24.0,
            ),
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Tutorial e Suporte',
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
          child: isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                )
              : errorMessage != null && youtubeVideoUrl == null && whatsappUrl == null
                  ? Center(
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: FlutterFlowTheme.of(context).error,
                              size: 48,
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                              child: Text(
                                errorMessage!,
                                textAlign: TextAlign.center,
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                      font: GoogleFonts.poppins(),
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                              child: FFButtonWidget(
                                onPressed: _loadConfiguration,
                                text: 'Tentar Novamente',
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
                  // Título
                  Text(
                    'Como Usar o App',
                    style: FlutterFlowTheme.of(context).headlineMedium.override(
                          font: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                          letterSpacing: 0.0,
                        ),
                  ),
                  // Subtítulo
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 24.0),
                    child: Text(
                      'Assista ao vídeo tutorial abaixo para aprender a usar todas as funcionalidades do app.',
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            font: GoogleFonts.poppins(),
                            color: FlutterFlowTheme.of(context).secondary,
                            letterSpacing: 0.0,
                          ),
                    ),
                  ),
                  // Container do Vídeo do YouTube
                  if (youtubeVideoUrl != null && youtubeVideoUrl!.isNotEmpty && errorMessage == null)
                    GestureDetector(
                      onTap: _openYouTubeVideo,
                      child: Container(
                        width: double.infinity,
                        height: 220.0,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).secondaryBackground,
                          borderRadius: BorderRadius.circular(16.0),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 4,
                              color: FlutterFlowTheme.of(context).primary.withOpacity(0.1),
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Thumbnail do YouTube ou placeholder
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16.0),
                              child: Container(
                                width: double.infinity,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context).alternate,
                                ),
                                child: _extractYouTubeVideoId(youtubeVideoUrl) != null
                                    ? Image.network(
                                        'https://img.youtube.com/vi/${_extractYouTubeVideoId(youtubeVideoUrl)}/maxresdefault.jpg',
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: FlutterFlowTheme.of(context).alternate,
                                            child: Icon(
                                              Icons.play_circle_outline,
                                              size: 64,
                                              color: FlutterFlowTheme.of(context).secondary,
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: FlutterFlowTheme.of(context).alternate,
                                        child: Icon(
                                          Icons.play_circle_outline,
                                          size: 64,
                                          color: FlutterFlowTheme.of(context).secondary,
                                        ),
                                      ),
                              ),
                            ),
                            // Overlay com botão de play
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(16.0),
                              ),
                              child: Center(
                                child: Container(
                                  width: 64.0,
                                  height: 64.0,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        blurRadius: 8,
                                        color: Colors.black.withOpacity(0.3),
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 36.0,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 220.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(
                          color: FlutterFlowTheme.of(context).alternate,
                          width: 1.0,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.video_library_outlined,
                              size: 48,
                              color: FlutterFlowTheme.of(context).secondary,
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 0.0),
                              child: Text(
                                'Vídeo não configurado',
                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                      font: GoogleFonts.poppins(),
                                      color: FlutterFlowTheme.of(context).secondary,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 0.0),
                    child: Text(
                      'Toque para assistir no YouTube',
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            font: GoogleFonts.poppins(),
                            color: FlutterFlowTheme.of(context).secondary,
                            letterSpacing: 0.0,
                          ),
                    ),
                  ),
                  // Botão de Suporte WhatsApp
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 32.0, 0.0, 0.0),
                    child: FFButtonWidget(
                      onPressed: _openWhatsApp,
                      text: 'Suporte no WhatsApp',
                      icon: FaIcon(
                        FontAwesomeIcons.whatsapp,
                        size: 20,
                      ),
                      options: FFButtonOptions(
                        width: double.infinity,
                        height: 56.0,
                        padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        color: Color(0xFF25D366), // Cor verde do WhatsApp
                        textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                              font: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                              color: Colors.white,
                              letterSpacing: 0.0,
                            ),
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                    child: Text(
                      'Entre em contato conosco pelo WhatsApp para tirar suas dúvidas ou reportar problemas.',
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context).bodySmall.override(
                            font: GoogleFonts.poppins(),
                            color: FlutterFlowTheme.of(context).secondary,
                            letterSpacing: 0.0,
                          ),
                    ),
                  ),
                  // Botão de Comunidade WhatsApp (apenas para usuários com plano ativo)
                  if (hasActivePlan && comunidadeUrl != null && comunidadeUrl!.isNotEmpty)
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0.0, 24.0, 0.0, 0.0),
                      child: FFButtonWidget(
                        onPressed: _openComunidadeWhatsApp,
                        text: 'Comunidade no WhatsApp',
                        icon: FaIcon(
                          FontAwesomeIcons.whatsapp,
                          size: 20,
                        ),
                        options: FFButtonOptions(
                          width: double.infinity,
                          height: 56.0,
                          padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                          iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                          color: Color(0xFF25D366), // Cor verde do WhatsApp
                          textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                                font: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                                color: Colors.white,
                                letterSpacing: 0.0,
                              ),
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  if (hasActivePlan && comunidadeUrl != null && comunidadeUrl!.isNotEmpty)
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
                      child: Text(
                        'Junte-se à nossa comunidade no WhatsApp para trocar experiências e dicas sobre fotografia.',
                        textAlign: TextAlign.center,
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
          ),
        ),
      ),
    );
  }
}

