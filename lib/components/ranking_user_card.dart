// lib/components/ranking_user_card.dart
import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/ranking_item_model.dart';
import '../utils/logger.dart';

class RankingUserCard extends StatelessWidget {
  final RankingItemModel user;
  final bool isTopThree;

  const RankingUserCard({
    super.key,
    required this.user,
    this.isTopThree = false,
  });

  Color _getPositionColor(BuildContext context) {
    switch (user.position) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey.shade400;
      case 3:
        return Colors.brown.shade400;
      default:
        return FlutterFlowTheme.of(context).primary;
    }
  }

  IconData _getPositionIcon() {
    switch (user.position) {
      case 1:
        return Icons.emoji_events;
      case 2:
        return Icons.workspace_premium;
      case 3:
        return Icons.military_tech;
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      final isTopThree = user.position <= 3;
      final positionColor = _getPositionColor(context);

      return Container(
        margin: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 12.0),
        padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: isTopThree
                ? positionColor.withOpacity(0.3)
                : FlutterFlowTheme.of(context).alternate.withOpacity(0.5),
            width: isTopThree ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 4,
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Posição
            Container(
              width: 40.0,
              alignment: Alignment.center,
              child: Text(
                '${user.position}',
                style: FlutterFlowTheme.of(context).titleLarge.override(
                      font: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                      ),
                      color: isTopThree
                          ? positionColor
                          : FlutterFlowTheme.of(context).secondaryText,
                      fontSize: 18.0,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
            SizedBox(width: 12.0),
            // Avatar
            Container(
              width: 48.0,
              height: 48.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isTopThree
                      ? positionColor
                      : FlutterFlowTheme.of(context).alternate,
                  width: isTopThree ? 2.0 : 1.5,
                ),
              ),
              child: ClipOval(
                child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: user.avatarUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: FlutterFlowTheme.of(context).alternate,
                          child: Icon(
                            Icons.person,
                            color: FlutterFlowTheme.of(context).secondary,
                            size: 24.0,
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: FlutterFlowTheme.of(context).alternate,
                          child: Icon(
                            Icons.person,
                            color: FlutterFlowTheme.of(context).secondary,
                            size: 24.0,
                          ),
                        ),
                      )
                    : Container(
                        color: FlutterFlowTheme.of(context).alternate,
                        child: Icon(
                          Icons.person,
                          color: FlutterFlowTheme.of(context).secondary,
                          size: 24.0,
                        ),
                      ),
              ),
            ),
            SizedBox(width: 12.0),
            // Informações do usuário
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    user.username ?? 'Usuário',
                    style: FlutterFlowTheme.of(context).titleMedium.override(
                          font: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                          fontSize: 16.0,
                          letterSpacing: 0.0,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.0),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: positionColor,
                        size: 14.0,
                      ),
                      SizedBox(width: 4.0),
                      Text(
                        user.score.toStringAsFixed(1),
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              font: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                              ),
                              color: positionColor,
                              fontSize: 14.0,
                              letterSpacing: 0.0,
                            ),
                      ),
                      SizedBox(width: 12.0),
                      Icon(
                        Icons.photo_camera_outlined,
                        color: FlutterFlowTheme.of(context).secondaryText,
                        size: 14.0,
                      ),
                      SizedBox(width: 4.0),
                      Text(
                        '${user.photosCount}',
                        style: FlutterFlowTheme.of(context).bodySmall.override(
                              font: GoogleFonts.poppins(),
                              color: FlutterFlowTheme.of(context).secondaryText,
                              fontSize: 12.0,
                              letterSpacing: 0.0,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } catch (e, stackTrace) {
      Logger.error('Erro no build do RankingUserCard', e, stackTrace);
      return Container(
        margin: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 12.0),
        padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Text(
          'Erro ao renderizar card: ${e.toString()}',
          style: TextStyle(color: Colors.red),
        ),
      );
    }
  }
}
