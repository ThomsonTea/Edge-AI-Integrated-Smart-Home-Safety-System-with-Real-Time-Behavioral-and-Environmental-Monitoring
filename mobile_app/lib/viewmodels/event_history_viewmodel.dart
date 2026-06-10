import 'package:flutter/material.dart';

import '../domain/models/ai_event.dart';
import '../services/event_service.dart';

class EventHistoryViewModel extends ChangeNotifier {
  final EventService _eventService;

  EventHistoryViewModel({EventService? eventService})
    : _eventService = eventService ?? EventService();

  List<AiEvent> _events = const [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _errorMessage;

  int _limit = 50;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedEventType;
  bool? _selectedAcknowledgementStatus;

  List<AiEvent> get events => _events;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  String? get errorMessage => _errorMessage;
  bool get hasEvents => _events.isNotEmpty;
  String? get selectedEventType => _selectedEventType;
  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;
  bool? get selectedAcknowledgementStatus => _selectedAcknowledgementStatus;

  Future<void> loadEvents({
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
    String? eventType,
    bool? isAcknowledged,
  }) async {
    _limit = limit;
    _startDate = startDate;
    _endDate = endDate;
    _selectedEventType = eventType;
    _selectedAcknowledgementStatus = isAcknowledged;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _events = await _fetchEvents();
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error loading events: $error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> applyFilters({
    String? eventType,
    DateTime? startDate,
    DateTime? endDate,
    bool? acknowledgementStatus,
  }) {
    return loadEvents(
      limit: _limit,
      eventType: eventType,
      startDate: startDate,
      endDate: endDate,
      isAcknowledged: acknowledgementStatus,
    );
  }

  Future<void> clearFilters() {
    return loadEvents(limit: _limit);
  }

  Future<void> refreshEvents() async {
    _isRefreshing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _events = await _fetchEvents();
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error refreshing events: $error');
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> acknowledgeEvent(int id) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final acknowledgedEvent = await _eventService.acknowledgeEvent(id);
      _events = _events
          .map((event) => event.id == id ? acknowledgedEvent : event)
          .toList();
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error acknowledging event: $error');
    } finally {
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<List<AiEvent>> _fetchEvents() {
    return _eventService.fetchEventsWithFilters(
      limit: _limit,
      startDate: _startDate,
      endDate: _endDate,
      eventType: _selectedEventType,
      isAcknowledged: _selectedAcknowledgementStatus,
    );
  }
}
