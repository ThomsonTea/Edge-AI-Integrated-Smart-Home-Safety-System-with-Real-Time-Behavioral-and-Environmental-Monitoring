import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../domain/models/user_profile.dart';
import 'token_service.dart';

class ProfileService {
  final String baseUrl;
  final TokenService _tokenService;
  final http.Client _client;

  ProfileService({
    String? baseUrl,
    TokenService? tokenService,
    http.Client? client,
  }) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
       _tokenService = tokenService ?? TokenService(),
       _client = client ?? http.Client();

  Future<UserProfile> fetchProfile() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/profile/me'),
      headers: await _authorizedHeaders(),
    );

    if (response.statusCode == 200) {
      return _profileFromResponse(response);
    }

    throw Exception(
      _errorMessage(fallback: 'Failed to load profile', response: response),
    );
  }

  Future<UserProfile> updateProfile({
    required String username,
    required String email,
    String? phoneNumber,
  }) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/profile/me'),
      headers: await _authorizedHeaders(),
      body: jsonEncode({
        'username': username,
        'email': email,
        'phone_number': phoneNumber,
      }),
    );

    if (response.statusCode == 200) {
      return _profileFromResponse(response);
    }

    throw Exception(
      _errorMessage(fallback: 'Failed to update profile', response: response),
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/profile/me/password'),
      headers: await _authorizedHeaders(),
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      }),
    );

    if (response.statusCode == 200) {
      return;
    }

    throw Exception(
      _errorMessage(fallback: 'Failed to change password', response: response),
    );
  }

  Future<UserProfile> uploadProfilePicture(File imageFile) async {
    return _uploadImage(
      endpoint: '$baseUrl/profile/me/profile-picture',
      imageFile: imageFile,
      fallback: 'Failed to upload profile picture',
    );
  }

  Future<UserProfile> registerFace(File imageFile) async {
    return _uploadImage(
      endpoint: '$baseUrl/profile/me/face',
      imageFile: imageFile,
      fallback: 'Failed to register face',
    );
  }

  Future<UserProfile> _uploadImage({
    required String endpoint,
    required File imageFile,
    required String fallback,
  }) async {
    if (!await imageFile.exists()) {
      throw Exception('Selected image does not exist');
    }

    final request = http.MultipartRequest('POST', Uri.parse(endpoint));
    request.headers.addAll(await _authorizationOnlyHeaders());
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = _decodeJson(response);

        if (decoded is Map<String, dynamic>) {
          final profile = decoded['profile'];
          if (profile is Map<String, dynamic>) {
            return UserProfile.fromJson(profile);
          }
        }

        throw Exception('Unexpected profile upload response format');
      }

      throw Exception(_errorMessage(fallback: fallback, response: response));
    } catch (error) {
      if (error is Exception) rethrow;
      throw Exception('Network error: $error');
    }
  }

  Future<Map<String, String>> _authorizedHeaders() async {
    final headers = await _authorizationOnlyHeaders();
    return {...headers, 'Content-Type': 'application/json'};
  }

  Future<Map<String, String>> _authorizationOnlyHeaders() async {
    final token = await _tokenService.getToken();

    if (token == null || token.isEmpty || token == 'null') {
      throw Exception('Invalid auth token');
    }

    return {'Authorization': 'Bearer ${token.trim()}'};
  }

  UserProfile _profileFromResponse(http.Response response) {
    final decoded = _decodeJson(response);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected profile response format');
    }

    return UserProfile.fromJson(decoded);
  }

  dynamic _decodeJson(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid profile response payload');
    }
  }

  String _errorMessage({
    required String fallback,
    required http.Response response,
  }) {
    if (response.body.isEmpty) {
      return '$fallback (${response.statusCode})';
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message =
            decoded['message'] ?? decoded['detail'] ?? decoded['error'];
        if (message != null) return message.toString();
      }
    } catch (_) {
      return '$fallback (${response.statusCode})';
    }

    return '$fallback (${response.statusCode})';
  }
}
