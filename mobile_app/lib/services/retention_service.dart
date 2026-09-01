import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../domain/models/retention_settings.dart';
import 'token_service.dart';

class RetentionService {
  final String baseUrl;
  final TokenService _tokenService;
  final http.Client _client;

  RetentionService({
    String? baseUrl,
    TokenService? tokenService,
    http.Client? client,
  }) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
       _tokenService = tokenService ?? TokenService(),
       _client = client ?? http.Client();

  Future<RetentionSettings> fetchSettings() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/premise/settings/retention'),
      headers: await _headers(),
    );
    return _settingsResponse(response, 'Failed to load retention settings');
  }

  Future<RetentionSettings> updateSettings(RetentionSettings settings) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/premise/settings/retention'),
      headers: await _headers(),
      body: jsonEncode(settings.toUpdateJson()),
    );
    return _settingsResponse(response, 'Failed to update retention settings');
  }

  Future<RetentionCleanupResult> runCleanup() async {
    final response = await _client.post(
      Uri.parse('$baseUrl/premise/settings/retention/cleanup'),
      headers: await _headers(),
    );
    final decoded = _decode(response);
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return RetentionCleanupResult.fromJson(decoded);
    }
    throw Exception(_error(response, decoded, 'Failed to run data cleanup'));
  }

  RetentionSettings _settingsResponse(http.Response response, String fallback) {
    final decoded = _decode(response);
    if (response.statusCode == 200 && decoded is Map<String, dynamic>) {
      return RetentionSettings.fromJson(decoded);
    }
    throw Exception(_error(response, decoded, fallback));
  }

  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return null;
    }
  }

  String _error(http.Response response, dynamic decoded, String fallback) {
    if (decoded is Map<String, dynamic>) {
      final message =
          decoded['detail'] ?? decoded['message'] ?? decoded['error'];
      if (message != null) return message.toString();
    }
    return '$fallback (${response.statusCode})';
  }

  Future<Map<String, String>> _headers() async {
    final token = await _tokenService.getToken();
    if (token == null || token.isEmpty || token == 'null') {
      throw Exception('Invalid auth token');
    }
    return {
      'Authorization': 'Bearer ${token.trim()}',
      'Content-Type': 'application/json',
    };
  }
}
