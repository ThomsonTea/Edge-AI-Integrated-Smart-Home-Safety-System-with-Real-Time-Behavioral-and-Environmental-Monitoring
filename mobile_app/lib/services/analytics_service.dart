import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../domain/models/analytics_models.dart';
import 'token_service.dart';

class AnalyticsService {
  final String baseUrl;
  final TokenService _tokenService;
  final http.Client _client;

  AnalyticsService({
    String? baseUrl,
    TokenService? tokenService,
    http.Client? client,
  }) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
       _tokenService = tokenService ?? TokenService(),
       _client = client ?? http.Client();

  Future<SensorAnalytics> fetchSensorAnalytics(String range) async {
    final response = await _get(
      Uri.parse(
        '$baseUrl/analytics/sensors',
      ).replace(queryParameters: {'range': range}),
    );

    if (response.statusCode == 200) {
      final decoded = _decodeJson(response);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected sensor analytics response format');
      }
      return SensorAnalytics.fromJson(decoded);
    }

    throw Exception(
      _errorMessage(
        fallback: 'Failed to fetch sensor analytics',
        response: response,
      ),
    );
  }

  Future<EventAnalytics> fetchEventAnalytics(String range) async {
    final response = await _get(
      Uri.parse(
        '$baseUrl/analytics/events',
      ).replace(queryParameters: {'range': range}),
    );

    if (response.statusCode == 200) {
      final decoded = _decodeJson(response);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected event analytics response format');
      }
      return EventAnalytics.fromJson(decoded);
    }

    throw Exception(
      _errorMessage(
        fallback: 'Failed to fetch event analytics',
        response: response,
      ),
    );
  }

  Future<EventTrendAnalytics> fetchEventTrendAnalytics(String range) async {
    final response = await _get(
      Uri.parse(
        '$baseUrl/analytics/event-trends',
      ).replace(queryParameters: {'range': range}),
    );

    if (response.statusCode == 200) {
      final decoded = _decodeJson(response);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Unexpected event trend analytics response format');
      }
      return EventTrendAnalytics.fromJson(decoded);
    }

    throw Exception(
      _errorMessage(
        fallback: 'Failed to fetch event trend analytics',
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
      throw Exception('Invalid analytics payload');
    }
  }

  String _errorMessage({
    required String fallback,
    required http.Response response,
  }) {
    switch (response.statusCode) {
      case 400:
        return 'Unsupported analytics range.';
      case 401:
        return 'Unauthorized. Please sign in again.';
      case 403:
        return 'You are not allowed to access analytics.';
      case 404:
        return 'Analytics data not found.';
    }

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
