import 'dart:async';

import 'package:flutter/material.dart';

import '../domain/models/dashboard_summary.dart';
import '../domain/models/sensor_snapshot.dart';
import '../services/dashboard_service.dart';
import '../services/sensor_service.dart';

class DashboardViewModel extends ChangeNotifier {
  final DashboardService _dashboardService;
  final SensorService _sensorService;

  DashboardViewModel({
    DashboardService? dashboardService,
    SensorService? sensorService,
  }) : _dashboardService = dashboardService ?? DashboardService(),
       _sensorService = sensorService ?? SensorService();

  DashboardSummary _summary = DashboardSummary.empty();
  SensorSnapshot _sensorSnapshot = const SensorSnapshot.offline();
  Timer? _sensorRefreshTimer;
  bool _isLoading = false;
  bool _isSensorLoading = false;
  String? _errorMessage;
  String? _sensorErrorMessage;

  DashboardSummary get summary => _summary;
  SensorSnapshot get sensorSnapshot => _sensorSnapshot;
  bool get isLoading => _isLoading;
  bool get isSensorLoading => _isSensorLoading;
  String? get errorMessage => _errorMessage;
  String? get sensorErrorMessage => _sensorErrorMessage;
  bool get isEmpty =>
      !_isLoading &&
      _errorMessage == null &&
      _summary.knownPersonTodayCount == 0 &&
      _summary.unknownPersonTodayCount == 0 &&
      _summary.fallTodayCount == 0 &&
      _summary.environmentAlertTodayCount == 0 &&
      _summary.criticalAlertCount == 0 &&
      _summary.latestDetection == null;

  Future<void> initializeDashboard() async {
    await refreshDashboard();
    _startSensorRefreshTimer();
  }

  Future<void> refreshDashboard() {
    return Future.wait([loadSummary(), loadSensorSnapshot()]).then((_) {});
  }

  Future<void> loadSummary() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _summary = await _dashboardService.fetchSummary();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSensorSnapshot({bool showLoading = true}) async {
    if (showLoading) {
      _isSensorLoading = true;
      notifyListeners();
    }

    try {
      _sensorSnapshot = await _sensorService.fetchLatest();
      _sensorErrorMessage = null;
    } catch (error) {
      _sensorSnapshot = const SensorSnapshot.offline();
      _sensorErrorMessage = error.toString();
    } finally {
      if (showLoading) {
        _isSensorLoading = false;
      }
      notifyListeners();
    }
  }

  void _startSensorRefreshTimer() {
    _sensorRefreshTimer?.cancel();
    _sensorRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => loadSensorSnapshot(showLoading: false),
    );
  }

  @override
  void dispose() {
    _sensorRefreshTimer?.cancel();
    super.dispose();
  }
}
