// lib/pages/admin/admin_user_photos_model.dart
import '/flutter_flow/flutter_flow_util.dart';
import 'admin_user_photos_widget.dart' show AdminUserPhotosWidget;
import 'package:flutter/material.dart';
import '../../models/photo_model.dart';

class AdminUserPhotosModel extends FlutterFlowModel<AdminUserPhotosWidget> {
  List<PhotoModel> photos = [];
  bool isLoading = false;
  bool hasMore = true;
  int currentPage = 0;
  final int pageSize = 30;
  bool isSelectionMode = false;
  Set<String> selectedPhotoIds = {};
  int totalPhotos = 0;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
