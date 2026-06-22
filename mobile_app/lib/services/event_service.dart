import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../domain/models/ai_event.dart';
import 'token_service.dart';

class EventService {
  final String baseUrl;
  final TokenService _tokenService;
  final http.Client _client;

  EventService({
    String? baseUrl,
    TokenService? tokenService,
    http.Client? client,
  }) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl,
       _tokenService = tokenService ?? TokenService(),
       _client = client ?? http.Client();

  Future<List<AiEvent>> fetchEvents({int limit = 50}) {
    return fetchEventsWithFilters(limit: limit);
  }

  Future<List<AiEvent>> fetchEventsWithFilters({
    int limit = 50,
    DateTime? startDate,
    DateTime? endDate,
    String? eventType,
    bool? isAcknowledged,
  }) async {
    final queryParameters = <String, String>{
      'limit': limit.toString(),
      if (startDate != null) 'start_date': startDate.toIso8601String(),
      if (endDate != null) 'end_date': endDate.toIso8601String(),
      if (eventType != null && eventType.isNotEmpty) 'event_type': eventType,
      if (isAcknowledged != null) 'is_acknowledged': isAcknowledged.toString(),
    };

    final response = await _get(
      Uri.parse('$baseUrl/ai_events').replace(queryParameters: queryParameters),
    );

    if (response.statusCode == 200) {
      final decoded = _decodeJson(response);

      if (decoded is! List) {
        throw Exception('Unexpected events response format');
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AiEvent.fromJson)
          .toList();
    }

    throw Exception(
      _errorMessage(fallback: 'Failed to fetch events', response: response),
    );
  }

  Future<AiEvent> fetchEventById(int id) async {
    _validateEventId(id);

    final response = await _get(Uri.parse('$baseUrl/ai_events/$id'));

    if (response.statusCode == 200) {
      return _eventFromResponse(response);
    }

    throw Exception(
      _errorMessage(fallback: 'Failed to fetch event', response: response),
    );
  }

  Future<List<Map<String, dynamic>>> fetchRecentNotificationPayloads({
    int limit = 20,
  }) async {
    final response = await _get(
      Uri.parse(
        '$baseUrl/ai_events/recent',
      ).replace(queryParameters: {'limit': limit.toString()}),
    );

    if (response.statusCode == 200) {
      final decoded = _decodeJson(response);

      if (decoded is! List) {
        throw Exception('Unexpected recent events response format');
      }

      return decoded.whereType<Map<String, dynamic>>().toList();
    }

    throw Exception(
      _errorMessage(
        fallback: 'Failed to fetch recent notifications',
        response: response,
      ),
    );
  }

  Future<AiEvent> acknowledgeEvent(int id) async {
    _validateEventId(id);

    final response = await _put(
      Uri.parse('$baseUrl/ai_events/$id/acknowledge'),
    );

    if (response.statusCode == 200) {
      return _eventFromResponse(response);
    }

    throw Exception(
      _errorMessage(
        fallback: 'Failed to acknowledge event',
        response: response,
      ),
    );
  }

  Future<List<AiEvent>> acknowledgeVisibleEvents(List<int> ids) async {
    final eventIds = ids.where((id) => id > 0).toSet().toList();
    if (eventIds.isEmpty) return const [];

    final response = await _put(
      Uri.parse('$baseUrl/ai_events/acknowledge-visible'),
      body: jsonEncode({'event_ids': eventIds}),
    );

    if (response.statusCode == 200) {
      final decoded = _decodeJson(response);

      if (decoded is! List) {
        throw Exception('Unexpected acknowledge response format');
      }

      return decoded
          .whereType<Map<String, dynamic>>()
          .map(AiEvent.fromJson)
          .toList();
    }

    throw Exception(
      _errorMessage(
        fallback: 'Failed to acknowledge visible events',
        response: response,
      ),
    );
  }

  Future<String> deleteEvent(int id) async {
    _validateEventId(id);

    final response = await _delete(Uri.parse('$baseUrl/ai_events/$id'));

    if (response.statusCode == 200) {
      final decoded = _decodeJson(response);

      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }

      return 'Event deleted successfully';
    }

    throw Exception(
      _errorMessage(fallback: 'Failed to delete event', response: response),
    );
  }

  Future<http.Response> _get(Uri uri) async {
    final headers = await _authorizedHeaders();

    try {
      return await _client.get(uri, headers: headers);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<http.Response> _put(Uri uri, {Object? body}) async {
    final headers = await _authorizedHeaders();

    try {
      return await _client.put(uri, headers: headers, body: body);
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<http.Response> _delete(Uri uri) async {
    final headers = await _authorizedHeaders();

    try {
      return await _client.delete(uri, headers: headers);
    } catch (e) {
      throw Exception('Network error: $e');
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

  AiEvent _eventFromResponse(http.Response response) {
    final decoded = _decodeJson(response);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Unexpected event response format');
    }

    return AiEvent.fromJson(decoded);
  }

  dynamic _decodeJson(http.Response response) {
    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw Exception('Invalid response payload');
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
        return 'You are not allowed to access this event.';
      case 404:
        return 'Event not found.';
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

  void _validateEventId(int id) {
    if (id <= 0) {
      throw ArgumentError.value(id, 'id', 'Event id must be greater than zero');
    }
  }
}
