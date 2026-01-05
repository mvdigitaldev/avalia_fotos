// lib/pages/reports/reports_model.dart
import '/flutter_flow/flutter_flow_util.dart';
import 'reports_widget.dart' show ReportsWidget;
import 'package:flutter/material.dart';
import '../../models/report_model.dart';

class ReportsModel {
  List<ReportModel> reports = [];
  bool isLoading = true;
  String? errorMessage;
  ReportStatus? selectedFilter;
  int pendingCount = 0;

  ReportsModel() {
    selectedFilter = ReportStatus.pending;
  }

  void dispose() {}
}

