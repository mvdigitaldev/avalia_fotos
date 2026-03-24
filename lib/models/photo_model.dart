class PhotoModel {
  final String id;
  final String userId;
  final String imageUrl;
  final String? thumbnailUrl;
  final double score;
  final List<String> positivePoints;
  final List<String> improvementPoints;
  final String? observacao;
  final String? categoria;
  final String? recado;
  final bool isShared;
  final int likesCount;
  final int commentsCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? username;
  final String? userAvatarUrl;
  final bool? isLiked;
  final bool? hasPaidPlan;
  /// Preenchido pela query do feed (view feed_photos); evita N queries de "foto do dia".
  final bool? isPhotoOfTheDay;
  final bool? isPhotoOfTheWeek;
  final bool? isPhotoOfTheMonth;

  PhotoModel({
    required this.id,
    required this.userId,
    required this.imageUrl,
    this.thumbnailUrl,
    required this.score,
    required this.positivePoints,
    required this.improvementPoints,
    this.observacao,
    this.categoria,
    this.recado,
    required this.isShared,
    required this.likesCount,
    required this.commentsCount,
    required this.createdAt,
    required this.updatedAt,
    this.username,
    this.userAvatarUrl,
    this.isLiked,
    this.hasPaidPlan,
    this.isPhotoOfTheDay,
    this.isPhotoOfTheWeek,
    this.isPhotoOfTheMonth,
  });

  factory PhotoModel.fromJson(Map<String, dynamic> json) {
    // Extrair dados do usuário se vier do join
    Map<String, dynamic>? userData;
    if (json['users'] != null) {
      if (json['users'] is Map) {
        userData = json['users'] as Map<String, dynamic>;
      } else if (json['users'] is List && (json['users'] as List).isNotEmpty) {
        userData = (json['users'] as List).first as Map<String, dynamic>;
      }
    }

    // Parsing seguro de datas (evita Null is not a subtype quando colunas ausentes no feed)
    DateTime parseDateTime(dynamic v, DateTime fallback) {
      if (v == null) return fallback;
      if (v is String) return DateTime.tryParse(v) ?? fallback;
      return fallback;
    }

    return PhotoModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String?,
      score: json['score'] is String
          ? double.tryParse(json['score'] as String) ?? 0.0
          : (json['score'] != null ? (json['score'] as num).toDouble() : 0.0),
      positivePoints: (json['positive_points'] is List)
          ? (json['positive_points'] as List<dynamic>).map((e) => e.toString()).toList()
          : [],
      improvementPoints: (json['improvement_points'] is List)
          ? (json['improvement_points'] as List<dynamic>).map((e) => e.toString()).toList()
          : [],
      observacao: json['observacao'] as String?,
      categoria: json['categoria'] as String?,
      recado: json['recado'] as String?,
      isShared: json['is_shared'] == true,
      likesCount: (json['likes_count'] is int) ? json['likes_count'] as int : int.tryParse('${json['likes_count']}') ?? 0,
      commentsCount: (json['comments_count'] is int) ? json['comments_count'] as int : int.tryParse('${json['comments_count']}') ?? 0,
      createdAt: parseDateTime(json['created_at'], DateTime.now()),
      updatedAt: parseDateTime(json['updated_at'], DateTime.now()),
      username: userData?['username'] as String? ?? json['username'] as String?,
      userAvatarUrl: userData?['avatar_url'] as String? ?? json['user_avatar_url'] as String?,
      isLiked: json['is_liked'] as bool?,
      hasPaidPlan: json['has_paid_plan'] as bool?,
      isPhotoOfTheDay: json['is_photo_of_the_day'] as bool?,
      isPhotoOfTheWeek: json['is_photo_of_the_week'] as bool?,
      isPhotoOfTheMonth: json['is_photo_of_the_month'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'image_url': imageUrl,
      'thumbnail_url': thumbnailUrl,
      'score': score,
      'positive_points': positivePoints,
      'improvement_points': improvementPoints,
      'observacao': observacao,
      'categoria': categoria,
      'recado': recado,
      'is_shared': isShared,
      'likes_count': likesCount,
      'comments_count': commentsCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PhotoModel copyWith({
    String? id,
    String? userId,
    String? imageUrl,
    String? thumbnailUrl,
    double? score,
    List<String>? positivePoints,
    List<String>? improvementPoints,
    String? observacao,
    String? categoria,
    String? recado,
    bool? isShared,
    int? likesCount,
    int? commentsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? username,
    String? userAvatarUrl,
    bool? isLiked,
    bool? hasPaidPlan,
    bool? isPhotoOfTheDay,
    bool? isPhotoOfTheWeek,
    bool? isPhotoOfTheMonth,
  }) {
    return PhotoModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      imageUrl: imageUrl ?? this.imageUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      score: score ?? this.score,
      positivePoints: positivePoints ?? this.positivePoints,
      improvementPoints: improvementPoints ?? this.improvementPoints,
      observacao: observacao ?? this.observacao,
      categoria: categoria ?? this.categoria,
      recado: recado ?? this.recado,
      isShared: isShared ?? this.isShared,
      likesCount: likesCount ?? this.likesCount,
      commentsCount: commentsCount ?? this.commentsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      username: username ?? this.username,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      isLiked: isLiked ?? this.isLiked,
      hasPaidPlan: hasPaidPlan ?? this.hasPaidPlan,
      isPhotoOfTheDay: isPhotoOfTheDay ?? this.isPhotoOfTheDay,
      isPhotoOfTheWeek: isPhotoOfTheWeek ?? this.isPhotoOfTheWeek,
      isPhotoOfTheMonth: isPhotoOfTheMonth ?? this.isPhotoOfTheMonth,
    );
  }
}

