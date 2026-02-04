// lib/pages/admin/admin_manage_users_model.dart
import '/flutter_flow/flutter_flow_util.dart';
import 'admin_manage_users_widget.dart' show AdminManageUsersWidget;
import 'package:flutter/material.dart';

class AdminManageUsersModel extends FlutterFlowModel<AdminManageUsersWidget> {
  String searchQuery = '';
  List<Map<String, dynamic>> searchResults = [];
  Map<String, dynamic>? selectedUser;
  bool isLoading = false;
  bool isSaving = false;
  List<Map<String, dynamic>> plans = [];

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
