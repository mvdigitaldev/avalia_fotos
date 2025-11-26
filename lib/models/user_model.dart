class UserModel {
  final String id;
  final String? username;
  final String? email;
  final String? avatarUrl;
  final double totalScore;
  final double monthlyScore;
  final int photosCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    this.username,
    this.email,
    this.avatarUrl,
    required this.totalScore,
    required this.monthlyScore,
    required this.photosCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      totalScore: (json['total_score'] ?? 0).toDouble(),
      monthlyScore: (json['monthly_score'] ?? 0).toDouble(),
      photosCount: json['photos_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar_url': avatarUrl,
      'total_score': totalScore,
      'monthly_score': monthlyScore,
      'photos_count': photosCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? username,
    String? email,
    String? avatarUrl,
    double? totalScore,
    double? monthlyScore,
    int? photosCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      totalScore: totalScore ?? this.totalScore,
      monthlyScore: monthlyScore ?? this.monthlyScore,
      photosCount: photosCount ?? this.photosCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

