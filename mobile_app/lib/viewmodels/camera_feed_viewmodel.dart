import 'package:flutter/material.dart';

import '../services/token_service.dart';

class CameraFeedViewModel extends ChangeNotifier {
  final TokenService _tokenService;

  CameraFeedViewModel({TokenService? tokenService})
    : _tokenService = tokenService ?? TokenService();

  String? _jwtToken;
  bool _isLoading = false;
  String? _errorMessage;

  String? get jwtToken => _jwtToken;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadCameraSession() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _jwtToken = await _tokenService.getToken();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
