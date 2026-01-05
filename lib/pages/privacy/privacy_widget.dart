// lib/pages/privacy/privacy_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class PrivacyWidget extends StatelessWidget {
  const PrivacyWidget({super.key});

  static String routeName = 'privacy';
  static String routePath = '/privacy';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          'Política de Privacidade',
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
        child: SingleChildScrollView(
          padding: EdgeInsetsDirectional.fromSTEB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                context,
                '1. Informações Coletadas',
                'Coletamos informações que você nos fornece diretamente, incluindo nome de usuário, email, fotos que você envia, comentários e outras informações relacionadas ao uso do aplicativo.',
              ),
              _buildSection(
                context,
                '2. Uso das Informações',
                'Utilizamos suas informações para fornecer, manter e melhorar nossos serviços, processar transações, enviar notificações e comunicação relacionada ao serviço.',
              ),
              _buildSection(
                context,
                '3. Sistema de Denúncias e Moderação',
                'Nosso aplicativo possui um sistema de denúncias e moderação de conteúdo para manter um ambiente seguro e respeitoso. Os usuários podem denunciar conteúdo inapropriado, e nossos administradores revisam todas as denúncias. Conteúdo que viole nossas políticas pode ser removido, e usuários que violarem repetidamente as regras podem ter suas contas suspensas ou banidas. Implementamos também moderação automática de comentários para prevenir conteúdo ofensivo, racista, sexista, homofóbico, xenofóbico ou que promova ódio.',
              ),
              _buildSection(
                context,
                '4. Responsabilidades do Usuário',
                'Os usuários são responsáveis por todo o conteúdo que publicam. Você concorda em não publicar conteúdo que seja ilegal, difamatório, ofensivo, que viole direitos de terceiros ou que seja considerado inadequado por nossa equipe de moderação. Ao usar nosso serviço, você concorda em respeitar todos os outros usuários e manter um ambiente positivo.',
              ),
              _buildSection(
                context,
                '5. Processo de Revisão de Denúncias',
                'Todas as denúncias são revisadas por nossa equipe de administradores. Se uma denúncia for aprovada, o conteúdo será removido. Se uma denúncia for rejeitada, o conteúdo permanecerá publicado. Nosso objetivo é garantir justiça e transparência em todo o processo de moderação.',
              ),
              _buildSection(
                context,
                '6. Compartilhamento de Informações',
                'Não vendemos suas informações pessoais. Podemos compartilhar informações apenas quando necessário para fornecer nossos serviços, cumprir obrigações legais ou proteger nossos direitos.',
              ),
              _buildSection(
                context,
                '7. Segurança',
                'Implementamos medidas de segurança técnicas e organizacionais para proteger suas informações contra acesso não autorizado, alteração, divulgação ou destruição.',
              ),
              _buildSection(
                context,
                '8. Alterações nesta Política',
                'Podemos atualizar esta política de privacidade ocasionalmente. Notificaremos você sobre alterações significativas através do aplicativo ou por email.',
              ),
              _buildSection(
                context,
                '9. Contato',
                'Se você tiver dúvidas sobre esta política de privacidade, entre em contato conosco através do aplicativo.',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: FlutterFlowTheme.of(context).titleMedium.override(
                  font: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                  ),
                  letterSpacing: 0.0,
                ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(0, 8, 0, 0),
            child: Text(
              content,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.poppins(),
                    letterSpacing: 0.0,
                  ).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

