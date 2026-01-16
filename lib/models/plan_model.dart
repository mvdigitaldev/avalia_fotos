// lib/models/plan_model.dart
import 'dart:io';

class PlanModel {
  final String id;
  final String name;
  final int? monthlyEvaluationsLimit; // null = ilimitado
  final int? storageLimit; // null = ilimitado
  final double? price; // null = grátis
  final String? linkPlan; // Link para página de compra do plano
  final String? appleProductId; // Product ID do App Store Connect
  final String? googleProductId; // Product ID do Google Play Console
  final int? durationMonths; // null = sem duração fixa (free), 3 = trimestral, 6 = semestral

  PlanModel({
    required this.id,
    required this.name,
    this.monthlyEvaluationsLimit,
    this.storageLimit,
    this.price,
    this.linkPlan,
    this.appleProductId,
    this.googleProductId,
    this.durationMonths,
  });

  factory PlanModel.fromJson(Map<String, dynamic> json) {
    return PlanModel(
      id: json['id'] as String,
      name: json['name'] as String,
      monthlyEvaluationsLimit: json['monthly_evaluations_limit'] as int?,
      storageLimit: json['storage_limit'] as int?,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      linkPlan: json['link_plan'] as String?,
      appleProductId: json['apple_product_id'] as String?,
      googleProductId: json['google_product_id'] as String?,
      durationMonths: json['duration_months'] as int?,
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
      'apple_product_id': appleProductId,
      'google_product_id': googleProductId,
      'duration_months': durationMonths,
    };
  }

  bool get isUnlimitedEvaluations => monthlyEvaluationsLimit == null;
  bool get isUnlimitedStorage => storageLimit == null;
  bool get isFree => price == null;

  /// Retorna o Product ID apropriado baseado na plataforma atual
  String? getProductIdForPlatform() {
    if (Platform.isIOS) {
      return appleProductId;
    } else if (Platform.isAndroid) {
      return googleProductId;
    }
    return null;
  }

  /// Verifica se há Product ID disponível para a plataforma atual
  bool hasProductIdForCurrentPlatform() {
    return getProductIdForPlatform() != null && getProductIdForPlatform()!.isNotEmpty;
  }

  /// Retorna a duração do plano em texto formatado
  String get durationText {
    if (durationMonths == null) return 'Sem duração fixa';
    if (durationMonths == 3) return 'Trimestral (3 meses)';
    if (durationMonths == 6) return 'Semestral (6 meses)';
    return '$durationMonths meses';
  }

  /// Verifica se é um plano trimestral
  bool get isQuarterly => durationMonths == 3;

  /// Verifica se é um plano semestral
  bool get isSemiannual => durationMonths == 6;
}

