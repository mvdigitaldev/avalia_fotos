// lib/components/photo_trophy_badge.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_theme.dart';

enum TrophyBadgeSize { small, medium, large }

enum TrophyAwardKind { day, week, month }

class PhotoTrophyBadge extends StatelessWidget {
  final TrophyBadgeSize size;
  final TrophyAwardKind kind;
  final bool showLabel;
  final Alignment alignment;

  const PhotoTrophyBadge({
    super.key,
    this.size = TrophyBadgeSize.medium,
    this.kind = TrophyAwardKind.day,
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

  String get _assetPath {
    switch (kind) {
      case TrophyAwardKind.day:
        return 'assets/images/selo-dia.png';
      case TrophyAwardKind.week:
        return 'assets/images/selo-semana.png';
      case TrophyAwardKind.month:
        return 'assets/images/selo-mes.png';
    }
  }

  String get _label {
    switch (kind) {
      case TrophyAwardKind.day:
        return 'Foto do Dia';
      case TrophyAwardKind.week:
        return 'Foto da Semana';
      case TrophyAwardKind.month:
        return 'Foto do Mês';
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
            _assetPath,
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
                  _label,
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

/// Selos empilhados (canto do card) — dia, semana e mês.
class PhotoAwardBadgesColumn extends StatelessWidget {
  const PhotoAwardBadgesColumn({
    super.key,
    required this.isDay,
    required this.isWeek,
    required this.isMonth,
    this.size = TrophyBadgeSize.medium,
  });

  final bool isDay;
  final bool isWeek;
  final bool isMonth;
  final TrophyBadgeSize size;

  double get _spacing {
    switch (size) {
      case TrophyBadgeSize.small:
        return 4;
      case TrophyBadgeSize.medium:
        return 6;
      case TrophyBadgeSize.large:
        return 8;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isDay) ...[
          PhotoTrophyBadge(size: size, kind: TrophyAwardKind.day),
          if (isWeek || isMonth) SizedBox(height: _spacing),
        ],
        if (isWeek) ...[
          PhotoTrophyBadge(size: size, kind: TrophyAwardKind.week),
          if (isMonth) SizedBox(height: _spacing),
        ],
        if (isMonth) PhotoTrophyBadge(size: size, kind: TrophyAwardKind.month),
      ],
    );
  }
}
