import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../services/achievement_service.dart';
import '../../models/achievement_model.dart';
import '../../utils/logger.dart';
import '../../components/achievement_card.dart';
import 'conquistas_model.dart';
export 'conquistas_model.dart';

class ConquistasWidget extends StatefulWidget {
  const ConquistasWidget({super.key});

  static String routeName = 'conquistas';
  static String routePath = '/conquistas';

  @override
  State<ConquistasWidget> createState() => _ConquistasWidgetState();
}

class _ConquistasWidgetState extends State<ConquistasWidget> {
  late ConquistasModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late AchievementService _achievementService;
  bool _servicesInitialized = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ConquistasModel());
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    try {
      final supabaseService = await SupabaseService.getInstance();
      _achievementService = AchievementService(supabaseService);
      setState(() {
        _servicesInitialized = true;
      });
      await _loadAchievements();
    } catch (e, stackTrace) {
      Logger.error('Erro ao inicializar serviços', e, stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao inicializar serviços: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    }
  }

  Future<void> _loadAchievements() async {
    if (!_servicesInitialized) return;

    final userId = _achievementService.currentUserId;
    if (userId == null) return;

    safeSetState(() {
      _model.isLoading = true;
      _model.errorMessage = null;
    });

    try {
      // Buscar conquistas e estatísticas do usuário
      final achievements = await _achievementService.getAllAchievements();
      final stats = await _achievementService.getUserStats(userId);

      safeSetState(() {
        _model.achievements = achievements;
        _model.userStats = stats;
        _model.isLoading = false;
      });
    } catch (e, stackTrace) {
      Logger.error('Erro ao carregar conquistas', e, stackTrace);
      safeSetState(() {
        _model.isLoading = false;
        _model.errorMessage = 'Erro ao carregar conquistas: $e';
      });
    }
  }

  void _showAchievementDetails(
    BuildContext context,
    AchievementModel achievement,
    int? currentProgress,
    int? requirementTotal,
  ) {
    final theme = FlutterFlowTheme.of(context);
    final progress = currentProgress ?? 0;
    final total = requirementTotal ?? achievement.getRequirementTotal() ?? 1;
    final progressPercent = total > 0 ? (progress / total).clamp(0.0, 1.0) : 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Handle bar
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: theme.alternate.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Ícone da conquista
                    Container(
                      height: 150,
                      width: 150,
                      decoration: BoxDecoration(
                        color: achievement.isUnlocked
                            ? theme.alternate.withOpacity(0.1)
                            : theme.alternate.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Center(
                        child: achievement.isUnlocked
                            ? SvgPicture.string(
                                achievement.img,
                                width: 120,
                                height: 120,
                                fit: BoxFit.contain,
                              )
                            : Icon(
                                Icons.lock,
                                size: 100,
                                color: theme.secondaryText.withOpacity(0.5),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Título
                    Text(
                      achievement.title,
                      style: theme.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    // Descrição
                    Text(
                      achievement.description,
                      style: theme.bodyMedium.copyWith(
                        color: theme.primaryText.withOpacity(0.8),
                        fontSize: 15,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Se desbloqueada: mostrar data
                    if (achievement.isUnlocked && achievement.unlockedAt != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: theme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.primary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 18,
                              color: theme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Desbloqueada em ${DateFormat('dd/MM/yyyy').format(achievement.unlockedAt!)}',
                              style: theme.bodyMedium.copyWith(
                                color: theme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Se bloqueada: mostrar progresso
                    if (!achievement.isUnlocked && total > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: theme.primaryBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.alternate.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progresso',
                              style: theme.titleSmall.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '$progress / $total',
                                  style: theme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.primary,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  '${(progressPercent * 100).toInt()}%',
                                  style: theme.bodyMedium.copyWith(
                                    color: theme.secondaryText,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progressPercent,
                                backgroundColor: theme.alternate.withOpacity(0.2),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  theme.primary,
                                ),
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return GestureDetector(
      onTap: () => _model.unfocusNode.canRequestFocus
          ? FocusScope.of(context).requestFocus(_model.unfocusNode)
          : FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.primaryBackground,
        appBar: AppBar(
          backgroundColor: theme.primaryBackground,
          automaticallyImplyLeading: false,
          leading: InkWell(
            onTap: () async {
              context.pop();
            },
            child: Icon(
              Icons.arrow_back_ios,
              color: theme.primaryText,
              size: 24,
            ),
          ),
          title: Text(
            'Conquistas',
            style: theme.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: false,
          elevation: 0,
        ),
        body: SafeArea(
          top: true,
          child: RefreshIndicator(
            onRefresh: _loadAchievements,
            child: _model.isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: theme.primary,
                    ),
                  )
                : _model.errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: theme.error,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _model.errorMessage!,
                              style: theme.bodyMedium.copyWith(
                                color: theme.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FFButtonWidget(
                              onPressed: _loadAchievements,
                              text: 'Tentar Novamente',
                              options: FFButtonOptions(
                                height: 40,
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                    24, 0, 24, 0),
                                iconPadding:
                                    const EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
                                color: theme.primary,
                                textStyle: theme.titleSmall.copyWith(
                                  color: Colors.white,
                                ),
                                elevation: 2,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _model.achievements.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.emoji_events_outlined,
                                  size: 64,
                                  color: theme.secondaryText,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Nenhuma conquista encontrada',
                                  style: theme.titleMedium.copyWith(
                                    color: theme.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.65,
                            ),
                            itemCount: _model.achievements.length,
                            itemBuilder: (context, index) {
                              final achievement = _model.achievements[index];
                              
                              // Calcular progresso
                              int? currentProgress;
                              int? requirementTotal;
                              
                              if (_model.userStats != null) {
                                final minPhotos = achievement.requirement['min_photos'] as int?;
                                final minHighScorePhotos = achievement.requirement['min_high_score_photos'] as int?;
                                
                                if (minPhotos != null) {
                                  currentProgress = _model.userStats!['total_photos'] ?? 0;
                                  requirementTotal = minPhotos;
                                } else if (minHighScorePhotos != null) {
                                  currentProgress = _model.userStats!['high_score_photos'] ?? 0;
                                  requirementTotal = minHighScorePhotos;
                                }
                              }

                              return AchievementCard(
                                achievement: achievement,
                                currentProgress: currentProgress,
                                requirementTotal: requirementTotal,
                                onTap: () => _showAchievementDetails(
                                  context,
                                  achievement,
                                  currentProgress,
                                  requirementTotal,
                                ),
                              );
                            },
                          ),
          ),
        ),
      ),
    );
  }
}

