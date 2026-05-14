class LoginResult {
  final String token;
  final Map<String, dynamic> raw;

  LoginResult({
    required this.token,
    required this.raw,
  });
}