// lib/components/upgrade_post_card.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/plans_navigation_helper.dart';

class UpgradePostCard extends StatelessWidget {
  const UpgradePostCard({
    super.key,
    this.onUpgrade,
    this.variant = 1,
  });

  final VoidCallback? onUpgrade;
  final int variant;

  static const List<String> _benefits = [
    'Sem interrupções no seu fluxo',
    'Sem anúncios',
    'Acesso a todas as funcionalidades',
    '+ de 200 avaliações por mês',
    '+ de 1000 fotos armazenadas',
  ];

  Widget _buildBenefitRow(BuildContext context, String text, {double iconSize = 20}) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: FlutterFlowTheme.of(context).success,
            size: iconSize,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(8, 0, 0, 0),
              child: Text(
                text,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.poppins(),
                      letterSpacing: 0.0,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(20.0, 12.0, 20.0, 12.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          CircleAvatar(
            radius: 20.0,
            backgroundColor: FlutterFlowTheme.of(context).primary.withOpacity(0.15),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: FlutterFlowTheme.of(context).primary,
              size: 24.0,
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 0.0, 0.0),
            child: Text(
              'AvaliaFotos Premium',
              style: FlutterFlowTheme.of(context).titleSmall.override(
                    font: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                    fontSize: 14.0,
                    letterSpacing: 0.0,
                  ),
            ),
          ),
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 10.0, 0.0),
            child: Icon(
              Icons.circle,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 8.0,
            ),
          ),
          Expanded(
            child: Text(
              'Patrocinado',
              style: GoogleFonts.poppins(
                color: FlutterFlowTheme.of(context).secondary,
                fontSize: 10.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCtaButton(BuildContext context) {
    return FFButtonWidget(
      onPressed: onUpgrade ?? () => PlansNavigationHelper.navigateToPlans(context),
      text: 'Ver Planos Disponíveis',
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
    );
  }

  Widget _buildBanner1(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        _buildHeader(context),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Desbloqueie todo o potencial!',
                style: FlutterFlowTheme.of(context).headlineSmall.override(
                      font: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                      ),
                      letterSpacing: 0.0,
                    ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0, 8, 0, 0),
                child: Text(
                  'Upgrade para planos pagos e tenha acesso ilimitado a todas as funcionalidades do app.',
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        font: GoogleFonts.poppins(),
                        color: FlutterFlowTheme.of(context).secondaryText,
                        letterSpacing: 0.0,
                      ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0, 16, 0, 20),
                child: Column(
                  children: _benefits.map((b) => _buildBenefitRow(context, b)).toList(),
                ),
              ),
              _buildCtaButton(context),
            ],
          ),
        ),
        _buildSeparator(context),
      ],
    );
  }

  Widget _buildBanner2(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        _buildHeader(context),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mais que o básico.',
                          style: FlutterFlowTheme.of(context).headlineSmall.override(
                                font: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                ),
                                letterSpacing: 0.0,
                              ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(0, 8, 0, 0),
                          child: Text(
                            'Planos pagos: sem anúncios, sem interrupções e muito mais recurso.',
                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.poppins(),
                                  color: FlutterFlowTheme.of(context).secondaryText,
                                  fontSize: 13,
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 16),
                  SizedBox(
                    width: 140,
                    child: _buildCtaButton(context),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0, 20, 0, 0),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _benefits.map((b) {
                    return Container(
                      padding: EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: FlutterFlowTheme.of(context).success,
                            size: 16,
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(6, 0, 0, 0),
                            child: Text(
                              b,
                              style: FlutterFlowTheme.of(context).bodySmall.override(
                                    font: GoogleFonts.poppins(),
                                    fontSize: 12,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        _buildSeparator(context),
      ],
    );
  }

  Widget _buildBanner3(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max,
      children: [
        _buildHeader(context),
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Desbloqueie todo o potencial!',
                style: FlutterFlowTheme.of(context).headlineSmall.override(
                      font: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                      ),
                      letterSpacing: 0.0,
                    ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
                child: Text(
                  'O que você ganha:',
                  style: FlutterFlowTheme.of(context).titleMedium.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                        ),
                        fontSize: 14,
                        letterSpacing: 0.0,
                      ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 20),
                child: Column(
                  children: _benefits.map((b) => _buildBenefitRow(context, b, iconSize: 18)).toList(),
                ),
              ),
              _buildCtaButton(context),
            ],
          ),
        ),
        _buildSeparator(context),
      ],
    );
  }

  Widget _buildSeparator(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.9,
        height: 1.0,
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).alternate.withOpacity(0.3),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = variant.clamp(1, 3);
    Widget content;
    switch (v) {
      case 2:
        content = _buildBanner2(context);
        break;
      case 3:
        content = _buildBanner3(context);
        break;
      default:
        content = _buildBanner1(context);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(),
      margin: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 40.0),
      child: Container(
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
        ),
        child: content,
      ),
    );
  }
}
