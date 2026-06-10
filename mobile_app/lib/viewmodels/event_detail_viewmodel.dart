import 'package:flutter/material.dart';

import '../domain/models/ai_event.dart';
import '../services/event_service.dart';

class EventDetailViewModel extends ChangeNotifier {
  final EventService _eventService;

  EventDetailViewModel({EventService? eventService})
    : _eventService = eventService ?? EventService();

  AiEvent? _event;
  bool _isLoading = false;
  bool _isAcknowledging = false;
  String? _errorMessage;

  AiEvent? get event => _event;
  bool get isLoading => _isLoading;
  bool get isAcknowledging => _isAcknowledging;
  String? get errorMessage => _errorMessage;

  Future<void> loadEvent({required int id}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _event = await _eventService.fetchEventById(id);
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error loading event detail: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> acknowledgeEvent() async {
    final currentEvent = _event;
    if (currentEvent == null || currentEvent.isAcknowledged) return;

    _isAcknowledging = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _event = await _eventService.acknowledgeEvent(currentEvent.id);
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error acknowledging event detail: $error');
    } finally {
      _isAcknowledging = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
