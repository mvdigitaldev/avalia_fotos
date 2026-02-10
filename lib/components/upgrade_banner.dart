// lib/components/upgrade_banner.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/plans_navigation_helper.dart';

class UpgradeBanner extends StatelessWidget {
  const UpgradeBanner({
    super.key,
    required this.title,
    required this.message,
    this.ctaText,
    this.onDismiss,
    this.dismissible = true,
  });

  final String title;
  final String message;
  final String? ctaText;
  final VoidCallback? onDismiss;
  final bool dismissible;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FlutterFlowTheme.of(context).primary.withOpacity(0.1),
            FlutterFlowTheme.of(context).primary.withOpacity(0.05),
          ],
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FlutterFlowTheme.of(context).primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(16, 16, dismissible ? 40 : 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: FlutterFlowTheme.of(context).titleSmall.override(
                        font: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                        ),
                        letterSpacing: 0.0,
                      ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
                  child: Text(
                    message,
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          font: GoogleFonts.poppins(),
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
                  child: FFButtonWidget(
                    onPressed: () => PlansNavigationHelper.navigateToPlans(context),
                    text: ctaText ?? 'Ver Planos',
                    options: FFButtonOptions(
                      height: 36,
                      padding: EdgeInsetsDirectional.fromSTEB(16, 0, 16, 0),
                      iconPadding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                      color: FlutterFlowTheme.of(context).primary,
                      textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                            font: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                            color: Colors.white,
                            fontSize: 12,
                            letterSpacing: 0.0,
                          ),
                      elevation: 0,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (dismissible)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: FlutterFlowTheme.of(context).secondaryText,
                  size: 20,
                ),
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ),
        ],
      ),
    );
  }
}
