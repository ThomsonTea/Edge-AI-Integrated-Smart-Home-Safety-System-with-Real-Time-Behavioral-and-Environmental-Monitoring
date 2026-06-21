import '../../config/app_config.dart';

class UserProfile {
  final int id;
  final String username;
  final String email;
  final String? phoneNumber;
  final String role;
  final int? premiseId;
  final String? premiseName;
  final String? profileImagePath;
  final bool faceRegistered;
  final DateTime? lastSeen;
  final bool isPrimaryOwner;

  const UserProfile({
    required this.id,
    required this.username,
    required this.email,
    this.phoneNumber,
    required this.role,
    this.premiseId,
    this.premiseName,
    this.profileImagePath,
    required this.faceRegistered,
    this.lastSeen,
    this.isPrimaryOwner = false,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phoneNumber: _stringFromJson(json['phone_number']),
      role:
          json['role']?.toString() ??
          json['group_type']?.toString() ??
          'Resident',
      premiseId: int.tryParse(json['premise_id']?.toString() ?? ''),
      premiseName: _stringFromJson(json['premise_name']),
      profileImagePath: _stringFromJson(json['profile_image_path']),
      faceRegistered: json['face_registered'] == true,
      lastSeen: DateTime.tryParse(json['last_seen']?.toString() ?? ''),
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

  String? get profileImageUrl {
    final path = profileImagePath;
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return '${AppConfig.serverBaseUrl}$path';
  }

  static String? _stringFromJson(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
