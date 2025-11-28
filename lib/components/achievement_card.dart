import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/achievement_model.dart';
import '../flutter_flow/flutter_flow_theme.dart';
import 'package:intl/intl.dart';

class AchievementCard extends StatelessWidget {
  final AchievementModel achievement;
  final int? currentProgress;
  final int? requirementTotal;
  final VoidCallback? onTap;

  const AchievementCard({
    super.key,
    required this.achievement,
    this.currentProgress,
    this.requirementTotal,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final progress = currentProgress ?? 0;
    final total = requirementTotal ?? achievement.getRequirementTotal() ?? 1;
    final progressPercent = total > 0 ? (progress / total).clamp(0.0, 1.0) : 0.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: achievement.isUnlocked
              ? theme.secondaryBackground
              : theme.secondaryBackground.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: achievement.isUnlocked
                ? theme.primary
                : theme.alternate.withOpacity(0.3),
            width: achievement.isUnlocked ? 2 : 1,
          ),
          boxShadow: achievement.isUnlocked
              ? [
                  BoxShadow(
                    color: theme.primary.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Imagem da conquista
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: achievement.isUnlocked
                  ? null
                  : theme.alternate.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Stack(
              children: [
                // Ícone da conquista (cadeado se bloqueada, SVG se desbloqueada)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: achievement.isUnlocked
                        ? SvgPicture.string(
                            achievement.img,
                            width: 70,
                            height: 70,
                            fit: BoxFit.contain,
                          )
                        : Icon(
                            Icons.lock,
                            size: 60,
                            color: theme.secondaryText.withOpacity(0.5),
                          ),
                  ),
                ),
                // Badge de desbloqueada
                if (achievement.isUnlocked)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: theme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Conteúdo
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Título
                  Text(
                    achievement.title,
                    style: theme.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: achievement.isUnlocked
                          ? theme.primaryText
                          : theme.secondaryText,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Descrição
                  Flexible(
                    child: Text(
                      achievement.description,
                      style: theme.bodySmall.copyWith(
                        color: achievement.isUnlocked
                            ? theme.primaryText.withOpacity(0.8)
                            : theme.primaryText.withOpacity(0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.normal,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progresso (se não desbloqueada)
                  if (!achievement.isUnlocked && total > 0)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '$progress / $total',
                                style: theme.bodySmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.primary,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${(progressPercent * 100).toInt()}%',
                              style: theme.bodySmall.copyWith(
                                color: theme.secondaryText,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progressPercent,
                            backgroundColor: theme.alternate.withOpacity(0.2),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.primary,
                            ),
                            minHeight: 4,
                          ),
                        ),
                      ],
                    ),
                  // Data de desbloqueio (se desbloqueada)
                  if (achievement.isUnlocked && achievement.unlockedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 10,
                            color: theme.secondaryText,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Desbloqueada em ${DateFormat('dd/MM/yyyy').format(achievement.unlockedAt!)}',
                              style: theme.bodySmall.copyWith(
                                color: theme.secondaryText,
                                fontSize: 9,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

