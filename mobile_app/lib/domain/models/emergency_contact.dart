class EmergencyContact {
  final int id;
  final String contactName;
  final String phoneNumber;
  final String? relationship;
  final int priority;
  final bool enabled;

  const EmergencyContact({
    required this.id,
    required this.contactName,
    required this.phoneNumber,
    this.relationship,
    required this.priority,
    required this.enabled,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: _parseInt(json['id']),
      contactName: json['contact_name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      relationship: _optionalText(json['relationship']),
      priority: _parseInt(json['priority'], fallback: 1),
      enabled: json['enabled'] == true,
    );
  }

  Map<String, dynamic> toMutationJson() => {
    'contact_name': contactName,
    'phone_number': phoneNumber,
    'relationship': relationship,
    'priority': priority,
    'enabled': enabled,
  };

  EmergencyContact copyWith({
    int? id,
    String? contactName,
    String? phoneNumber,
    String? relationship,
    bool clearRelationship = false,
    int? priority,
    bool? enabled,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      contactName: contactName ?? this.contactName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      relationship: clearRelationship
          ? null
          : relationship ?? this.relationship,
      priority: priority ?? this.priority,
      enabled: enabled ?? this.enabled,
    );
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static String? _optionalText(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
