import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../domain/dtos/register_user_request.dart';
import '../domain/models/user.dart';
import 'token_service.dart';

class UserService {
  final String baseUrl;
  final TokenService _tokenService;
  final http.Client _client;

  UserService({
    String? baseUrl,
    TokenService? tokenService,
    http.Client? client,
  }) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
       _tokenService = tokenService ?? TokenService(),
       _client = client ?? http.Client();

  Future<List<User>> fetchUsers() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/users'),
      headers: await _authorizedHeaders(),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw Exception('Unexpected users response format');
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(User.fromJson)
          .toList();
    }

    throw Exception(
      _errorMessage(fallback: 'Failed to fetch users', response: response),
    );
  }

  Future<void> registerUser(RegisterUserRequest request) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/users'),
      headers: await _authorizedHeaders(),
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(
        _errorMessage(fallback: 'Failed to register user', response: response),
      );
    }
  }

  Future<void> deleteUser({required String id}) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/users/$id'),
      headers: await _authorizedHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        _errorMessage(fallback: 'Failed to delete user', response: response),
      );
    }
  }

  Future<void> updateUser({
    required String id,
    required String username,
    required String email,
    required String phoneNumber,
    String? role,
  }) async {
    final payload = <String, String>{
      'username': username,
      'email': email,
      'phone_number': phoneNumber,
    };

    if (role != null) {
      payload['group_type'] = role;
    }

    final response = await _client.put(
      Uri.parse('$baseUrl/users/$id'),
      headers: await _authorizedHeaders(),
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
        _errorMessage(fallback: 'Failed to update user', response: response),
      );
    }
  }

  Future<void> resetPassword({
    required String id,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/users/$id/reset-password'),
      headers: await _authorizedHeaders(),
      body: jsonEncode({
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        _errorMessage(fallback: 'Failed to reset password', response: response),
      );
    }
  }

  Future<void> registerFace({
    required String id,
    required File imageFile,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/users/$id/face'),
    );

    request.headers.addAll(await _authorizationHeaders());
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception(
        _errorMessage(fallback: 'Failed to register face', response: response),
      );
    }
  }

  Future<Map<String, String>> _authorizedHeaders({
    bool requireToken = true,
  }) async {
    final token = await _tokenService.getToken();
    final headers = <String, String>{'Content-Type': 'application/json'};

    if (token != null && token.isNotEmpty && token != 'null') {
      headers['Authorization'] = 'Bearer ${token.trim()}';
      return headers;
    }

    if (requireToken) {
      throw Exception('Invalid auth token');
    }

    return headers;
  }

  Future<Map<String, String>> _authorizationHeaders() async {
    final token = await _tokenService.getToken();

    if (token != null && token.isNotEmpty && token != 'null') {
      return {'Authorization': 'Bearer ${token.trim()}'};
    }

    throw Exception('Invalid auth token');
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
        if (message != null) {
          return message.toString();
        }
      }
    } catch (_) {
      return '$fallback (${response.statusCode})';
    }

    return '$fallback (${response.statusCode})';
  }
}
