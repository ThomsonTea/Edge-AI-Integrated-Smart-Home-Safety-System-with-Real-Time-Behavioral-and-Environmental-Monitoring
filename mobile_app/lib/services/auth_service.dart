import 'package:http/http.dart' as http;
import 'dart:convert';
import '../domain/models/login_result.dart';
import '../config/app_config.dart';

class AuthService {
  final String baseUrl = AppConfig.apiBaseUrl;

  // Login function to authenticate user and get token
  Future<LoginResult> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/profile/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
        }),
      );

      final decoded = jsonDecode(response.body);
      
      if (response.statusCode != 200) {
        throw Exception('Login failed: ${decoded.toString()}');
      }

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Invalid login response format');
      }

      final token = decoded['token'];
      if (token == null || token.toString().isEmpty) {
        throw Exception('Login failed: token missing from server response');
      }

      return LoginResult(
        token: token.toString(),
        raw: decoded,
      );
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }
}