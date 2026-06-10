class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phoneNumber;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phoneNumber,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name:
          json['username']?.toString() ??
          json['full_name']?.toString() ??
          json['name']?.toString() ??
          '',
      email: json['email']?.toString() ?? '',
      role: json['group_type']?.toString() ?? json['role']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString(),
    );
  }
}
