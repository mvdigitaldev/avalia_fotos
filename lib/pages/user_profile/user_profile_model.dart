// lib/pages/user_profile/user_profile_model.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'user_profile_widget.dart' show UserProfileWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/photo_model.dart';

class UserProfileModel extends FlutterFlowModel<UserProfileWidget> {
  /// Estado da página de perfil
  String? username;
  String? avatarUrl;
  int totalPhotosEvaluated = 0;
  int? rankingPosition;
  double? score;
  String? city;
  String? state;
  String? phone;
  bool hasPaidPlan = false;
  List<PhotoModel> photos = [];
  bool isLoading = false;
  bool isLoadingPhotos = false;
  bool hasMore = true;
  int currentPage = 0;
  final int pageSize = 20;
  String? errorMessage;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
