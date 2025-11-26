import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/photo_model.dart';

enum AvaliaState {
  initial,
  imageSelected,
  uploading,
  evaluating,
  completed,
  error,
}

class AvaliaStateManager extends ChangeNotifier {
  AvaliaState _state = AvaliaState.initial;
  File? _selectedImage;
  PhotoModel? _evaluatedPhoto;
  String? _errorMessage;

  AvaliaState get state => _state;
  File? get selectedImage => _selectedImage;
  PhotoModel? get evaluatedPhoto => _evaluatedPhoto;
  String? get errorMessage => _errorMessage;

  void selectImage(File image) {
    _selectedImage = image;
    _state = AvaliaState.imageSelected;
    _errorMessage = null;
    notifyListeners();
  }

  void startUpload() {
    _state = AvaliaState.uploading;
    _errorMessage = null;
    notifyListeners();
  }

  void startEvaluation() {
    _state = AvaliaState.evaluating;
    _errorMessage = null;
    notifyListeners();
  }

  void completeEvaluation(PhotoModel photo) {
    _evaluatedPhoto = photo;
    _state = AvaliaState.completed;
    _errorMessage = null;
    notifyListeners();
  }

  void setError(String error) {
    _errorMessage = error;
    _state = AvaliaState.error;
    notifyListeners();
  }

  void reset() {
    _state = AvaliaState.initial;
    _selectedImage = null;
    _evaluatedPhoto = null;
    _errorMessage = null;
    notifyListeners();
  }
}

