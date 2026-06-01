import 'package:flutter/material.dart';
import '../services/user_access_service.dart';
import '../domain/models/user.dart';


class UserAccessViewModel extends ChangeNotifier {
  final UserAccessService _service = UserAccessService();

  List<User> _users = [];
  bool _isLoading = false;

  List<User> get users => _users;
  bool get isLoading => _isLoading;

  Future<void> loadUsers() async {
    _isLoading = true;
    notifyListeners();

    try {
      _users = await _service.fetchUsers();
    } catch (e) {
      debugPrint('Error loading users: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> registerUser(String name, String role) async {
    await _service.addUser(
      User(id: '', name: name, role: role),
    );
    await loadUsers();
  }

  Future<void> deleteUser(String id) async {
    await _service.deleteUser(id);
    await loadUsers();
  }
}