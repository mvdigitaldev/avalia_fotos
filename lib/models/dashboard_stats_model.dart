// lib/models/dashboard_stats_model.dart
import 'photo_model.dart';

class DashboardStatsModel {
  final int? rankingPosition; // Posição no ranking mensal
  final double monthlyScore; // Pontuação mensal do usuário
  final int monthlyEvaluationsUsed; // Avaliações feitas no mês
  final int? monthlyEvaluationsLimit; // Limite de avaliações do plano
  final double? monthlyAverageScore; // Média das notas do mês
  final PhotoModel? bestPhotoOfMonth; // Melhor foto do mês

  DashboardStatsModel({
    this.rankingPosition,
    required this.monthlyScore,
    required this.monthlyEvaluationsUsed,
    this.monthlyEvaluationsLimit,
    this.monthlyAverageScore,
    this.bestPhotoOfMonth,
  });

  double get monthlyProgressPercentage {
    if (monthlyEvaluationsLimit == null || monthlyEvaluationsLimit == 0) {
      return 0.0;
    }
    return (monthlyEvaluationsUsed / monthlyEvaluationsLimit!).clamp(0.0, 1.0);
  }

  String get rankingPositionText {
    if (rankingPosition == null) return 'Sem posição';
    
    final pos = rankingPosition!;
    if (pos == 1) return '1º lugar';
    if (pos == 2) return '2º lugar';
    if (pos == 3) return '3º lugar';
    return '$posº lugar';
  }
}

