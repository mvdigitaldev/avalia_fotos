class AnnouncementModel {
  final String id;
  final String title;
  final String description;
  final String? imageUrl;
  final String? link;
  final bool isPinned;
  final DateTime createdAt;
  final String? authorId;
  final String? authorUsername;

  AnnouncementModel({
    required this.id,
    required this.title,
    required this.description,
    this.imageUrl,
    this.link,
    required this.isPinned,
    required this.createdAt,
    this.authorId,
    this.authorUsername,
  });

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    final author = json['author'];
    final String? username = author is Map<String, dynamic>
        ? (author['username'] as String?)
        : null;
    return AnnouncementModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imageUrl: json['image_url'] as String?,
      link: json['link'] as String?,
      isPinned: (json['is_pinned'] as bool?) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      authorId: json['author_id'] as String?,
      authorUsername: username,
    );
  }

  /// Short description for pinned card (e.g. first 100 chars)
  String get descriptionExcerpt {
    if (description.length <= 100) return description;
    return '${description.substring(0, 100)}...';
  }
}
