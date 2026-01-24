// lib/pages/checkout_webview/checkout_webview_model.dart
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'checkout_webview_widget.dart' show CheckoutWebViewWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CheckoutWebViewModel extends FlutterFlowModel<CheckoutWebViewWidget> {
  /// Estado da página de checkout WebView
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
