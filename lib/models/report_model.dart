// lib/models/report_model.dart
class ReportModel {
  final String id;
  final String userId;
  final String? photoId;
  final String? commentId;
  final ReportType reportType;
  final String reason;
  final String? description;
  final ReportStatus status;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Dados relacionados (para exibição)
  final String? reporterUsername;
  final String? photoImageUrl;
  final String? commentContent;

  ReportModel({
    required this.id,
    required this.userId,
    this.photoId,
    this.commentId,
    required this.reportType,
    required this.reason,
    this.description,
    required this.status,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
    this.reporterUsername,
    this.photoImageUrl,
    this.commentContent,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      photoId: json['photo_id'] as String?,
      commentId: json['comment_id'] as String?,
      reportType: ReportType.fromString(json['report_type'] as String),
      reason: json['reason'] as String,
      description: json['description'] as String?,
      status: ReportStatus.fromString(json['status'] as String),
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      reporterUsername: json['reporter']?['username'] as String?,
      photoImageUrl: json['photo']?['image_url'] as String?,
      commentContent: json['comment']?['content'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'photo_id': photoId,
      'comment_id': commentId,
      'report_type': reportType.value,
      'reason': reason,
      'description': description,
      'status': status.value,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

enum ReportType {
  photo('photo'),
  comment('comment');

  final String value;
  const ReportType(this.value);

  static ReportType fromString(String value) {
    return ReportType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReportType.photo,
    );
  }
}

enum ReportStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  final String value;
  const ReportStatus(this.value);

  static ReportStatus fromString(String value) {
    return ReportStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ReportStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case ReportStatus.pending:
        return 'Pendente';
      case ReportStatus.approved:
        return 'Aprovada';
      case ReportStatus.rejected:
        return 'Rejeitada';
    }
  }
}

// Motivos de denúncia
class ReportReasons {
  static const String spam = 'spam';
  static const String inappropriate = 'inappropriate';
  static const String violence = 'violence';
  static const String hateSpeech = 'hate_speech';
  static const String other = 'other';

  static const Map<String, String> displayNames = {
    spam: 'Spam',
    inappropriate: 'Conteúdo Inadequado',
    violence: 'Violência',
    hateSpeech: 'Discurso de Ódio',
    other: 'Outro',
  };

  static List<String> get all => displayNames.keys.toList();
}



