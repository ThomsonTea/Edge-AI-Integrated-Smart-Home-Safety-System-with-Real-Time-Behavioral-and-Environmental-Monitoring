import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../domain/models/dashboard_summary.dart';
import 'token_service.dart';

class DashboardService {
  final String baseUrl;
  final TokenService _tokenService;
  final http.Client _client;

  DashboardService({
    String? baseUrl,
    TokenService? tokenService,
    http.Client? client,
  }) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
       _tokenService = tokenService ?? TokenService(),
       _client = client ?? http.Client();

  Future<DashboardSummary> fetchSummary() async {
    final response = await _get(Uri.parse('$baseUrl/dashboard/summary'));

    if (response.statusCode == 200) {
      final decoded = _decodeJson(response);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected dashboard summary response format');
      }

      return DashboardSummary.fromJson(decoded);
    }

    throw Exception(
      _errorMessage(
        fallback: 'Failed to fetch dashboard summary',
        response: response,
      ),
    );
  }

  Future<http.Response> _get(Uri uri) async {
    final headers = await _authorizedHeaders();

    try {
      return await _client.get(uri, headers: headers);
    } catch (error) {
      throw Exception('Network error: $error');
    }
  }

  Future<Map<String, String>> _authorizedHeaders() async {
    final token = await _tokenService.getToken();

    if (token == null || token.isEmpty || token == 'null') {
      throw Exception('Invalid auth token');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
    };
  }

  dynamic _decodeJson(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid dashboard summary payload');
    }
  }

  String _errorMessage({
    required String fallback,
    required http.Response response,
  }) {
    switch (response.statusCode) {
      case 401:
        return 'Unauthorized. Please sign in again.';
      case 403:
        return 'You are not allowed to access this dashboard.';
      case 404:
        return 'Dashboard data not found.';
    }

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
