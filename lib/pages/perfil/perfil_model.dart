// lib/pages/perfil/perfil_model.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'perfil_widget.dart' show PerfilWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class PerfilModel extends FlutterFlowModel<PerfilWidget> {
  /// State fields for stateful widgets in this page.
  String? username;
  String? email;
  String? avatarUrl;
  DateTime? accountCreatedAt;
  int totalPhotosEvaluated = 0;
  String planName = 'Sem plano';
  DateTime? planExpiresAt;
  bool isFreePlan = false;
  bool habilitarPlanos = false;
  
  bool isLoading = true;
  bool isUpdatingAvatar = false;
  bool isUpdatingUsername = false;
  bool isDeletingAccount = false;
  String? errorMessage;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}

