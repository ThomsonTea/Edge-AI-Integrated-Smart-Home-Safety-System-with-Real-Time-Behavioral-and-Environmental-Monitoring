import 'package:flutter/material.dart';

import '../domain/models/ai_event.dart';
import '../services/event_service.dart';
import '../services/token_service.dart';

class EventDetailViewModel extends ChangeNotifier {
  final EventService _eventService;
  final TokenService _tokenService;

  EventDetailViewModel({EventService? eventService, TokenService? tokenService})
    : _eventService = eventService ?? EventService(),
      _tokenService = tokenService ?? TokenService();

  AiEvent? _event;
  bool _isLoading = false;
  bool _isAcknowledging = false;
  bool _isPinning = false;
  bool _canManageEvent = false;
  String? _errorMessage;

  AiEvent? get event => _event;
  bool get isLoading => _isLoading;
  bool get isAcknowledging => _isAcknowledging;
  bool get isPinning => _isPinning;
  bool get canManageEvent => _canManageEvent;
  String? get errorMessage => _errorMessage;

  Future<void> loadEvent({required int id}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final role = (await _tokenService.getCurrentUserRole())
          ?.trim()
          .toLowerCase();
      _canManageEvent =
          role == 'owner' ||
          role == 'manager' ||
          role == 'admin' ||
          role == 'administrator' ||
          role == 'operator';
      _event = await _eventService.fetchEventById(id);
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error loading event detail: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> togglePin() async {
    final current = _event;
    if (current == null || !_canManageEvent || _isPinning) return;
    _isPinning = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _event = await _eventService.setEventPinned(
        current.id,
        isPinned: !current.isPinned,
      );
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error changing event detail pin: $error');
    } finally {
      _isPinning = false;
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
