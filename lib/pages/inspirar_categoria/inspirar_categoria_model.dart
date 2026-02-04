// lib/pages/inspirar_categoria/inspirar_categoria_model.dart
import '/flutter_flow/flutter_flow_util.dart';
import 'inspirar_categoria_widget.dart' show InspirarCategoriaWidget;
import 'package:flutter/material.dart';
import '../../models/photo_model.dart';

class InspirarCategoriaModel extends FlutterFlowModel<InspirarCategoriaWidget> {
  List<PhotoModel> photos = [];
  bool isLoading = false;
  bool hasMore = true;
  int currentPage = 0;
  final int pageSize = 20;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
