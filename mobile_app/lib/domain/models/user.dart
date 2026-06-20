class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? phoneNumber;
  final int? premiseId;
  final bool faceRegistered;
  final bool isPrimaryOwner;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phoneNumber,
    this.premiseId,
    this.faceRegistered = false,
    this.isPrimaryOwner = false,
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
      premiseId: _parseInt(json['premise_id']),
      faceRegistered:
          json['face_registered'] == true || json['has_face_signature'] == true,
      isPrimaryOwner: json['is_primary_owner'] == true,
    );
  }

  String get normalizedRole {
    final value = role.trim().toLowerCase().replaceAll('-', '_');

    return switch (value) {
      'owner' || 'admin' || 'administrator' => 'owner',
      'manager' || 'operator' => 'manager',
      'normal_user' ||
      'normal user' ||
      'member' ||
      'guest' ||
      'resident' => 'normal_user',
      _ => value,
    };
  }

  String get roleLabel {
    return switch (normalizedRole) {
      'owner' => 'Owner',
      'manager' => 'Manager',
      'normal_user' => 'Normal User',
      _ => role,
    };
  }

  bool get isOwner => normalizedRole == 'owner' || isPrimaryOwner;

  static int? _parseInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }
}
