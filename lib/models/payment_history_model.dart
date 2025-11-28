// lib/models/payment_history_model.dart
class PaymentHistoryModel {
  final String id;
  final String userId;
  final String planId;
  final String planName;
  final double amount;
  final String paymentStatus;
  final String paymentMethod;
  final String? transactionId;
  final DateTime? paymentDate;
  final DateTime expiresAt;
  final String? paymentGateway;
  final String? invoiceUrl;
  final Map<String, dynamic>? metadata;
  final String? description;
  final String currency;
  final DateTime? refundedAt;
  final String? refundReason;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentHistoryModel({
    required this.id,
    required this.userId,
    required this.planId,
    required this.planName,
    required this.amount,
    required this.paymentStatus,
    required this.paymentMethod,
    this.transactionId,
    this.paymentDate,
    required this.expiresAt,
    this.paymentGateway,
    this.invoiceUrl,
    this.metadata,
    this.description,
    this.currency = 'BRL',
    this.refundedAt,
    this.refundReason,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentHistoryModel.fromJson(Map<String, dynamic> json) {
    final planData = json['plans'];
    String planName = 'Plano desconhecido';
    
    if (planData is Map<String, dynamic>) {
      planName = planData['name'] as String? ?? 'Plano desconhecido';
    } else if (planData is List && planData.isNotEmpty) {
      planName = (planData[0] as Map<String, dynamic>)['name'] as String? ?? 'Plano desconhecido';
    }

    return PaymentHistoryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      planId: json['plan_id'] as String,
      planName: planName,
      amount: (json['amount'] as num).toDouble(),
      paymentStatus: json['payment_status'] as String,
      paymentMethod: json['payment_method'] as String,
      transactionId: json['transaction_id'] as String?,
      paymentDate: json['payment_date'] != null
          ? DateTime.parse(json['payment_date'] as String)
          : null,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      paymentGateway: json['payment_gateway'] as String?,
      invoiceUrl: json['invoice_url'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      description: json['description'] as String?,
      currency: json['currency'] as String? ?? 'BRL',
      refundedAt: json['refunded_at'] != null
          ? DateTime.parse(json['refunded_at'] as String)
          : null,
      refundReason: json['refund_reason'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  String get statusLabel {
    switch (paymentStatus) {
      case 'paid':
        return 'Pago';
      case 'pending':
        return 'Pendente';
      case 'cancelled':
        return 'Cancelado';
      case 'refunded':
        return 'Reembolsado';
      case 'failed':
        return 'Falhou';
      default:
        return paymentStatus;
    }
  }

  String get methodLabel {
    switch (paymentMethod) {
      case 'credit_card':
        return 'Cartão de Crédito';
      case 'debit_card':
        return 'Cartão de Débito';
      case 'pix':
        return 'PIX';
      case 'boleto':
        return 'Boleto';
      case 'bank_transfer':
        return 'Transferência Bancária';
      default:
        return paymentMethod;
    }
  }

  bool get isPaid => paymentStatus == 'paid';
  bool get isPending => paymentStatus == 'pending';
  bool get isRefunded => paymentStatus == 'refunded';
  bool get isFailed => paymentStatus == 'failed';
}

