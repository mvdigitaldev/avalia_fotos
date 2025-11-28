// lib/models/evaluation_limit_model.dart
class EvaluationLimitModel {
  final bool canEvaluate;
  final String? reason;
  final int? monthlyEvaluationsUsed;
  final int? monthlyEvaluationsLimit;
  final int storageUsed;
  final int? storageLimit;

  EvaluationLimitModel({
    required this.canEvaluate,
    this.reason,
    this.monthlyEvaluationsUsed,
    this.monthlyEvaluationsLimit,
    required this.storageUsed,
    this.storageLimit,
  });

  bool get isMonthlyLimitReached {
    if (monthlyEvaluationsLimit == null) return false;
    return monthlyEvaluationsUsed != null &&
        monthlyEvaluationsUsed! >= monthlyEvaluationsLimit!;
  }

  bool get isStorageLimitReached {
    if (storageLimit == null) return false;
    return storageUsed >= storageLimit!;
  }
}

