import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';
import 'token_service.dart';

class AlertService {
  final String baseUrl = AppConfig.apiBaseUrl;
  final _tokenService = TokenService();
  
  // Fetch recent AI detections
  Future<List<dynamic>> fetchAlerts() async {
    try {
      final token = await _tokenService.getToken();

      if (token == null || token.isEmpty || token == 'null') {
        throw Exception('Invalid auth token');
      }

      final response = await http.get(
        Uri.parse('$baseUrl/ai_events'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token.trim()}', 
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is! List) {
          throw Exception('Unexpected response format');
        }

        return data;
      } else {
        throw Exception('Failed to load alerts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}