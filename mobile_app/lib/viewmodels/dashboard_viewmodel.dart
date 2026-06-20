import 'package:flutter/material.dart';

import '../domain/models/dashboard_summary.dart';
import '../services/dashboard_service.dart';

class DashboardFilterOption {
  final String value;
  final String label;

  const DashboardFilterOption({required this.value, required this.label});
}

class DashboardViewModel extends ChangeNotifier {
  final DashboardService _dashboardService;

  DashboardViewModel({DashboardService? dashboardService})
    : _dashboardService = dashboardService ?? DashboardService();

  static const timeFilterOptions = [
    DashboardFilterOption(value: 'today', label: 'Today'),
    DashboardFilterOption(value: 'yesterday', label: 'Yesterday'),
    DashboardFilterOption(value: 'last_7_days', label: 'Last 7 Days'),
    DashboardFilterOption(value: 'all', label: 'All'),
  ];

  static const eventTypeFilterOptions = [
    DashboardFilterOption(value: 'all', label: 'All'),
    DashboardFilterOption(value: 'known_person', label: 'Known Person'),
    DashboardFilterOption(value: 'unknown_person', label: 'Unknown Person'),
    DashboardFilterOption(
      value: 'blacklisted_person',
      label: 'Blacklisted Person',
    ),
    DashboardFilterOption(value: 'fire_alert', label: 'Fire Alert'),
    DashboardFilterOption(value: 'gas_alert', label: 'Gas Alert'),
    DashboardFilterOption(value: 'system_error', label: 'System Error'),
    DashboardFilterOption(value: 'fall_detected', label: 'Fall Detected'),
    DashboardFilterOption(
      value: 'prolonged_inactivity',
      label: 'Prolonged Inactivity',
    ),
  ];

  DashboardSummary _summary = DashboardSummary.empty();
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedTimeFilter = 'today';
  String _selectedEventType = 'all';

  DashboardSummary get summary => _summary;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get selectedTimeFilter => _selectedTimeFilter;
  String get selectedEventType => _selectedEventType;
  bool get isEmpty =>
      !_isLoading &&
      _errorMessage == null &&
      _summary.eventTrend.isEmpty &&
      _summary.eventTypeCounts.total == 0 &&
      _summary.latestCriticalEvent == null;

  Future<void> initializeDashboard() {
    return loadSummary();
  }

  Future<void> loadSummary() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _summary = await _dashboardService.fetchSummary(
        timeFilter: _selectedTimeFilter,
        eventType: _selectedEventType,
      );
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setTimeFilter(String value) async {
    if (value == _selectedTimeFilter) return;
    _selectedTimeFilter = value;
    await loadSummary();
  }

  Future<void> setEventTypeFilter(String value) async {
    if (value == _selectedEventType) return;
    _selectedEventType = value;
    await loadSummary();
  }
}
