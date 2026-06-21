import 'package:flutter/material.dart';

import '../domain/models/dashboard_summary.dart';
import '../services/dashboard_service.dart';

class DashboardViewModel extends ChangeNotifier {
  final DashboardService _dashboardService;

  DashboardViewModel({DashboardService? dashboardService})
    : _dashboardService = dashboardService ?? DashboardService();

  DashboardSummary _summary = DashboardSummary.empty();
  bool _isLoading = false;
  String? _errorMessage;

  DashboardSummary get summary => _summary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isEmpty =>
      !_isLoading &&
      _errorMessage == null &&
      _summary.knownPersonTodayCount == 0 &&
      _summary.unknownPersonTodayCount == 0 &&
      _summary.fallTodayCount == 0 &&
      _summary.environmentAlertTodayCount == 0 &&
      _summary.criticalAlertCount == 0 &&
      _summary.latestDetection == null;

  Future<void> initializeDashboard() {
    return loadSummary();
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
}
