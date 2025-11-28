// lib/components/load_more_button.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoadMoreButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool hasMore;
  final String text;

  const LoadMoreButton({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.hasMore = true,
    this.text = 'Mostrar Mais',
  });

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return Padding(
        padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 16.0),
        child: Center(
          child: Text(
            'Não há mais itens para carregar',
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  font: GoogleFonts.poppins(),
                  color: FlutterFlowTheme.of(context).secondary,
                  letterSpacing: 0.0,
                ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 16.0),
      child: Center(
        child: FFButtonWidget(
          onPressed: isLoading ? null : onPressed,
          text: isLoading ? 'Carregando...' : text,
          options: FFButtonOptions(
            width: 200.0,
            height: 44.0,
            padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
            iconPadding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
            color: FlutterFlowTheme.of(context).primary,
            textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                  font: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                  color: Colors.white,
                  letterSpacing: 0.0,
                ),
            elevation: 2.0,
            borderRadius: BorderRadius.circular(22.0),
          ),
        ),
      ),
    );
  }
}

