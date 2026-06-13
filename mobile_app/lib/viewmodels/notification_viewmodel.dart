import 'package:flutter/material.dart';

import '../domain/models/ai_event.dart';
import '../services/event_service.dart';

class NotificationViewModel extends ChangeNotifier {
  final EventService _eventService;

  NotificationViewModel({EventService? eventService})
    : _eventService = eventService ?? EventService();

  List<AiEvent> _events = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AiEvent> get events => _events;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadNotifications() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _events = await _eventService.fetchEvents(limit: 100);
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error loading notifications: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshNotifications() {
    return loadNotifications();
  }
}
