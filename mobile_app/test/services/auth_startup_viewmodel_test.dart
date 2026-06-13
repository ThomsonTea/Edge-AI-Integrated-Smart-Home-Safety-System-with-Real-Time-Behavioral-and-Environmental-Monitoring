import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_security_system/services/auth_service.dart';
import 'package:smart_home_security_system/services/token_service.dart';
import 'package:smart_home_security_system/viewmodels/auth_startup_viewmodel.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({required this.shouldVerify});

  final bool shouldVerify;

  @override
  Future<Map<String, dynamic>> verifyMe() async {
    if (!shouldVerify) {
      throw Exception('Token expired');
    }

    return {
      'message': 'Token is valid',
      'user': {'user_id': 1},
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTokenService implements TokenService {
  bool deleted = false;

  @override
  Future<void> deleteToken() async {
    deleted = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('valid /me response authenticates startup', () async {
    final tokenService = FakeTokenService();
    final viewModel = AuthStartupViewModel(
      authService: FakeAuthService(shouldVerify: true),
      tokenService: tokenService,
    );

    await viewModel.checkSession();

    expect(viewModel.state, AuthStartupState.authenticated);
    expect(tokenService.deleted, isFalse);
  });

  test('invalid /me response clears token and shows login', () async {
    final tokenService = FakeTokenService();
    final viewModel = AuthStartupViewModel(
      authService: FakeAuthService(shouldVerify: false),
      tokenService: tokenService,
    );

    await viewModel.checkSession();

    expect(viewModel.state, AuthStartupState.unauthenticated);
    expect(tokenService.deleted, isTrue);
  });
}
