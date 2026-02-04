// lib/components/verified_badge.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

enum VerifiedBadgeSize { small, medium, large }

class VerifiedBadge extends StatelessWidget {
  final VerifiedBadgeSize size;

  const VerifiedBadge({
    super.key,
    this.size = VerifiedBadgeSize.medium,
  });

  double _getSize() {
    switch (size) {
      case VerifiedBadgeSize.small:
        return 20.0;
      case VerifiedBadgeSize.medium:
        return 28.0;
      case VerifiedBadgeSize.large:
        return 36.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _getSize();
    return SizedBox(
      width: s,
      height: s,
      child: CustomPaint(
        painter: _VerifiedBadgePainter(),
      ),
    );
  }
}

class _VerifiedBadgePainter extends CustomPainter {
  static const Color _orange = Color(0xFFFF4C00);
  static const Color _white = Color(0xFFFFFFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(cx, cy) - 0.5;
    const outerPoints = 12;
    const innerRadiusRatio = 0.5;

    // Desenhar estrela 12 pontas
    final starPath = Path();
    for (var i = 0; i < outerPoints * 2; i++) {
      final angle = (i * math.pi / outerPoints) - math.pi / 2;
      final radius = i.isEven ? r : r * innerRadiusRatio;
      final x = cx + radius * math.cos(angle);
      final y = cy + radius * math.sin(angle);
      if (i == 0) {
        starPath.moveTo(x, y);
      } else {
        starPath.lineTo(x, y);
      }
    }
    starPath.close();
    canvas.drawPath(starPath, Paint()..color = _orange);

    // Desenhar checkmark branco no centro
    final checkSize = r * 0.55;
    final checkPath = Path();
    checkPath.moveTo(cx - checkSize * 0.6, cy);
    checkPath.lineTo(cx - checkSize * 0.15, cy + checkSize * 0.45);
    checkPath.lineTo(cx + checkSize * 0.65, cy - checkSize * 0.55);
    checkPath.lineTo(cx + checkSize * 0.45, cy - checkSize * 0.7);
    checkPath.lineTo(cx - checkSize * 0.15, cy + checkSize * 0.05);
    checkPath.lineTo(cx - checkSize * 0.35, cy - checkSize * 0.15);
    checkPath.close();

    canvas.drawPath(checkPath, Paint()..color = _white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
