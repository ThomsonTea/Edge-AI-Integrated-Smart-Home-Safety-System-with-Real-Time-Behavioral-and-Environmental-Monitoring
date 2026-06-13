import 'dart:io';

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/token_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthService _authService;
  final TokenService _tokenService;

  LoginViewModel({AuthService? authService, TokenService? tokenService})
    : _authService = authService ?? AuthService(),
      _tokenService = tokenService ?? TokenService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isSuccess = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isSuccess => _isSuccess;

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _isSuccess = false;
    notifyListeners();

    try {
      final result = await _authService.login(
        username: username,
        password: password,
      );

      await _tokenService.saveToken(result.token);

      _isSuccess = true;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> faceLogin({required File imageFile}) async {
    _isLoading = true;
    _errorMessage = null;
    _isSuccess = false;
    notifyListeners();

    try {
      final result = await _authService.faceLogin(imageFile: imageFile);

      await _tokenService.saveToken(result.token);

      _isSuccess = true;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
