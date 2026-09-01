import 'package:flutter/material.dart';

import '../domain/models/retention_settings.dart';
import '../services/retention_service.dart';

class RetentionSettingsViewModel extends ChangeNotifier {
  final RetentionService _service;

  RetentionSettingsViewModel({RetentionService? service})
    : _service = service ?? RetentionService();

  RetentionSettings? _settings;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isCleaning = false;
  String? _errorMessage;
  String? _successMessage;

  RetentionSettings? get settings => _settings;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isCleaning => _isCleaning;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _settings = await _service.fetchSettings();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateDraft(RetentionSettings next) {
    _settings = next;
    _successMessage = null;
    notifyListeners();
  }

  Future<bool> save() async {
    final current = _settings;
    if (current == null || _isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      _settings = await _service.updateSettings(current);
      _successMessage = 'Retention settings saved';
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<RetentionCleanupResult?> cleanup() async {
    if (_isCleaning) return null;
    _isCleaning = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      final result = await _service.runCleanup();
      _successMessage =
          'Cleanup complete: ${result.eventsDeleted} events, '
          '${result.sensorReadingsDeleted} readings and '
          '${result.imagesDeleted} images removed.';
      return result;
    } catch (error) {
      _errorMessage = error.toString();
      return null;
    } finally {
      _isCleaning = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
