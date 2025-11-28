// lib/models/plan_model.dart
class PlanModel {
  final String id;
  final String name;
  final int? monthlyEvaluationsLimit; // null = ilimitado
  final int? storageLimit; // null = ilimitado
  final double? price; // null = grátis
  final String? linkPlan; // Link para página de compra do plano

  PlanModel({
    required this.id,
    required this.name,
    this.monthlyEvaluationsLimit,
    this.storageLimit,
    this.price,
    this.linkPlan,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'] as String,
      name: json['name'] as String,
      monthlyEvaluationsLimit: json['monthly_evaluations_limit'] as int?,
      storageLimit: json['storage_limit'] as int?,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      linkPlan: json['link_plan'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'monthly_evaluations_limit': monthlyEvaluationsLimit,
      'storage_limit': storageLimit,
      'price': price,
      'link_plan': linkPlan,
    };
  }

  bool get isUnlimitedEvaluations => monthlyEvaluationsLimit == null;
  bool get isUnlimitedStorage => storageLimit == null;
  bool get isFree => price == null;
}

