class NotificationModel {
  final String id;
  final String userId;
  final String actorId;
  final String type;
  final String resourceId;
  final String? commentId;
  final bool isRead;
  final DateTime createdAt;
  
  // Dados extras (joins)
  final String? actorUsername;
  final String? actorAvatarUrl;
  final String? photoThumbnailUrl;
  final String? commentText;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.actorId,
    required this.type,
    required this.resourceId,
    this.commentId,
    required this.isRead,
    required this.createdAt,
    this.actorUsername,
    this.actorAvatarUrl,
    this.photoThumbnailUrl,
    this.commentText,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      userId: json['user_id'],
      actorId: json['actor_id'],
      type: json['type'],
      resourceId: json['resource_id'],
      commentId: json['comment_id'],
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      actorUsername: json['actor']?['username'],
      actorAvatarUrl: json['actor']?['avatar_url'],
      photoThumbnailUrl: json['photo']?['thumbnail_url'] ?? json['photo']?['image_url'],
      commentText: json['comment_details']?['content'],
    );
  }
}
