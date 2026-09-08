import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../domain/models/emergency_contact.dart';
import 'token_service.dart';

class EmergencyContactService {
  final String baseUrl;
  final TokenService _tokenService;
  final http.Client _client;

  EmergencyContactService({
    String? baseUrl,
    TokenService? tokenService,
    http.Client? client,
  }) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
       _tokenService = tokenService ?? TokenService(),
       _client = client ?? http.Client();

  Future<List<EmergencyContact>> fetchContacts() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/emergency-contacts'),
      headers: await _headers(),
    );
    final decoded = _decode(response);
    if (response.statusCode == 200 && decoded is List) {
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(EmergencyContact.fromJson)
          .toList();
    }
    throw Exception(_error(response, decoded, 'Failed to load contacts'));
  }

  Future<EmergencyContact> createContact(EmergencyContact contact) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/emergency-contacts'),
      headers: await _headers(),
      body: jsonEncode(contact.toMutationJson()),
    );
    return _contactResponse(response, 'Failed to add contact', {201});
  }

  Future<EmergencyContact> updateContact(EmergencyContact contact) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/emergency-contacts/${contact.id}'),
      headers: await _headers(),
      body: jsonEncode(contact.toMutationJson()),
    );
    return _contactResponse(response, 'Failed to update contact', {200});
  }

  Future<void> deleteContact(int id) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/emergency-contacts/$id'),
      headers: await _headers(),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      final decoded = _decode(response);
      throw Exception(_error(response, decoded, 'Failed to delete contact'));
    }
  }

  EmergencyContact _contactResponse(
    http.Response response,
    String fallback,
    Set<int> acceptedStatuses,
  ) {
    final decoded = _decode(response);
    if (acceptedStatuses.contains(response.statusCode) &&
        decoded is Map<String, dynamic>) {
      return EmergencyContact.fromJson(decoded);
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
