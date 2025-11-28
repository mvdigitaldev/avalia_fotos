import '/flutter_flow/flutter_flow_util.dart';
import 'conquistas_widget.dart' show ConquistasWidget;
import 'package:flutter/material.dart';
import '../../models/achievement_model.dart';

class ConquistasModel extends FlutterFlowModel<ConquistasWidget> {
  ///  State fields for stateful widgets in this page.

  final unfocusNode = FocusNode();
  List<AchievementModel> achievements = [];
  bool isLoading = false;
  String? errorMessage;
  Map<String, int>? userStats; // {total_photos: X, high_score_photos: Y}

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    unfocusNode.dispose();
  }
}

