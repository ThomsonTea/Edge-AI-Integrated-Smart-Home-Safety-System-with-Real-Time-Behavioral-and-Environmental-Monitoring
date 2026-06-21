import 'package:flutter/material.dart';

import '../domain/models/ai_event.dart';
import '../services/event_service.dart';

enum AlertFilter {
  all('All'),
  critical('Critical'),
  unacknowledged('Unacknowledged'),
  knownPerson('Known Person'),
  unknownPerson('Unknown Person'),
  fall('Fall'),
  inactivity('Inactivity'),
  fire('Fire'),
  system('System');

  final String label;

  const AlertFilter(this.label);
}

enum AlertSeverity { critical, warning, info }

enum EventDateFilter {
  today('Today'),
  yesterday('Yesterday'),
  last7Days('Last 7 Days'),
  last30Days('Last 30 Days'),
  all('All'),
  custom('Custom');

  final String label;

  const EventDateFilter(this.label);
}

class AlertGroup {
  final String title;
  final List<AiEvent> events;

  const AlertGroup({required this.title, required this.events});
}

class NotificationViewModel extends ChangeNotifier {
  final EventService _eventService;

  NotificationViewModel({EventService? eventService})
    : _eventService = eventService ?? EventService();

  List<AiEvent> _events = const [];
  bool _isLoading = false;
  bool _isAcknowledgingVisible = false;
  String? _errorMessage;
  String _searchQuery = '';
  AlertFilter _selectedFilter = AlertFilter.all;
  EventDateFilter _selectedDateFilter = EventDateFilter.all;
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  final Set<int> _acknowledgingEventIds = <int>{};

  List<AiEvent> get events => _events;
  bool get isLoading => _isLoading;
  bool get isAcknowledgingVisible => _isAcknowledgingVisible;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  AlertFilter get selectedFilter => _selectedFilter;
  EventDateFilter get selectedDateFilter => _selectedDateFilter;
  DateTime? get customStartDate => _customStartDate;
  DateTime? get customEndDate => _customEndDate;
  List<AlertFilter> get filters => AlertFilter.values;
  List<EventDateFilter> get dateFilters => EventDateFilter.values;
  String get selectedDateFilterLabel {
    if (_selectedDateFilter != EventDateFilter.custom ||
        _customStartDate == null ||
        _customEndDate == null) {
      return _selectedDateFilter.label;
    }

    return 'Custom: ${_formatDateLabel(_customStartDate!)} - '
        '${_formatDateLabel(_customEndDate!)}';
  }

  List<AiEvent> get filteredEvents {
    final query = _searchQuery.trim().toLowerCase();

    return _events.where((event) {
      if (!_matchesDateFilter(event)) return false;
      if (!_matchesFilter(event, _selectedFilter)) return false;
      if (query.isEmpty) return true;
      return _matchesSearch(event, query);
    }).toList();
  }

  List<AiEvent> get criticalAlerts {
    return filteredEvents
        .where(
          (event) => severityFor(event.eventType) == AlertSeverity.critical,
        )
        .toList();
  }

  List<AiEvent> get recentActivityEvents {
    final criticalIds = criticalAlerts.map((event) => event.id).toSet();
    return filteredEvents
        .where((event) => !criticalIds.contains(event.id))
        .toList();
  }

  List<AlertGroup> get groupedRecentActivity {
    return _groupEvents(recentActivityEvents);
  }

  int get criticalCount => _events
      .where((event) => severityFor(event.eventType) == AlertSeverity.critical)
      .length;

  int get unacknowledgedCount =>
      _events.where((event) => !event.isAcknowledged).length;

  DateTime? get lastAlertTime {
    if (_events.isEmpty) return null;
    DateTime? latest;

    for (final event in _events) {
      final timestamp = event.timestamp;
      if (timestamp == null) continue;
      if (latest == null || timestamp.isAfter(latest)) {
        latest = timestamp;
      }
    }

    return latest;
  }

  int get unknownPersonsTodayCount => _events
      .where((event) => _isToday(event.timestamp))
      .where((event) => event.eventType == 'unknown_person')
      .length;

  int get fallsTodayCount => _events
      .where((event) => _isToday(event.timestamp))
      .where((event) => event.eventType == 'fall_detected')
      .length;

  int get knownVisitsTodayCount => _events
      .where((event) => _isToday(event.timestamp))
      .where((event) => event.eventType == 'known_person')
      .length;

  int get criticalTodayCount => _events
      .where((event) => _isToday(event.timestamp))
      .where((event) => severityFor(event.eventType) == AlertSeverity.critical)
      .length;

  bool isAcknowledging(AiEvent event) {
    return _acknowledgingEventIds.contains(event.id);
  }

  List<AiEvent> get visibleUnacknowledgedEvents {
    return filteredEvents.where((event) => !event.isAcknowledged).toList();
  }

  int get visibleUnacknowledgedCount => visibleUnacknowledgedEvents.length;

  bool get visibleUnacknowledgedIncludesCritical {
    return visibleUnacknowledgedEvents.any(
      (event) => severityFor(event.eventType) == AlertSeverity.critical,
    );
  }

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

  void setFilter(AlertFilter filter) {
    if (_selectedFilter == filter) return;
    _selectedFilter = filter;
    notifyListeners();
  }

  void setDateFilter(EventDateFilter filter) {
    if (filter == EventDateFilter.custom &&
        (_customStartDate == null || _customEndDate == null)) {
      return;
    }

    if (_selectedDateFilter == filter) return;
    _selectedDateFilter = filter;
    notifyListeners();
  }

  void setCustomDateRange(DateTime start, DateTime end) {
    if (start.isAfter(end)) {
      _errorMessage = 'Start date must be before end date.';
      notifyListeners();
      return;
    }

    _customStartDate = DateTime(start.year, start.month, start.day);
    _customEndDate = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    _selectedDateFilter = EventDateFilter.custom;
    _errorMessage = null;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> acknowledgeEvent(AiEvent event) async {
    if (event.isAcknowledged || _acknowledgingEventIds.contains(event.id)) {
      return;
    }

    _acknowledgingEventIds.add(event.id);
    _errorMessage = null;
    notifyListeners();

    try {
      final acknowledged = await _eventService.acknowledgeEvent(event.id);
      _events = _events
          .map(
            (existing) =>
                existing.id == acknowledged.id ? acknowledged : existing,
          )
          .toList();
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error acknowledging notification: $error');
    } finally {
      _acknowledgingEventIds.remove(event.id);
      notifyListeners();
    }
  }

  Future<void> acknowledgeVisibleEvents() async {
    final visibleEvents = visibleUnacknowledgedEvents;
    if (visibleEvents.isEmpty || _isAcknowledgingVisible) return;

    final visibleIds = visibleEvents.map((event) => event.id).toList();
    _isAcknowledgingVisible = true;
    _acknowledgingEventIds.addAll(visibleIds);
    _errorMessage = null;
    notifyListeners();

    try {
      final acknowledged = await _eventService.acknowledgeVisibleEvents(
        visibleIds,
      );
      final acknowledgedById = {
        for (final event in acknowledged) event.id: event,
      };

      _events = _events
          .map((event) => acknowledgedById[event.id] ?? event)
          .toList();
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error acknowledging visible notifications: $error');
    } finally {
      _isAcknowledgingVisible = false;
      _acknowledgingEventIds.removeAll(visibleIds);
      notifyListeners();
    }
  }

  AlertSeverity severityFor(String eventType) {
    return switch (eventType) {
      'fall_detected' ||
      'prolonged_inactivity' ||
      'fire_alert' ||
      'gas_alert' ||
      'system_error' ||
      'camera_offline' => AlertSeverity.critical,
      'unknown_person' => AlertSeverity.warning,
      _ => AlertSeverity.info,
    };
  }

  bool _matchesFilter(AiEvent event, AlertFilter filter) {
    return switch (filter) {
      AlertFilter.all => true,
      AlertFilter.critical =>
        severityFor(event.eventType) == AlertSeverity.critical,
      AlertFilter.unacknowledged => !event.isAcknowledged,
      AlertFilter.knownPerson => event.eventType == 'known_person',
      AlertFilter.unknownPerson => event.eventType == 'unknown_person',
      AlertFilter.fall => event.eventType == 'fall_detected',
      AlertFilter.inactivity => event.eventType == 'prolonged_inactivity',
      AlertFilter.fire => event.eventType == 'fire_alert',
      AlertFilter.system =>
        event.eventType == 'system_error' ||
            event.eventType == 'camera_offline' ||
            event.eventType == 'gas_alert',
    };
  }

  bool _matchesDateFilter(AiEvent event) {
    if (_selectedDateFilter == EventDateFilter.all) return true;

    final timestamp = event.timestamp?.toLocal();
    if (timestamp == null) return false;

    final now = DateTime.now();

    return switch (_selectedDateFilter) {
      EventDateFilter.today => _isSameDate(timestamp, now),
      EventDateFilter.yesterday => _isSameDate(
        timestamp,
        now.subtract(const Duration(days: 1)),
      ),
      EventDateFilter.last7Days =>
        timestamp.isAfter(now.subtract(const Duration(days: 7))) ||
            _isSameDate(timestamp, now.subtract(const Duration(days: 7))),
      EventDateFilter.last30Days =>
        timestamp.isAfter(now.subtract(const Duration(days: 30))) ||
            _isSameDate(timestamp, now.subtract(const Duration(days: 30))),
      EventDateFilter.custom => _matchesCustomDateRange(timestamp),
      EventDateFilter.all => true,
    };
  }

  bool _matchesCustomDateRange(DateTime timestamp) {
    final start = _customStartDate;
    final end = _customEndDate;
    if (start == null || end == null) return false;

    return !timestamp.isBefore(start) && !timestamp.isAfter(end);
  }

  bool _matchesSearch(AiEvent event, String query) {
    final values = [
      event.eventType,
      event.displayType,
      event.profileName,
      event.premiseName,
      event.profileDisplay,
      event.premiseDisplay,
    ];

    return values.whereType<String>().any(
      (value) => value.toLowerCase().contains(query),
    );
  }

  List<AlertGroup> _groupEvents(List<AiEvent> events) {
    final today = <AiEvent>[];
    final yesterday = <AiEvent>[];
    final older = <AiEvent>[];

    for (final event in events) {
      final timestamp = event.timestamp;
      if (_isToday(timestamp)) {
        today.add(event);
      } else if (_isYesterday(timestamp)) {
        yesterday.add(event);
      } else {
        older.add(event);
      }
    }

    return [
      if (today.isNotEmpty) AlertGroup(title: 'Today', events: today),
      if (yesterday.isNotEmpty)
        AlertGroup(title: 'Yesterday', events: yesterday),
      if (older.isNotEmpty) AlertGroup(title: 'Older', events: older),
    ];
  }

  bool _isToday(DateTime? timestamp) {
    if (timestamp == null) return false;
    final local = timestamp.toLocal();
    final now = DateTime.now();
    return _isSameDate(local, now);
  }

  bool _isYesterday(DateTime? timestamp) {
    if (timestamp == null) return false;
    final local = timestamp.toLocal();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _isSameDate(local, yesterday);
  }

  bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _formatDateLabel(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${value.day} ${months[value.month - 1]}';
  }
}
