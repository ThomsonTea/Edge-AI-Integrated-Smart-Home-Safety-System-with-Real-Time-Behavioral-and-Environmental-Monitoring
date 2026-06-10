import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'token_service.dart';

class FaceRegistrationResult {
  final String message;
  final int profileId;
  final bool hasFaceSignature;

  const FaceRegistrationResult({
    required this.message,
    required this.profileId,
    required this.hasFaceSignature,
  });

  factory FaceRegistrationResult.fromJson(Map<String, dynamic> json) {
    final profileId = int.tryParse(json['profile_id']?.toString() ?? '');

    if (profileId == null) {
      throw Exception('Invalid face registration response format');
    }

    return FaceRegistrationResult(
      message: json['message']?.toString() ?? 'Face registered successfully',
      profileId: profileId,
      hasFaceSignature: json['has_face_signature'] == true,
    );
  }
}

class FaceService {
  final String baseUrl;
  final TokenService _tokenService;
  final http.Client _client;

  FaceService({
    String? baseUrl,
    TokenService? tokenService,
    http.Client? client,
  }) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
       _tokenService = tokenService ?? TokenService(),
       _client = client ?? http.Client();

  Future<FaceRegistrationResult> registerFace({
    required int profileId,
    required File imageFile,
  }) async {
    if (profileId <= 0) {
      throw ArgumentError.value(
        profileId,
        'profileId',
        'Profile id must be greater than zero',
      );
    }

    if (!await imageFile.exists()) {
      throw Exception('Selected face image does not exist');
    }

    final token = await _authToken();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/profile/profiles/$profileId/face'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    http.StreamedResponse streamedResponse;

    try {
      streamedResponse = await _client.send(request);
    } catch (error) {
      throw Exception('Network error: $error');
    }

    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return _registrationResultFromResponse(response);
    }

    throw Exception(
      _errorMessage(fallback: 'Failed to register face', response: response),
    );
  }

  Future<String> _authToken() async {
    final token = await _tokenService.getToken();

    if (token == null || token.isEmpty || token == 'null') {
      throw Exception('Invalid auth token');
    }

    return token.trim();
  }

  FaceRegistrationResult _registrationResultFromResponse(
    http.Response response,
  ) {
    final decoded = _decodeJson(response);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid face registration response format');
    }

    return FaceRegistrationResult.fromJson(decoded);
  }

  dynamic _decodeJson(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response payload');
    }
  }

  String _errorMessage({
    required String fallback,
    required http.Response response,
  }) {
    switch (response.statusCode) {
      case 400:
        return _bodyMessage(response) ?? 'Invalid face image.';
      case 401:
        return 'Unauthorized. Please sign in again.';
      case 403:
        return 'Admin access required to register a face.';
      case 404:
        return 'Profile not found.';
    }

    return _bodyMessage(response) ?? '$fallback (${response.statusCode})';
  }

  String? _bodyMessage(http.Response response) {
    if (response.body.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message =
            decoded['message'] ?? decoded['detail'] ?? decoded['error'];
        return message?.toString();
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
