import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class TokenService {
  final _storage = const FlutterSecureStorage();

  Future<String?> getToken() async {
    return await _storage.read(key: AppConfig.jwtTokenKey);
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: AppConfig.jwtTokenKey, value: token);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: AppConfig.jwtTokenKey);
  }

  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty && token != 'null';
  }

  Future<String?> getCurrentUserId() async {
    final token = await getToken();
    if (token == null || token.isEmpty || token == 'null') {
      return null;
    }

    final payload = _decodeJwtPayload(token);
    return payload?['user_id']?.toString();
  }

  Future<String?> getCurrentUserRole() async {
    final token = await getToken();
    if (token == null || token.isEmpty || token == 'null') {
      return null;
    }

    final payload = _decodeJwtPayload(token);
    return payload?['role']?.toString();
  }

  Map<String, dynamic>? _decodeJwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }

    try {
      final normalizedPayload = base64Url.normalize(parts[1]);
      final payloadJson = utf8.decode(base64Url.decode(normalizedPayload));
      final payload = jsonDecode(payloadJson);

      if (payload is Map<String, dynamic>) {
        return payload;
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}
