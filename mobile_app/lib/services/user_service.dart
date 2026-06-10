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
      Uri.parse('$baseUrl/profile/profiles'),
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
      Uri.parse('$baseUrl/profile/register'),
      headers: await _authorizedHeaders(requireToken: false),
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
      Uri.parse('$baseUrl/profile/profiles/$id'),
      headers: await _authorizedHeaders(),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        _errorMessage(fallback: 'Failed to delete user', response: response),
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
