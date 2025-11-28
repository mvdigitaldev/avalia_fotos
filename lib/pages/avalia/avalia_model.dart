import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:io';
import 'dart:ui';
import 'avalia_widget.dart' show AvaliaWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../models/photo_model.dart';

class AvaliaModel extends FlutterFlowModel<AvaliaWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for Switch widget.
  bool? switchValue;
  
  // Estado da avaliação
  File? selectedImage;
  bool isLoading = false;
  PhotoModel? evaluatedPhoto;
  String? errorMessage;
  
  // Estado de limites
  bool canEvaluate = true;
  String? limitMessage;
  int? monthlyEvaluationsUsed;
  int? monthlyEvaluationsLimit;
  int storageUsed = 0;
  int? storageLimit;

  @override
  void initState(BuildContext context) {
    switchValue = true;
  }

  @override
  void dispose() {}
}
