// lib/pages/photo_detail/photo_detail_model.dart
import '/flutter_flow/flutter_flow_util.dart';
import 'photo_detail_widget.dart' show PhotoDetailWidget;
import 'package:flutter/material.dart';
import '../../models/photo_model.dart';
import '../../models/comment_model.dart';

class PhotoDetailModel extends FlutterFlowModel<PhotoDetailWidget> {
  /// Estado da página de detalhes
  PhotoModel? photo;
  List<CommentModel> comments = [];
  bool isLoading = true;
  bool isSubmittingComment = false;
  String? errorMessage;
  
  // Controller para campo de comentário
  TextEditingController? commentController;
  FocusNode? commentFocusNode;

  @override
  void initState(BuildContext context) {
    commentController = TextEditingController();
    commentFocusNode = FocusNode();
  }

  @override
  void dispose() {
    commentController?.dispose();
    commentFocusNode?.dispose();
  }
}

