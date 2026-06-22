import 'package:flutter/material.dart';

import '../domain/models/analytics_models.dart';
import '../services/analytics_service.dart';

const analyticsRanges = ['24h', '7d', '30d'];

class AnalyticsViewModel extends ChangeNotifier {
  final AnalyticsService _analyticsService;

  AnalyticsViewModel({AnalyticsService? analyticsService})
    : _analyticsService = analyticsService ?? AnalyticsService();

  SensorAnalytics _sensorAnalytics = const SensorAnalytics.empty();
  EventAnalytics _eventAnalytics = const EventAnalytics.empty();
  String _sensorRange = '24h';
  String _eventRange = '7d';
  bool _isSensorLoading = false;
  bool _isEventLoading = false;
  String? _sensorError;
  String? _eventError;

  SensorAnalytics get sensorAnalytics => _sensorAnalytics;
  EventAnalytics get eventAnalytics => _eventAnalytics;
  String get sensorRange => _sensorRange;
  String get eventRange => _eventRange;
  bool get isSensorLoading => _isSensorLoading;
  bool get isEventLoading => _isEventLoading;
  String? get sensorError => _sensorError;
  String? get eventError => _eventError;

  Future<void> loadAnalytics() async {
    await Future.wait([loadSensorAnalytics(), loadEventAnalytics()]);
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
    _isEventLoading = true;
    _eventError = null;
    notifyListeners();

    try {
      _eventAnalytics = await _analyticsService.fetchEventAnalytics(
        _eventRange,
      );
    } catch (error) {
      _eventError = error.toString();
      _eventAnalytics = EventAnalytics(range: _eventRange, counts: const []);
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
    await loadEventAnalytics();
  }
}
