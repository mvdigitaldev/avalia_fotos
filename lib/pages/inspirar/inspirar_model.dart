// lib/pages/inspirar/inspirar_model.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'inspirar_widget.dart' show InspirarWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/photo_model.dart';

class InspirarModel extends FlutterFlowModel<InspirarWidget> {
  /// Estado da página de inspiração
  List<PhotoModel> photos = [];
  bool isLoading = false;
  bool hasMore = true;
  int currentPage = 0;
  final int pageSize = 20; // 20 fotos por página
  
  // Filtros
  DateTime? dateFrom;
  DateTime? dateTo;
  double? minScore;
  String? categoria;
  
  // Categorias disponíveis
  List<String> availableCategories = [];
  bool isLoadingCategories = false;
  
  // Contador de resultados
  int totalResults = 0;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}

