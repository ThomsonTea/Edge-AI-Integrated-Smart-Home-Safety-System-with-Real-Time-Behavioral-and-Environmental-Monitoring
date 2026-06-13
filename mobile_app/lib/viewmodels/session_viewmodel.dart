import 'package:flutter/material.dart';

import '../services/notification_websocket_service.dart';
import '../services/token_service.dart';

class SessionViewModel extends ChangeNotifier {
  final NotificationWebSocketService _notificationWebSocketService;
  final TokenService _tokenService;
  bool _isAuthExpired = false;

  SessionViewModel({
    NotificationWebSocketService? notificationWebSocketService,
    TokenService? tokenService,
  }) : _notificationWebSocketService =
           notificationWebSocketService ??
           NotificationWebSocketService.instance,
       _tokenService = tokenService ?? TokenService();

  bool get isAuthExpired => _isAuthExpired;

  Future<void> startSession() async {
    _isAuthExpired = false;
    _notificationWebSocketService.setAuthFailureHandler(_handleAuthFailure);
    await _notificationWebSocketService.start();
  }

  void disposeSession() {
    _notificationWebSocketService.setAuthFailureHandler(null);
    _notificationWebSocketService.stop();
  }

  Future<void> logout() async {
    await _notificationWebSocketService.stop();
    await _tokenService.deleteToken();
  }

  Future<void> _handleAuthFailure() async {
    await _tokenService.deleteToken();
    _isAuthExpired = true;
    notifyListeners();
  }
}
