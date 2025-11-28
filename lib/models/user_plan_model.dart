// lib/models/user_plan_model.dart
import 'plan_model.dart';

class UserPlanModel {
  final String id;
  final String userId;
  final PlanModel plan;
  final DateTime startedAt;
  final DateTime? expiresAt;
  final bool isActive;

  UserPlanModel({
    required this.id,
    required this.userId,
    required this.plan,
    required this.startedAt,
    this.expiresAt,
    required this.isActive,
  });

  factory UserPlanModel.fromJson(Map<String, dynamic> json) {
    return UserPlanModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      plan: PlanModel.fromJson(json['plans'] as Map<String, dynamic>),
      startedAt: DateTime.parse(json['started_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'plan': plan.toJson(),
      'started_at': startedAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'is_active': isActive,
    };
  }
}

