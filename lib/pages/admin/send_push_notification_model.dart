// lib/pages/admin/send_push_notification_model.dart
import 'package:flutter/material.dart';
import '/flutter_flow/flutter_flow_util.dart';

class SendPushNotificationModel extends FlutterFlowModel {
  ///  State fields for stateful widgets in this page.
  
  // State field(s) for TextField widget.
  FocusNode? titleFocusNode;
  TextEditingController? titleController;
  String? Function(String?)? titleControllerValidator;
  
  // State field(s) for TextField widget.
  FocusNode? contentFocusNode;
  TextEditingController? contentController;
  String? Function(String?)? contentControllerValidator;
  
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    titleFocusNode?.dispose();
    titleController?.dispose();
    
    contentFocusNode?.dispose();
    contentController?.dispose();
  }
}

