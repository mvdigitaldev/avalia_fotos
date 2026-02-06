// lib/components/photo_trophy_badge.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_theme.dart';

enum TrophyBadgeSize { small, medium, large }

class PhotoTrophyBadge extends StatelessWidget {
  final TrophyBadgeSize size;
  final bool showLabel;
  final Alignment alignment;

  const PhotoTrophyBadge({
    super.key,
    this.size = TrophyBadgeSize.medium,
    this.showLabel = false,
    this.alignment = Alignment.topRight,
  });

  double get _sealSize {
    switch (size) {
      case TrophyBadgeSize.small:
        return 50.0;
      case TrophyBadgeSize.medium:
      case TrophyBadgeSize.large:
        return 120.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Image.asset(
            'assets/images/selo-dia.png',
            width: _sealSize,
            height: _sealSize,
            fit: BoxFit.contain,
          ),
          if (showLabel)
            Positioned(
              bottom: -_sealSize * 0.3,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Foto do Dia',
                  style: GoogleFonts.poppins(
                    fontSize: _sealSize * 0.12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
