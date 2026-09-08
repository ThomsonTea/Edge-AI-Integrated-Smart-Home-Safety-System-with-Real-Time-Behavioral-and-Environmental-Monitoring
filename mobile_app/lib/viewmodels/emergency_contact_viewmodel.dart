import 'package:flutter/material.dart';

import '../domain/models/emergency_contact.dart';
import '../services/emergency_contact_service.dart';
import '../services/token_service.dart';

class EmergencyContactViewModel extends ChangeNotifier {
  final EmergencyContactService _service;
  final TokenService _tokenService;

  EmergencyContactViewModel({
    EmergencyContactService? service,
    TokenService? tokenService,
  }) : _service = service ?? EmergencyContactService(),
       _tokenService = tokenService ?? TokenService();

  List<EmergencyContact> _contacts = const [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;
  String? _role;

  List<EmergencyContact> get contacts => List.unmodifiable(_contacts);
  List<EmergencyContact> get enabledContacts =>
      _contacts.where((contact) => contact.enabled).toList(growable: false);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get canManage => _role == 'owner' || _role == 'manager';

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _role = _normalizeRole(await _tokenService.getCurrentUserRole());
      _contacts = await _service.fetchContacts();
    } catch (error) {
      _errorMessage = _friendlyError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> save(EmergencyContact contact, {required bool isNew}) async {
    if (_isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      if (isNew) {
        final created = await _service.createContact(contact);
        _contacts = _sorted([..._contacts, created]);
        _successMessage = 'Emergency contact added.';
      } else {
        final updated = await _service.updateContact(contact);
        _contacts = _sorted([
          for (final existing in _contacts)
            if (existing.id == updated.id) updated else existing,
        ]);
        _successMessage = 'Emergency contact updated.';
      }
      return true;
    } catch (error) {
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> setEnabled(EmergencyContact contact, bool enabled) {
    return save(contact.copyWith(enabled: enabled), isNew: false);
  }

  Future<bool> delete(EmergencyContact contact) async {
    if (_isSaving) return false;
    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
    try {
      await _service.deleteContact(contact.id);
      _contacts = _contacts
          .where((existing) => existing.id != contact.id)
          .toList(growable: false);
      _successMessage = 'Emergency contact deleted.';
      return true;
    } catch (error) {
      _errorMessage = _friendlyError(error);
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  String? _normalizeRole(String? role) {
    final value = role?.trim().toLowerCase().replaceAll('-', '_');
    return switch (value) {
      'admin' || 'administrator' => 'owner',
      'operator' => 'manager',
      _ => value,
    };
  }

  String _friendlyError(Object error) {
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  List<EmergencyContact> _sorted(List<EmergencyContact> contacts) {
    contacts.sort((left, right) {
      if (left.enabled != right.enabled) return left.enabled ? -1 : 1;
      final priority = left.priority.compareTo(right.priority);
      if (priority != 0) return priority;
      return left.contactName.toLowerCase().compareTo(
        right.contactName.toLowerCase(),
      );
    });
    return contacts;
  }
}
