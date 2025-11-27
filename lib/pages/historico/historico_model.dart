// lib/pages/historico/historico_model.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'historico_widget.dart' show HistoricoWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/photo_model.dart';

class HistoricoModel extends FlutterFlowModel<HistoricoWidget> {
  /// Estado da página de histórico
  List<PhotoModel> photos = [];
  bool isLoading = false;
  bool hasMore = true;
  int currentPage = 0;
  final int pageSize = 30; // 30 fotos por página
  bool isSelectionMode = false;
  Set<String> selectedPhotoIds = {};
  int totalPhotos = 0;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
