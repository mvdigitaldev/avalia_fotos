class EvaluationResultModel {
  final double score;
  final List<String> positivePoints;
  final List<String> improvementPoints;
  final String? observacao;
  final String? categoria;

  EvaluationResultModel({
    required this.score,
    required this.positivePoints,
    required this.improvementPoints,
    this.observacao,
    this.categoria,
  });

  factory EvaluationResultModel.fromJson(Map<String, dynamic> json) {
    return EvaluationResultModel(
      score: (json['score'] ?? 0).toDouble(),
      positivePoints: (json['positive_points'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      improvementPoints: (json['improvement_points'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      observacao: json['observacao'] as String?,
      categoria: json['categoria'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'positive_points': positivePoints,
      'improvement_points': improvementPoints,
      'observacao': observacao,
      'categoria': categoria,
    };
  }
}

