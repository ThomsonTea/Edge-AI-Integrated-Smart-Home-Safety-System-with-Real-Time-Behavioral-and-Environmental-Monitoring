class RegisterUserRequest {
  final String username;
  final String email;
  final String phoneNumber;
  final String password;
  final String role;

  const RegisterUserRequest({
    required this.username,
    required this.email,
    required this.phoneNumber,
    required this.password,
    required this.role,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'email': email,
      'phone_number': phoneNumber,
      'password': password,
      'group_type': role,
    };
  }
}
