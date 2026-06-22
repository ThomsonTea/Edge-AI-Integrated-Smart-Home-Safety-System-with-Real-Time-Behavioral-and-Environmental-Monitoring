import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/models/user_profile.dart';
import '../services/profile_service.dart';

class ProfileViewModel extends ChangeNotifier {
  final ProfileService _profileService;

  ProfileViewModel({ProfileService? profileService})
    : _profileService = profileService ?? ProfileService();

  UserProfile? _profile;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  UserProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  Future<void> loadProfile() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _profile = await _profileService.fetchProfile();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({
    required String username,
    required String email,
    String? phoneNumber,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _profile = await _profileService.updateProfile(
        username: username,
        email: email,
        phoneNumber: phoneNumber,
      );
      _successMessage = 'Profile updated successfully';
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _profileService.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      _successMessage = 'Password changed successfully';
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> uploadProfilePicture(File imageFile) async {
    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _profile = await _profileService.uploadProfilePicture(imageFile);
      _successMessage = 'Profile picture updated successfully';
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> registerFace(File imageFile) async {
    _isSaving = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      _profile = await _profileService.registerFace(imageFile);
      _successMessage = 'Face registered successfully';
      return true;
    } catch (error) {
      _errorMessage = _friendlyFaceRegistrationError(error);
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

  String _friendlyFaceRegistrationError(Object error) {
    final message = error.toString();
    final lower = message.toLowerCase();

    if (lower.contains('no face detected')) {
      return 'No face detected. Please use a clear photo of your face.';
    }

    if (lower.contains('multiple faces detected')) {
      return 'Multiple faces detected. Please use a photo with only your face.';
    }

    return message;
  }
}
