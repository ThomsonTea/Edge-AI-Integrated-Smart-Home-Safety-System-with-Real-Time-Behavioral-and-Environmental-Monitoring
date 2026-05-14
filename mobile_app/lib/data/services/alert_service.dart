import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class AlertService {
  final String baseUrl = 'https://api.philous.me/api/dev';
  final storage = const FlutterSecureStorage();
  
  // Fetch recent AI detections
  Future<List<dynamic>> fetchAlerts() async {
    try {
      // 1. Get the VIP pass (JWT) from storage
      final token = await storage.read(key: 'jwt_token');

      if (token == null || token == 'null' || token.isEmpty) {
        throw Exception('Invalid auth token');
      }

      // 2. Make the GET request to your FastAPI backend
      // NOTE: Make sure you create a GET route for /ai_events in your Python code!
      final response = await http.get(
        Uri.parse('$baseUrl/ai_events'), 
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${token?.trim()}', 
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

  // Logout function to delete the token
  Future<void> logout() async {
    await storage.delete(key: 'jwt_token');
  }
}