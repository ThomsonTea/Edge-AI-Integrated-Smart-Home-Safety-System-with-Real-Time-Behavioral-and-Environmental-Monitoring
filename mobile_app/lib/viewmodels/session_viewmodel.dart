import 'package:flutter/material.dart';

import '../services/notification_websocket_service.dart';
import '../services/token_service.dart';

class SessionViewModel extends ChangeNotifier {
  final NotificationWebSocketService _notificationWebSocketService;
  final TokenService _tokenService;
  bool _isAuthExpired = false;
  String? _currentUserRole;

  SessionViewModel({
    NotificationWebSocketService? notificationWebSocketService,
    TokenService? tokenService,
  }) : _notificationWebSocketService =
           notificationWebSocketService ??
           NotificationWebSocketService.instance,
       _tokenService = tokenService ?? TokenService();

  bool get isAuthExpired => _isAuthExpired;
  String? get currentUserRole => _currentUserRole;
  bool get canManageUsers =>
      _currentUserRole == 'owner' || _currentUserRole == 'manager';

  Future<void> startSession() async {
    _isAuthExpired = false;
    _currentUserRole = _normalizeRole(await _tokenService.getCurrentUserRole());
    _notificationWebSocketService.setAuthFailureHandler(_handleAuthFailure);
    await _notificationWebSocketService.start();
    notifyListeners();
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

  String? _normalizeRole(String? role) {
    final value = role?.trim().toLowerCase().replaceAll('-', '_');
    if (value == null || value.isEmpty) return null;

    return switch (value) {
      'owner' || 'admin' || 'administrator' => 'owner',
      'manager' || 'operator' => 'manager',
      'normal_user' ||
      'normal user' ||
      'member' ||
      'guest' ||
      'resident' => 'normal_user',
      _ => value,
    };
  }
}
