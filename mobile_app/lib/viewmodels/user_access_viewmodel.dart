import 'package:flutter/material.dart';

import '../domain/dtos/register_user_request.dart';
import '../domain/models/user.dart';
import '../services/user_service.dart';

class UserAccessViewModel extends ChangeNotifier {
  final UserService _service;

  UserAccessViewModel({UserService? service})
    : _service = service ?? UserService();

  List<User> _users = const [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;
  final Set<String> _deletingUserIds = <String>{};

  List<User> get users => _users;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  bool isDeleting({required String userId}) {
    return _deletingUserIds.contains(userId);
  }

  Future<void> loadUsers() async {
    _setLoading(true);

    try {
      _users = await _service.fetchUsers();
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
}
