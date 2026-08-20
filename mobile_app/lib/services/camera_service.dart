import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../domain/models/security_camera.dart';
import 'token_service.dart';

class CameraService {
  final String baseUrl;
  final TokenService _tokens;
  final http.Client _client;
  CameraService({
    String? baseUrl,
    TokenService? tokenService,
    http.Client? client,
  }) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
       _tokens = tokenService ?? TokenService(),
       _client = client ?? http.Client();
  Future<List<SecurityCamera>> fetchCameras() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/camera'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) throw Exception(_error(response));
    final value = jsonDecode(response.body);
    if (value is! List) throw Exception('Unexpected camera response format');
    return value
        .whereType<Map<String, dynamic>>()
        .map(SecurityCamera.fromJson)
        .toList();
  }

  Future<void> addCamera(Map<String, dynamic> payload) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/camera'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode != 201) throw Exception(_error(response));
  }

  Future<void> updateCamera(int id, Map<String, dynamic> payload) async {
    final response = await _client.patch(
      Uri.parse('$baseUrl/camera/$id'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) throw Exception(_error(response));
  }

  Future<List<DiscoveredCamera>> discoverCameras() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/camera/discover'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) throw Exception(_error(response));
    final value = jsonDecode(response.body);
    if (value is! Map || value['cameras'] is! List) {
      throw Exception('Unexpected camera discovery response');
    }
    return (value['cameras'] as List)
        .whereType<Map<String, dynamic>>()
        .map(DiscoveredCamera.fromJson)
        .toList();
  }

  Future<String> resolveStream({
    required String serviceUrl,
    required String username,
    required String password,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/camera/resolve-stream'),
      headers: await _headers(),
      body: jsonEncode({
        'service_url': serviceUrl,
        'username': username,
        'password': password,
      }),
    );
    if (response.statusCode != 200) throw Exception(_error(response));
    final value = jsonDecode(response.body);
    if (value is! Map || value['stream_url'] == null) {
      throw Exception('The camera did not provide a stream URL');
    }
    return value['stream_url'].toString();
  }

  Future<void> testConnection(Map<String, dynamic> payload) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/camera/test-connection'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    if (response.statusCode != 200) throw Exception(_error(response));
  }

  Future<void> deleteCamera(int id) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/camera/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 204) throw Exception(_error(response));
  }

  Future<Map<String, String>> _headers() async {
    final token = await _tokens.getToken();
    if (token == null || token.isEmpty || token == 'null') {
      throw Exception('Invalid auth token');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
    };
  }

  String _error(http.Response response) {
    try {
      final value = jsonDecode(response.body);
      if (value is Map && value['detail'] != null) {
        return value['detail'].toString();
      }
    } catch (_) {}
    return 'Camera request failed (${response.statusCode})';
  }
}
