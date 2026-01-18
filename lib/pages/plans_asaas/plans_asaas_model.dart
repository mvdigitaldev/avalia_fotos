// lib/pages/plans_asaas/plans_asaas_model.dart
import '/flutter_flow/flutter_flow_util.dart';
import 'plans_asaas_widget.dart' show PlansAsaasWidget;
import 'package:flutter/material.dart';
import '../../models/plan_model.dart';
import '../../models/user_plan_model.dart';
import '../../models/payment_history_model.dart';

class PlansAsaasModel extends FlutterFlowModel<PlansAsaasWidget> {
  List<PlanModel> availablePlans = [];
  UserPlanModel? currentPlan;
  List<PaymentHistoryModel> paymentHistory = [];
  bool isLoading = true;
  bool isLoadingHistory = false;
  String? errorMessage;
  int selectedTabIndex = 0;
  TabController? tabController;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    tabController?.dispose();
  }
}

