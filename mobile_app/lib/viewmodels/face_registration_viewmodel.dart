import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/models/user.dart';
import '../services/face_service.dart';
import '../services/token_service.dart';
import '../services/user_service.dart';

class FaceRegistrationViewModel extends ChangeNotifier {
  final FaceService _faceService;
  final TokenService _tokenService;
  final UserService _userService;

  FaceRegistrationViewModel({
    FaceService? faceService,
    TokenService? tokenService,
    UserService? userService,
  }) : _faceService = faceService ?? FaceService(),
       _tokenService = tokenService ?? TokenService(),
       _userService = userService ?? UserService();

  List<User> _users = const [];
  User? _selectedUser;
  String? _currentUserId;
  File? _selectedImage;
  bool _isLoading = false;
  bool _isLoadingUsers = false;
  String? _errorMessage;
  String? _successMessage;

  List<User> get users => _users;
  User? get selectedUser => _selectedUser;
  String? get currentUserId => _currentUserId;
  File? get selectedImage => _selectedImage;
  bool get isLoading => _isLoading;
  bool get isLoadingUsers => _isLoadingUsers;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;
  bool get canRegisterFace => _selectedUser != null && _selectedImage != null;

  Future<void> loadUsers() async {
    _isLoadingUsers = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUserId = await _tokenService.getCurrentUserId();
      _users = await _userService.fetchUsers();

      final selectedUser = _selectedUser;
      if (selectedUser != null &&
          !_users.any((user) => user.id == selectedUser.id)) {
        _selectedUser = null;
      }
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error loading users for face registration: $error');
    } finally {
      _isLoadingUsers = false;
      notifyListeners();
    }
  }

  void selectUser(User user) {
    _selectedUser = user;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  void setImage(File image) {
    _selectedImage = image;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }

  Future<bool> registerFace() async {
    final user = _selectedUser;
    final image = _selectedImage;

    if (user == null) {
      _errorMessage = 'Select a user before registering a face.';
      _successMessage = null;
      notifyListeners();
      return false;
    }

    if (image == null) {
      _errorMessage = 'Select a face image before registering.';
      _successMessage = null;
      notifyListeners();
      return false;
    }

    final profileId = int.tryParse(user.id);
    if (profileId == null || profileId <= 0) {
      _errorMessage = 'Selected user has an invalid profile id.';
      _successMessage = null;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      final result = await _faceService.registerFace(
        profileId: profileId,
        imageFile: image,
      );

      _successMessage = result.message;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      debugPrint('Error registering face: $error');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
