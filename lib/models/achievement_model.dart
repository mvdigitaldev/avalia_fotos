import 'dart:convert';

class AchievementModel {
  final String id;
  final String title;
  final String description;
  final String img; // SVG como string
  final Map<String, dynamic> requirement; // {"min_photos": 10} ou {"min_high_score_photos": 1}
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isUnlocked; // Calculado comparando com user_achievements
  final DateTime? unlockedAt; // Quando foi desbloqueada

  AchievementModel({
    required this.id,
    required this.title,
    required this.description,
    required this.img,
    required this.requirement,
    required this.createdAt,
    this.updatedAt,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  factory AchievementModel.fromJson(
    Map<String, dynamic> json, {
    Set<String>? unlockedAchievementIds,
    Map<String, DateTime>? unlockedAtMap,
  }) {
    final achievementId = json['id'] as String;
    final isUnlocked = unlockedAchievementIds?.contains(achievementId) ?? false;
    final unlockedAt = isUnlocked
        ? (unlockedAtMap?[achievementId] ??
            (json['user_achievements'] != null
                ? _parseDateTime(json['user_achievements'], 'unlocked_at')
                : null))
        : null;

    // Parse requirement - pode vir como Map ou String JSON
    Map<String, dynamic> requirementMap;
    final requirementValue = json['requirement'];
    if (requirementValue is Map) {
      requirementMap = requirementValue as Map<String, dynamic>;
    } else if (requirementValue is String) {
      // Se vier como string JSON, fazer parse
      requirementMap = Map<String, dynamic>.from(
        jsonDecode(requirementValue) as Map,
      );
    } else {
      requirementMap = {};
    }

    return AchievementModel(
      id: achievementId,
      title: json['title'] as String,
      description: json['description'] as String,
      img: json['img'] as String,
      requirement: requirementMap,
      createdAt: _parseDateTime(json, 'created_at'),
      updatedAt: _parseDateTimeOptional(json, 'updated_at'),
      isUnlocked: isUnlocked,
      unlockedAt: unlockedAt,
    );
  }

  static DateTime _parseDateTime(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      throw Exception('Campo $key não encontrado');
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        // Tentar parsear como timestamp ISO8601 ou outros formatos
        throw Exception('Erro ao parsear $key: $value');
      }
    }
    throw Exception('Formato inválido para $key: ${value.runtimeType}');
  }
  
  static DateTime? _parseDateTimeOptional(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'img': img,
      'requirement': requirement,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_unlocked': isUnlocked,
      'unlocked_at': unlockedAt?.toIso8601String(),
    };
  }

  AchievementModel copyWith({
    String? id,
    String? title,
    String? description,
    String? img,
    Map<String, dynamic>? requirement,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return AchievementModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      img: img ?? this.img,
      requirement: requirement ?? this.requirement,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  // Helper para obter progresso atual
  int? getProgress(int currentPhotos, int currentHighScorePhotos) {
    final minPhotos = requirement['min_photos'] as int?;
    final minHighScorePhotos = requirement['min_high_score_photos'] as int?;

    if (minPhotos != null) {
      return currentPhotos;
    }
    if (minHighScorePhotos != null) {
      return currentHighScorePhotos;
    }
    return null;
  }

  // Helper para obter requisito total
  int? getRequirementTotal() {
    final minPhotos = requirement['min_photos'] as int?;
    final minHighScorePhotos = requirement['min_high_score_photos'] as int?;

    return minPhotos ?? minHighScorePhotos;
  }
}

