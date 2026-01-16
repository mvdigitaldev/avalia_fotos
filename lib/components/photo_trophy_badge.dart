// lib/components/photo_trophy_badge.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
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

  @override
  Widget build(BuildContext context) {
    final badgeSize = _getBadgeSize();
    final iconSize = _getIconSize();

    return Align(
      alignment: alignment,
      child: Container(
        padding: EdgeInsets.all(badgeSize * 0.15),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              FontAwesomeIcons.trophy,
              size: iconSize,
              color: const Color(0xFFFFD700), // Dourado
            ),
            if (showLabel)
              Positioned(
                bottom: -badgeSize * 0.3,
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
                      fontSize: badgeSize * 0.12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _getBadgeSize() {
    switch (size) {
      case TrophyBadgeSize.small:
        return 32.0;
      case TrophyBadgeSize.medium:
        return 48.0;
      case TrophyBadgeSize.large:
        return 64.0;
    }
  }

  double _getIconSize() {
    switch (size) {
      case TrophyBadgeSize.small:
        return 20.0;
      case TrophyBadgeSize.medium:
        return 30.0;
      case TrophyBadgeSize.large:
        return 40.0;
    }
  }
}

