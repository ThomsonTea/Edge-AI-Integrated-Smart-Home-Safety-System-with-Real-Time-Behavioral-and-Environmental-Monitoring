import 'package:flutter/material.dart';
import '../domain/models/ai_event.dart';
import '../services/event_service.dart';
import '../services/notification_websocket_service.dart';
import '../services/token_service.dart';

class DashboardViewModel extends ChangeNotifier {
  final EventService _eventService = EventService();
  final TokenService _tokenService = TokenService();

  List<AiEvent> _alerts = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _jwtToken;

  List<AiEvent> get alerts => _alerts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get jwtToken => _jwtToken;

  Future<void> initializeDashboard() async {
    _jwtToken = await _tokenService.getToken();
    notifyListeners();
    await loadAlerts();
  }

  Future<void> loadAlerts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _alerts = await _eventService.fetchEvents();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await NotificationWebSocketService.instance.stop();
    await _tokenService.deleteToken();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
