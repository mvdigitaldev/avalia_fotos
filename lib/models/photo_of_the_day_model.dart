class PhotoOfTheDayModel {
  final String id;
  final String photoId;
  final DateTime selectedDate;
  final String selectedBy;
  final DateTime createdAt;
  final PhotoData? photoData;

  PhotoOfTheDayModel({
    required this.id,
    required this.photoId,
    required this.selectedDate,
    required this.selectedBy,
    required this.createdAt,
    this.photoData,
  });

  factory PhotoOfTheDayModel.fromJson(Map<String, dynamic> json) {
    // A função RPC retorna photo_data como JSONB, então precisamos parsear
    Map<String, dynamic>? photoDataMap;
    if (json['photo_data'] != null) {
      if (json['photo_data'] is Map) {
        photoDataMap = json['photo_data'] as Map<String, dynamic>;
      } else if (json['photo_data'] is String) {
        // Se vier como string JSON, fazer parse
        try {
          // photo_data já vem como objeto do Supabase
          photoDataMap = json['photo_data'] as Map<String, dynamic>?;
        } catch (e) {
          // Ignorar se não conseguir fazer parse
        }
      }
    }

    return PhotoOfTheDayModel(
      id: json['id'] as String,
      photoId: json['photo_id'] as String,
      selectedDate: DateTime.parse(json['selected_date'] as String),
      selectedBy: json['selected_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      photoData: photoDataMap != null
          ? PhotoData.fromJson(photoDataMap)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'photo_id': photoId,
      'selected_date': selectedDate.toIso8601String().split('T')[0],
      'selected_by': selectedBy,
      'created_at': createdAt.toIso8601String(),
      'photo_data': photoData?.toJson(),
    };
  }
}

class PhotoData {
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

  PhotoData({
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
  });

  factory PhotoData.fromJson(Map<String, dynamic> json) {
    return PhotoData(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      imageUrl: json['image_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      score: json['score'] is String
          ? double.tryParse(json['score'] as String) ?? 0.0
          : (json['score'] ?? 0).toDouble(),
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
      recado: json['recado'] as String?,
      isShared: json['is_shared'] ?? false,
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      username: json['username'] as String?,
      userAvatarUrl: json['user_avatar_url'] as String?,
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
      'username': username,
      'user_avatar_url': userAvatarUrl,
    };
  }
}

