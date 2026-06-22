import 'package:flutter/material.dart';

import '../domain/models/analytics_models.dart';
import '../services/analytics_service.dart';

const analyticsRanges = ['24h', '7d', '30d'];

enum AnalyticsSection { sensorTrends, securityEvents }

enum SensorMetric { temperature, humidity, gas }

enum EventCategory { all, people, safety, environment }

enum EventViewMode { trend, distribution }

const analyticsEventTypes = [
  'known_person',
  'unknown_person',
  'fall_detected',
  'prolonged_inactivity',
  'gas_alert',
  'high_temperature',
  'sensor_offline',
];

const eventTypesByCategory = {
  EventCategory.all: analyticsEventTypes,
  EventCategory.people: ['known_person', 'unknown_person'],
  EventCategory.safety: ['fall_detected', 'prolonged_inactivity'],
  EventCategory.environment: [
    'gas_alert',
    'high_temperature',
    'sensor_offline',
  ],
};

class AnalyticsViewModel extends ChangeNotifier {
  final AnalyticsService _analyticsService;

  AnalyticsViewModel({AnalyticsService? analyticsService})
    : _analyticsService = analyticsService ?? AnalyticsService();

  SensorAnalytics _sensorAnalytics = const SensorAnalytics.empty();
  EventAnalytics _eventAnalytics = const EventAnalytics.empty();
  EventTrendAnalytics _eventTrendAnalytics = const EventTrendAnalytics.empty();
  AnalyticsSection _selectedSection = AnalyticsSection.sensorTrends;
  EventViewMode _selectedEventViewMode = EventViewMode.trend;
  final Set<SensorMetric> _selectedSensorMetrics = {
    SensorMetric.temperature,
    SensorMetric.humidity,
  };
  EventCategory _selectedEventCategory = EventCategory.all;
  final Set<String> _selectedEventTypes = {...analyticsEventTypes};
  String _sensorRange = '24h';
  String _eventRange = '7d';
  bool _isSensorLoading = false;
  bool _isEventLoading = false;
  String? _sensorError;
  String? _eventError;

  SensorAnalytics get sensorAnalytics => _sensorAnalytics;
  EventAnalytics get eventAnalytics => _eventAnalytics;
  EventTrendAnalytics get eventTrendAnalytics => _eventTrendAnalytics;
  AnalyticsSection get selectedSection => _selectedSection;
  EventViewMode get selectedEventViewMode => _selectedEventViewMode;
  Set<SensorMetric> get selectedSensorMetrics =>
      Set.unmodifiable(_selectedSensorMetrics);
  EventCategory get selectedEventCategory => _selectedEventCategory;
  Set<String> get selectedEventTypes => Set.unmodifiable(_selectedEventTypes);
  List<EventCount> get filteredEventCounts => _eventAnalytics.counts
      .where((count) => _selectedEventTypes.contains(count.eventType))
      .toList();
  String get sensorRange => _sensorRange;
  String get eventRange => _eventRange;
  bool get isSensorLoading => _isSensorLoading;
  bool get isEventLoading => _isEventLoading;
  String? get sensorError => _sensorError;
  String? get eventError => _eventError;

  void setSelectedSection(AnalyticsSection section) {
    if (_selectedSection == section) return;
    _selectedSection = section;
    notifyListeners();
  }

  void setEventViewMode(EventViewMode mode) {
    if (_selectedEventViewMode == mode) return;
    _selectedEventViewMode = mode;
    notifyListeners();
  }

  void toggleSensorMetric(SensorMetric metric) {
    if (_selectedSensorMetrics.contains(metric)) {
      if (_selectedSensorMetrics.length == 1) return;
      _selectedSensorMetrics.remove(metric);
    } else {
      _selectedSensorMetrics.add(metric);
    }

    notifyListeners();
  }

  void setEventCategory(EventCategory category) {
    _selectedEventCategory = category;
    _selectedEventTypes
      ..clear()
      ..addAll(eventTypesByCategory[category] ?? analyticsEventTypes);
    notifyListeners();
  }

  void toggleEventType(String eventType) {
    if (!analyticsEventTypes.contains(eventType)) return;

    if (_selectedEventTypes.contains(eventType)) {
      if (_selectedEventTypes.length == 1) return;
      _selectedEventTypes.remove(eventType);
    } else {
      _selectedEventTypes.add(eventType);
    }

    notifyListeners();
  }

  @visibleForTesting
  void debugSetEventAnalyticsForTest(EventAnalytics analytics) {
    _eventAnalytics = analytics;
  }

  @visibleForTesting
  void debugSetEventTrendAnalyticsForTest(EventTrendAnalytics analytics) {
    _eventTrendAnalytics = analytics;
  }

  Future<void> loadAnalytics() async {
    await Future.wait([loadSensorAnalytics(), loadSecurityEventAnalytics()]);
  }

  Future<void> loadSensorAnalytics() async {
    _isSensorLoading = true;
    _sensorError = null;
    notifyListeners();

    try {
      _sensorAnalytics = await _analyticsService.fetchSensorAnalytics(
        _sensorRange,
      );
    } catch (error) {
      _sensorError = error.toString();
      _sensorAnalytics = SensorAnalytics(range: _sensorRange, points: const []);
    } finally {
      _isSensorLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadEventAnalytics() async {
    await loadSecurityEventAnalytics();
  }

  Future<void> loadEventTrendAnalytics() async {
    await loadSecurityEventAnalytics();
  }

  Future<void> loadSecurityEventAnalytics() async {
    _isEventLoading = true;
    _eventError = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _analyticsService.fetchEventAnalytics(_eventRange),
        _analyticsService.fetchEventTrendAnalytics(_eventRange),
      ]);
      _eventAnalytics = results[0] as EventAnalytics;
      _eventTrendAnalytics = results[1] as EventTrendAnalytics;
    } catch (error) {
      _eventError = error.toString();
      _eventAnalytics = EventAnalytics(range: _eventRange, counts: const []);
      _eventTrendAnalytics = EventTrendAnalytics(
        range: _eventRange,
        bucket: 'daily',
        points: const [],
      );
    } finally {
      _isEventLoading = false;
      notifyListeners();
    }
  }

  Future<void> setSensorRange(String range) async {
    if (!analyticsRanges.contains(range) || range == _sensorRange) return;
    _sensorRange = range;
    await loadSensorAnalytics();
  }

  Future<void> setEventRange(String range) async {
    if (!analyticsRanges.contains(range) || range == _eventRange) return;
    _eventRange = range;
    await loadSecurityEventAnalytics();
  }
}
