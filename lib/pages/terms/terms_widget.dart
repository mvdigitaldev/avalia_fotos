// lib/pages/terms/terms_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class TermsWidget extends StatelessWidget {
  const TermsWidget({super.key});

  static String routeName = 'terms';
  static String routePath = '/terms';

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
          'Termos de Uso',
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
                '1. Aceitação dos Termos',
                'Ao usar este aplicativo, você concorda em cumprir e estar vinculado a estes Termos de Uso. Se você não concordar com qualquer parte destes termos, não deve usar nosso serviço.',
              ),
              _buildSection(
                context,
                '2. Uso do Serviço',
                'Você concorda em usar nosso serviço apenas para fins legais e de acordo com estes Termos de Uso. Você não deve usar o serviço de qualquer forma que possa danificar, desabilitar, sobrecarregar ou comprometer nossos servidores ou redes.',
              ),
              _buildSection(
                context,
                '3. Conteúdo do Usuário',
                'Você é responsável por todo o conteúdo que publica, incluindo fotos, comentários e outras informações. Você garante que possui todos os direitos necessários para publicar o conteúdo e que o conteúdo não viola direitos de terceiros.',
              ),
              _buildSection(
                context,
                '4. Conduta Proibida',
                'Você concorda em NÃO:\n'
                    '• Publicar conteúdo ofensivo, difamatório, calunioso, obsceno ou ilegal\n'
                    '• Publicar conteúdo racista, sexista, homofóbico, xenofóbico, misógino ou que promova ódio\n'
                    '• Publicar conteúdo que viole direitos autorais ou outros direitos de propriedade intelectual\n'
                    '• Assediar, intimidar ou ameaçar outros usuários\n'
                    '• Publicar spam, conteúdo comercial não autorizado ou links maliciosos\n'
                    '• Tentar obter acesso não autorizado a sistemas ou dados\n'
                    '• Usar o serviço para atividades fraudulentas ou enganosas',
              ),
              _buildSection(
                context,
                '5. Sistema de Denúncias e Moderação',
                'Implementamos um sistema de denúncias e moderação para manter um ambiente seguro e respeitoso. Os usuários podem denunciar conteúdo que viola nossos termos. Nossos administradores revisam todas as denúncias e podem remover conteúdo que viole nossas políticas. Também implementamos moderação automática de comentários que bloqueia conteúdo ofensivo antes da publicação.',
              ),
              _buildSection(
                context,
                '6. Consequências de Violação',
                'Se você violar estes Termos de Uso, podemos, a nosso critério, remover seu conteúdo, suspender ou encerrar sua conta, e tomar outras medidas legais apropriadas. Violações repetidas podem resultar em banimento permanente.',
              ),
              _buildSection(
                context,
                '7. Propriedade Intelectual',
                'Todo o conteúdo do aplicativo, incluindo design, texto, gráficos, logos e software, é propriedade nossa ou de nossos licenciadores e está protegido por leis de direitos autorais e outras leis de propriedade intelectual.',
              ),
              _buildSection(
                context,
                '8. Limitação de Responsabilidade',
                'Nosso serviço é fornecido "como está" e "conforme disponível". Não garantimos que o serviço será ininterrupto, seguro ou livre de erros. Não seremos responsáveis por quaisquer danos diretos, indiretos, incidentais ou consequenciais decorrentes do uso do serviço.',
              ),
              _buildSection(
                context,
                '9. Modificações dos Termos',
                'Reservamo-nos o direito de modificar estes Termos de Uso a qualquer momento. Alterações significativas serão notificadas através do aplicativo. O uso continuado do serviço após tais modificações constitui sua aceitação dos novos termos.',
              ),
              _buildSection(
                context,
                '10. Rescisão',
                'Podemos encerrar ou suspender seu acesso ao serviço imediatamente, sem aviso prévio, por qualquer motivo, incluindo violação destes Termos de Uso.',
              ),
              _buildSection(
                context,
                '11. Lei Aplicável',
                'Estes Termos de Uso são regidos pelas leis aplicáveis. Qualquer disputa relacionada a estes termos será resolvida nos tribunais competentes.',
              ),
              _buildSection(
                context,
                '12. Contato',
                'Se você tiver dúvidas sobre estes Termos de Uso, entre em contato conosco através do aplicativo.',
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

