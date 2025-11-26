import '/components/opcoes_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'feed_widget.dart' show FeedWidget;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/photo_model.dart';

class FeedModel extends FlutterFlowModel<FeedWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for opcoes component.
  late OpcoesModel opcoesModel;
  
  // Estado do feed
  List<PhotoModel> photos = [];
  bool isLoading = false;
  bool hasMore = true;
  int currentPage = 0;
  final int pageSize = 20;

  @override
  void initState(BuildContext context) {
    opcoesModel = createModel(context, () => OpcoesModel());
  }

  @override
  void dispose() {
    opcoesModel.dispose();
  }
}
