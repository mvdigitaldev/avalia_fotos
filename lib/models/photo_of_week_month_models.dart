import 'photo_of_the_day_model.dart';

export 'photo_of_the_day_model.dart' show PhotoData;

class PhotoOfTheWeekModel {
  final String id;
  final String photoId;
  final DateTime weekStart;
  final String selectedBy;
  final DateTime createdAt;
  final PhotoData? photoData;
  final String? urlImagemSelo;

  PhotoOfTheWeekModel({
    required this.id,
    required this.photoId,
    required this.weekStart,
    required this.selectedBy,
    required this.createdAt,
    this.photoData,
    this.urlImagemSelo,
  });

  factory PhotoOfTheWeekModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? photoDataMap;
    final raw = json['photo_data'];
    if (raw is Map<String, dynamic>) {
      photoDataMap = raw;
    }

    return PhotoOfTheWeekModel(
      id: json['id'] as String,
      photoId: json['photo_id'] as String,
      weekStart: DateTime.parse(json['week_start'] as String),
      selectedBy: json['selected_by']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      photoData:
          photoDataMap != null ? PhotoData.fromJson(photoDataMap) : null,
      urlImagemSelo: json['url_imagem_selo'] as String?,
    );
  }
}

class PhotoOfTheMonthModel {
  final String id;
  final String photoId;
  final DateTime monthStart;
  final String selectedBy;
  final DateTime createdAt;
  final PhotoData? photoData;
  final String? urlImagemSelo;

  PhotoOfTheMonthModel({
    required this.id,
    required this.photoId,
    required this.monthStart,
    required this.selectedBy,
    required this.createdAt,
    this.photoData,
    this.urlImagemSelo,
  });

  factory PhotoOfTheMonthModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? photoDataMap;
    final raw = json['photo_data'];
    if (raw is Map<String, dynamic>) {
      photoDataMap = raw;
    }

    return PhotoOfTheMonthModel(
      id: json['id'] as String,
      photoId: json['photo_id'] as String,
      monthStart: DateTime.parse(json['month_start'] as String),
      selectedBy: json['selected_by']?.toString() ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      photoData:
          photoDataMap != null ? PhotoData.fromJson(photoDataMap) : null,
      urlImagemSelo: json['url_imagem_selo'] as String?,
    );
  }
}
