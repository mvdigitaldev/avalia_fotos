class RankingItemModel {
  final String userId;
  final String? username;
  final String? avatarUrl;
  final double score;
  final int photosCount;
  final int position;

  RankingItemModel({
    required this.userId,
    this.username,
    this.avatarUrl,
    required this.score,
    required this.photosCount,
    required this.position,
  });

  factory RankingItemModel.fromJson(Map<String, dynamic> json, int position) {
    return RankingItemModel(
      userId: json['user_id'] as String,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      score: (json['score'] ?? 0).toDouble(),
      photosCount: json['photos_count'] ?? 0,
      position: position,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'username': username,
      'avatar_url': avatarUrl,
      'score': score,
      'photos_count': photosCount,
      'position': position,
    };
  }
}

