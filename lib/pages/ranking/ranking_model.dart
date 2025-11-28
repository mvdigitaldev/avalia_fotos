import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'ranking_widget.dart' show RankingWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/ranking_item_model.dart';
import '../../models/photo_model.dart';

class RankingModel extends FlutterFlowModel<RankingWidget> {
  List<RankingItemModel> users = [];
  List<PhotoModel> photos = [];
  
  bool isLoadingUsers = false;
  bool isLoadingPhotos = false;
  
  bool hasMoreUsers = true;
  bool hasMorePhotos = true;
  
  int currentUsersPage = 0;
  int currentPhotosPage = 0;
  
  DateTime selectedMonth = DateTime.now();
  bool isHistoricalView = false;
  
  String? errorMessage;

  @override
  void initState(BuildContext context) {
    selectedMonth = DateTime.now();
  }

  @override
  void dispose() {}
}
