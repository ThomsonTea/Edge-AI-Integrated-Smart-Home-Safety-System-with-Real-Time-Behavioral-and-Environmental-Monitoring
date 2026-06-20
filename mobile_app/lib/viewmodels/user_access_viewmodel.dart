import 'package:flutter/material.dart';

import '../domain/dtos/register_user_request.dart';
import '../domain/models/user.dart';
import '../services/token_service.dart';
import '../services/user_service.dart';

class UserAccessViewModel extends ChangeNotifier {
  final UserService _service;
  final TokenService _tokenService;

  UserAccessViewModel({UserService? service, TokenService? tokenService})
    : _service = service ?? UserService(),
      _tokenService = tokenService ?? TokenService();

  List<User> _users = const [];
  String? _currentUserId;
  String? _currentUserRole;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;
  final Set<String> _deletingUserIds = <String>{};

  List<User> get users => _users;
  String? get currentUserRole => _currentUserRole;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get canManageUsers =>
      _currentUserRole == 'owner' || _currentUserRole == 'manager';

  List<UserRoleOption> get roleOptions {
    return switch (_currentUserRole) {
      'owner' => const [
        UserRoleOption(value: 'manager', label: 'Manager'),
        UserRoleOption(value: 'normal_user', label: 'Normal User'),
      ],
      'manager' => const [
        UserRoleOption(value: 'normal_user', label: 'Normal User'),
      ],
      _ => const [],
    };
  }

  bool isDeleting({required String userId}) {
    return _deletingUserIds.contains(userId);
  }

  Future<void> loadUsers() async {
    _setLoading(true);

    try {
      _currentUserId = await _tokenService.getCurrentUserId();
      _currentUserRole = _normalizeRole(
        await _tokenService.getCurrentUserRole(),
      );
      _users = await _service.fetchUsers();
      _currentUserRole = _currentUserRoleForLoadedUsers() ?? _currentUserRole;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error loading users: $error');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> registerUser({
    required String username,
    required String email,
    required String phoneNumber,
    required String password,
    required String role,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _service.registerUser(
        RegisterUserRequest(
          username: username,
          email: email,
          phoneNumber: phoneNumber,
          password: password,
          role: role,
        ),
      );

      _successMessage = 'User registered successfully';
      await loadUsers();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error registering user: $error');
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> deleteUser({required String id}) async {
    User? target;
    for (final user in _users) {
      if (user.id == id) {
        target = user;
        break;
      }
    }

    if (target?.isOwner == true) {
      _errorMessage = 'Primary Owner cannot be deleted.';
      notifyListeners();
      return;
    }

    _deletingUserIds.add(id);
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _service.deleteUser(id: id);
      _users = _users.where((user) => user.id != id).toList();
      _successMessage = 'User deleted successfully';
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error deleting user: $error');
    } finally {
      _deletingUserIds.remove(id);
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String? _currentUserRoleForLoadedUsers() {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return null;

    for (final user in _users) {
      if (user.id == currentUserId) {
        return user.normalizedRole;
      }
    }

    return null;
  }

  String? _normalizeRole(String? role) {
    final value = role?.trim().toLowerCase().replaceAll('-', '_');
    if (value == null || value.isEmpty) return null;

    return switch (value) {
      'owner' || 'admin' || 'administrator' => 'owner',
      'manager' || 'operator' => 'manager',
      'normal_user' ||
      'normal user' ||
      'member' ||
      'guest' ||
      'resident' => 'normal_user',
      _ => value,
    };
  }
}

class UserRoleOption {
  final String value;
  final String label;

  const UserRoleOption({required this.value, required this.label});
}
