// lib/components/progress_bar_widget.dart
import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProgressBarWidget extends StatefulWidget {
  final int current;
  final int? total;
  final String label;
  final Color? progressColor;
  final Color? backgroundColor;

  const ProgressBarWidget({
    super.key,
    required this.current,
    this.total,
    required this.label,
    this.progressColor,
    this.backgroundColor,
  });

  @override
  State<ProgressBarWidget> createState() => _ProgressBarWidgetState();
}

class _ProgressBarWidgetState extends State<ProgressBarWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  double get _progress {
    if (widget.total == null || widget.total == 0) return 0.0;
    return (widget.current / widget.total!).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final progressColor = widget.progressColor ?? FlutterFlowTheme.of(context).primary;
    final backgroundColor = widget.backgroundColor ?? FlutterFlowTheme.of(context).alternate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                    letterSpacing: 0.0,
                  ),
            ),
            Text(
              widget.total == null
                  ? '${widget.current}'
                  : '${widget.current}/${widget.total}',
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                    ),
                    color: FlutterFlowTheme.of(context).secondary,
                    letterSpacing: 0.0,
                  ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0, 8, 0, 0),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: 12,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              AnimatedBuilder(
                animation: _animation,
                builder: (context, child) {
                  return FractionallySizedBox(
                    widthFactor: _progress * _animation.value,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: progressColor,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: progressColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (widget.total != null && widget.total! > 0)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(0, 4, 0, 0),
            child: Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.poppins(),
                    color: FlutterFlowTheme.of(context).secondary,
                    fontSize: 10,
                    letterSpacing: 0.0,
                  ),
            ),
          ),
      ],
    );
  }
}

