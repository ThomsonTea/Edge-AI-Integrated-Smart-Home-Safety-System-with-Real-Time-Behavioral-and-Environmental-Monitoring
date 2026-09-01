import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_security_system/config/app_config.dart';

void main() {
  test('JWT token uses the stable secure-storage key', () {
    expect(AppConfig.jwtTokenKey, 'jwt_token');
  });
}
