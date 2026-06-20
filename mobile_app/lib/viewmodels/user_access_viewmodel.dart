import 'dart:io';

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
  bool _isResettingPassword = false;
  String? _errorMessage;
  String? _successMessage;
  final Set<String> _deletingUserIds = <String>{};
  final Set<String> _resettingPasswordUserIds = <String>{};
  final Set<String> _updatingUserIds = <String>{};
  final Set<String> _registeringFaceUserIds = <String>{};

  List<User> get users => _users;
  String? get currentUserRole => _currentUserRole;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get isResettingPassword => _isResettingPassword;
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

  bool isResettingPasswordFor({required String userId}) {
    return _resettingPasswordUserIds.contains(userId);
  }

  bool isUpdating({required String userId}) {
    return _updatingUserIds.contains(userId);
  }

  bool isRegisteringFaceFor({required String userId}) {
    return _registeringFaceUserIds.contains(userId);
  }

  bool isCurrentUser(User user) => user.id == _currentUserId;

  bool canEditUser(User user) =>
      isCurrentUser(user) || canManageTargetUser(user);

  bool canDeleteUser(User user) {
    if (isCurrentUser(user)) return false;
    return canManageTargetUser(user);
  }

  bool canResetPassword(User user) {
    if (isCurrentUser(user)) return false;
    return canManageTargetUser(user);
  }

  bool canRegisterFace(User user) =>
      isCurrentUser(user) || canManageTargetUser(user);

  List<UserRoleOption> roleOptionsForTarget(User user) {
    if (isCurrentUser(user) || !canEditUser(user)) return const [];
    return roleOptions;
  }

  bool canManageTargetUser(User user) {
    if (user.isOwner) return false;

    return switch (_currentUserRole) {
      'owner' =>
        user.normalizedRole == 'manager' ||
            user.normalizedRole == 'normal_user',
      'manager' => user.normalizedRole == 'normal_user',
      _ => false,
    };
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

  Future<bool> updateUser({
    required String id,
    required String username,
    required String email,
    required String phoneNumber,
    required String role,
  }) async {
    final target = _findUser(id);

    if (target == null || !canEditUser(target)) {
      _errorMessage = target?.isOwner == true
          ? 'Primary Owner cannot be edited here.'
          : 'You cannot edit this user.';
      notifyListeners();
      return false;
    }

    _updatingUserIds.add(id);
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _service.updateUser(
        id: id,
        username: username,
        email: email,
        phoneNumber: phoneNumber,
        role: isCurrentUser(target) ? null : role,
      );
      _successMessage = 'User updated successfully';
      await loadUsers();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error updating user: $error');
      return false;
    } finally {
      _updatingUserIds.remove(id);
      notifyListeners();
    }
  }

  Future<void> deleteUser({required String id}) async {
    final target = _findUser(id);

    if (target == null || !canDeleteUser(target)) {
      _errorMessage = target?.isOwner == true
          ? 'Primary Owner cannot be deleted.'
          : 'You cannot delete this user.';
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

  Future<bool> registerFaceForUser({
    required String id,
    required File imageFile,
  }) async {
    final target = _findUser(id);

    if (target == null || !canRegisterFace(target)) {
      _errorMessage = target?.isOwner == true
          ? 'Primary Owner face is managed from Profile.'
          : 'You cannot register a face for this user.';
      notifyListeners();
      return false;
    }

    _registeringFaceUserIds.add(id);
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _service.registerFace(id: id, imageFile: imageFile);
      _successMessage = target.faceRegistered
          ? 'Face updated successfully'
          : 'Face registered successfully';
      await loadUsers();
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error registering user face: $error');
      return false;
    } finally {
      _registeringFaceUserIds.remove(id);
      notifyListeners();
    }
  }

  Future<bool> resetPassword({
    required String id,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final target = _findUser(id);

    if (target == null || !canResetPassword(target)) {
      _errorMessage = target?.isOwner == true
          ? 'Primary Owner password cannot be reset here.'
          : 'You cannot reset this user password.';
      notifyListeners();
      return false;
    }

    _isResettingPassword = true;
    _resettingPasswordUserIds.add(id);
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _service.resetPassword(
        id: id,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      _successMessage = 'Password reset successfully';
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error resetting password: $error');
      return false;
    } finally {
      _isResettingPassword = false;
      _resettingPasswordUserIds.remove(id);
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

  User? _findUser(String id) {
    for (final user in _users) {
      if (user.id == id) {
        return user;
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
