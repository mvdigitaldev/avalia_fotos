// lib/models/comment_model.dart
class CommentModel {
  final String id;
  final String photoId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final String? username;
  final String? userAvatarUrl;

  CommentModel({
    required this.id,
    required this.photoId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.username,
    this.userAvatarUrl,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    // Extrair dados do usuário se vier do join
    Map<String, dynamic>? userData;
    if (json['users'] != null) {
      if (json['users'] is Map) {
        userData = json['users'] as Map<String, dynamic>;
      } else if (json['users'] is List && (json['users'] as List).isNotEmpty) {
        userData = (json['users'] as List).first as Map<String, dynamic>;
      }
    }

    return CommentModel(
      id: json['id'] as String,
      photoId: json['photo_id'] as String,
      userId: json['user_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      username: userData?['username'] as String?,
      userAvatarUrl: userData?['avatar_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'photo_id': photoId,
      'user_id': userId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

