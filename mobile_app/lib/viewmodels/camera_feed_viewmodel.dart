import 'package:flutter/material.dart';
import '../domain/models/security_camera.dart';
import '../services/camera_service.dart';
import '../services/token_service.dart';

class CameraFeedViewModel extends ChangeNotifier {
  final TokenService _tokens;
  final CameraService _service;

  CameraFeedViewModel({
    TokenService? tokenService,
    CameraService? cameraService,
  }) : _tokens = tokenService ?? TokenService(),
       _service = cameraService ?? CameraService();

  String? jwtToken, errorMessage, successMessage, currentUserRole;
  List<SecurityCamera> cameras = const [];
  List<DiscoveredCamera> discoveredCameras = const [];
  SecurityCamera? selectedCamera;
  bool isLoading = false,
      isSubmitting = false,
      isTesting = false,
      isDiscovering = false,
      isResolving = false;
  bool get canManage =>
      currentUserRole == 'owner' || currentUserRole == 'manager';

  Future<void> loadCameraSession() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      jwtToken = await _tokens.getToken();
      currentUserRole = _normalize(await _tokens.getCurrentUserRole());
      cameras = await _service.fetchCameras();
      if (selectedCamera == null ||
          !cameras.any((c) => c.id == selectedCamera!.id)) {
        selectedCamera = cameras.isEmpty ? null : cameras.first;
      } else {
        selectedCamera = cameras.firstWhere((c) => c.id == selectedCamera!.id);
      }
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectCamera(SecurityCamera camera) {
    selectedCamera = camera;
    notifyListeners();
  }

  Future<void> discoverCameras() async {
    isDiscovering = true;
    errorMessage = null;
    discoveredCameras = const [];
    notifyListeners();
    try {
      discoveredCameras = await _service.discoverCameras();
      if (discoveredCameras.isEmpty) {
        errorMessage = 'No ONVIF cameras were found on the server network.';
      }
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isDiscovering = false;
      notifyListeners();
    }
  }

  Future<String?> resolveStream({
    required DiscoveredCamera camera,
    required String username,
    required String password,
  }) async {
    isResolving = true;
    errorMessage = null;
    notifyListeners();
    try {
      return await _service.resolveStream(
        serviceUrl: camera.serviceUrl,
        username: username,
        password: password,
      );
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return null;
    } finally {
      isResolving = false;
      notifyListeners();
    }
  }

  Future<bool> addCamera(Map<String, dynamic> payload) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _service.addCamera(payload);
      successMessage = 'Camera added successfully';
      await loadCameraSession();
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> updateCamera(
    SecurityCamera camera,
    Map<String, dynamic> payload,
  ) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _service.updateCamera(camera.id, payload);
      successMessage = 'Camera updated successfully';
      await loadCameraSession();
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<bool> testConnection(Map<String, dynamic> payload) async {
    isTesting = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _service.testConnection(payload);
      successMessage = 'Camera connection successful';
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isTesting = false;
      notifyListeners();
    }
  }

  Future<void> deleteCamera(SecurityCamera camera) async {
    try {
      await _service.deleteCamera(camera.id);
      successMessage = 'Camera removed';
      await loadCameraSession();
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      notifyListeners();
    }
  }

  void clearMessages() {
    errorMessage = null;
    successMessage = null;
  }

  String? _normalize(String? value) {
    final normalized = value?.trim().toLowerCase().replaceAll(' ', '_');
    return normalized == 'admin' || normalized == 'administrator'
        ? 'owner'
        : normalized;
  }
}
