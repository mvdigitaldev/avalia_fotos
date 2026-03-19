// lib/pages/evaluation_packs_shop/evaluation_packs_shop_model.dart
import '/flutter_flow/flutter_flow_util.dart';
import 'evaluation_packs_shop_widget.dart' show EvaluationPacksShopWidget;
import 'package:flutter/material.dart';
import '../../models/evaluation_pack_model.dart';

class EvaluationPacksShopModel extends FlutterFlowModel<EvaluationPacksShopWidget> {
  List<EvaluationPackModel> packs = [];
  int extraCount = 0;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
