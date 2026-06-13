import 'package:flutter/material.dart';

import '../services/notification_websocket_service.dart';
import '../services/token_service.dart';

class SessionViewModel extends ChangeNotifier {
  final NotificationWebSocketService _notificationWebSocketService;
  final TokenService _tokenService;

  SessionViewModel({
    NotificationWebSocketService? notificationWebSocketService,
    TokenService? tokenService,
  }) : _notificationWebSocketService =
           notificationWebSocketService ??
           NotificationWebSocketService.instance,
       _tokenService = tokenService ?? TokenService();

  Future<void> startSession() {
    return _notificationWebSocketService.start();
  }

  void disposeSession() {
    _notificationWebSocketService.stop();
  }

  Future<void> logout() async {
    await _notificationWebSocketService.stop();
    await _tokenService.deleteToken();
  }
}
