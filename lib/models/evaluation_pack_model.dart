// lib/models/evaluation_pack_model.dart

class EvaluationPackModel {
  final String id;
  final String name;
  final int evaluationsCount;
  final double price;
  final String? linkCheckout;
  final bool isPopular;
  final bool hasSavings;
  final int sortOrder;

  EvaluationPackModel({
    required this.id,
    required this.name,
    required this.evaluationsCount,
    required this.price,
    this.linkCheckout,
    this.isPopular = false,
    this.hasSavings = false,
    this.sortOrder = 0,
  });

  factory EvaluationPackModel.fromJson(Map<String, dynamic> json) {
    return EvaluationPackModel(
      id: json['id'] as String,
      name: json['name'] as String,
      evaluationsCount: json['evaluations_count'] as int,
      price: (json['price'] as num).toDouble(),
      linkCheckout: json['link_checkout'] as String?,
      isPopular: json['is_popular'] as bool? ?? false,
      hasSavings: json['has_savings'] as bool? ?? false,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  String get formattedPrice => 'R\$ ${price.toStringAsFixed(2).replaceAll('.', ',')}';

  /// Preço por avaliação (hack psicológico de conversão)
  String get pricePerUnit {
    if (evaluationsCount <= 0) return '';
    final perUnit = price / evaluationsCount;
    return '~R\$ ${perUnit.toStringAsFixed(2).replaceAll('.', ',')} por avaliação';
  }
}
