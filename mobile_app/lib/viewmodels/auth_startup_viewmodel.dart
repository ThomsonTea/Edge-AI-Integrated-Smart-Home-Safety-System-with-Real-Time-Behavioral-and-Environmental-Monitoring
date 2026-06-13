import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/token_service.dart';

enum AuthStartupState { checking, authenticated, unauthenticated }

class AuthStartupViewModel extends ChangeNotifier {
  final AuthService _authService;
  final TokenService _tokenService;

  AuthStartupViewModel({AuthService? authService, TokenService? tokenService})
    : _authService = authService ?? AuthService(),
      _tokenService = tokenService ?? TokenService();

  AuthStartupState _state = AuthStartupState.checking;

  AuthStartupState get state => _state;

  Future<void> checkSession() async {
    _state = AuthStartupState.checking;
    notifyListeners();

    try {
      await _authService.verifyMe();
      _state = AuthStartupState.authenticated;
    } catch (_) {
      await _tokenService.deleteToken();
      _state = AuthStartupState.unauthenticated;
    }

    notifyListeners();
  }
}
