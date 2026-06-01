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
}
