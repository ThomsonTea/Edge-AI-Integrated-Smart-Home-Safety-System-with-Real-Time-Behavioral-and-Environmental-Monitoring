import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../domain/models/login_result.dart';
import '../config/app_config.dart';
import 'token_service.dart';

class AuthService {
  final String baseUrl;
  final TokenService _tokenService;
  final http.Client _client;

  AuthService({
    String? baseUrl,
    TokenService? tokenService,
    http.Client? client,
  }) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
       _tokenService = tokenService ?? TokenService(),
       _client = client ?? http.Client();

  // Login function to authenticate user and get token
  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/profile/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      return _loginResultFromResponse(response);
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  Future<LoginResult> faceLogin({required File imageFile}) async {
    if (!await imageFile.exists()) {
      throw Exception('Selected face image does not exist');
    }

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/auth/face-login'),
    );

    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return _loginResultFromResponse(response);
    } catch (e) {
      throw Exception('Face login error: $e');
    }
  }

  Future<Map<String, dynamic>> verifyMe() async {
    final token = await _tokenService.getToken();

    if (token == null || token.isEmpty || token == 'null') {
      throw Exception('Invalid auth token');
    }

    final response = await _client.get(
      Uri.parse('$baseUrl/me'),
      headers: {'Authorization': 'Bearer ${token.trim()}'},
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      throw Exception('Invalid /me response format');
    }

    throw Exception(
      _errorMessage(response, fallback: 'Token validation failed'),
    );
  }

  LoginResult _loginResultFromResponse(http.Response response) {
    final decoded = _decodeBody(response);

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, decoded: decoded));
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid login response format');
    }

    final token = decoded['token'];
    if (token == null || token.toString().isEmpty) {
      throw Exception('Login failed: token missing from server response');
    }

    return LoginResult(token: token.toString(), raw: decoded);
  }

  dynamic _decodeBody(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  String _errorMessage(
    http.Response response, {
    dynamic decoded,
    String fallback = 'Login failed',
  }) {
    final body = decoded ?? _decodeBody(response);

    if (body is Map<String, dynamic>) {
      final message = body['detail'] ?? body['message'] ?? body['error'];
      if (message != null) {
        return message.toString();
      }
    }

    return '$fallback (${response.statusCode})';
  }
}
