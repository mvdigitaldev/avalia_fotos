// lib/components/evaluation_pack_card.dart
import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/evaluation_pack_model.dart';

class EvaluationPackCard extends StatelessWidget {
  const EvaluationPackCard({
    super.key,
    required this.pack,
    required this.onTap,
  });

  final EvaluationPackModel pack;
  final VoidCallback onTap;

  String _getSubtitle() {
    if (pack.isPopular) {
      return '${pack.evaluationsCount} avaliações (mais escolhido)';
    }
    if (pack.hasSavings) {
      return '${pack.evaluationsCount} avaliações (melhor custo-benefício)';
    }
    return '${pack.evaluationsCount} avaliações';
  }

  @override
  Widget build(BuildContext context) {
    final isPopular = pack.isPopular;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isPopular
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    FlutterFlowTheme.of(context).primary.withOpacity(0.015),
                    FlutterFlowTheme.of(context).primary.withOpacity(0.005),
                    FlutterFlowTheme.of(context).secondaryBackground,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                )
              : null,
          color: isPopular ? null : FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(isPopular ? 16 : 12),
          border: Border.all(
            color: isPopular
                ? FlutterFlowTheme.of(context).primary.withOpacity(0.2)
                : FlutterFlowTheme.of(context).alternate,
            width: isPopular ? 1 : 1,
          ),
          boxShadow: isPopular
              ? [
                  BoxShadow(
                    color: FlutterFlowTheme.of(context).primary.withOpacity(0.04),
                    blurRadius: 8,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 6,
                    spreadRadius: 0,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            if (pack.isPopular)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primary.withOpacity(0.6),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: Text(
                    'POPULAR',
                    style: FlutterFlowTheme.of(context).bodySmall.override(
                          font: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                          color: Colors.white,
                          fontSize: 10,
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.zero,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Container(
                  width: isPopular ? 44 : 48,
                  height: isPopular ? 44 : 48,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primaryBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.photo_camera,
                    color: FlutterFlowTheme.of(context).primary,
                    size: isPopular ? 22 : 24,
                  ),
                ),
                SizedBox(width: isPopular ? 10 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pack.name,
                              style: FlutterFlowTheme.of(context).titleMedium.override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    letterSpacing: 0.0,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (pack.hasSavings && !pack.isPopular) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context).primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ECONOMIA',
                                style: FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      color: Colors.white,
                                      fontSize: 10,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getSubtitle(),
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              font: GoogleFonts.poppins(),
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0.0,
                            ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (pack.isPopular) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: FlutterFlowTheme.of(context).success,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Ideal para quem usa frequentemente',
                                overflow: TextOverflow.ellipsis,
                                style: FlutterFlowTheme.of(context).bodySmall.override(
                                      font: GoogleFonts.poppins(),
                                      color: FlutterFlowTheme.of(context).success,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (pack.pricePerUnit.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).alternate.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pack.pricePerUnit,
                            overflow: TextOverflow.ellipsis,
                            style: FlutterFlowTheme.of(context).bodySmall.override(
                                  font: GoogleFonts.poppins(),
                                  color: FlutterFlowTheme.of(context).secondaryText,
                                  fontSize: 12,
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).primary.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: FlutterFlowTheme.of(context).primary.withOpacity(0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Comprar por ${pack.formattedPrice}',
                              textAlign: TextAlign.center,
                              style: FlutterFlowTheme.of(context).titleSmall.override(
                                    font: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    color: Colors.white,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          ],
        ),
      ),
    );
  }
}
