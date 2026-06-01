import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/token_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final TokenService _tokenService = TokenService();

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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
