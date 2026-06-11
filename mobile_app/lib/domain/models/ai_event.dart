class AiEvent {
  final int id;
  final String eventType;
  final double? confidenceScore;
  final String? imagePath;
  final bool isAcknowledged;
  final DateTime? timestamp;
  final int? premiseId;
  final int? profileId;
  final String? premiseName;
  final String? profileName;

  const AiEvent({
    required this.id,
    required this.eventType,
    this.confidenceScore,
    this.imagePath,
    required this.isAcknowledged,
    this.timestamp,
    this.premiseId,
    this.profileId,
    this.premiseName,
    this.profileName,
  });

  factory AiEvent.fromJson(Map<String, dynamic> json) {
    return AiEvent(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      eventType:
          json['event_type']?.toString() ??
          json['type']?.toString() ??
          'Unknown Alert',
      confidenceScore: _doubleFromJson(json['confidence_score']),
      imagePath: json['image_path']?.toString(),
      isAcknowledged: json['is_acknowledged'] == true,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? ''),
      premiseId: int.tryParse(json['premise_id']?.toString() ?? ''),
      profileId: int.tryParse(json['profile_id']?.toString() ?? ''),
      premiseName: _stringFromJson(json['premise_name']),
      profileName: _stringFromJson(json['profile_name']),
    );
  }

  bool get isKnownPerson => eventType == 'known_person';

  bool get isUnknownPerson => eventType == 'unknown_person';

  String get displayType {
    return switch (eventType) {
      'known_person' => 'Known Person',
      'unknown_person' => 'Unknown Person',
      'person_detected' => 'Person Detected',
      _ => _titleCase(eventType),
    };
  }

  String get confidenceDisplay {
    final value = confidenceScore;

    if (value == null) {
      return 'Confidence unavailable';
    }

    final percent = value <= 1 ? value * 100 : value;
    return '${percent.toStringAsFixed(1)}% confidence';
  }

  String get profileDisplay {
    final name = profileName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    if (profileId != null) {
      return 'Profile ID: $profileId';
    }

    return 'Not assigned';
  }

  String get premiseDisplay {
    final name = premiseName?.trim();

    if (name != null && name.isNotEmpty) {
      return name;
    }

    if (premiseId != null) {
      return 'Premise ID: $premiseId';
    }

    return 'Not assigned';
  }

  String get recognitionSummary {
    if (isKnownPerson) {
      if (profileName != null || profileId != null) {
        return 'Known Person: $profileDisplay';
      }

      return 'Registered person detected';
    }

    if (isUnknownPerson) {
      return 'Unregistered person detected';
    }

    return displayType;
  }

  static double? _doubleFromJson(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String? _stringFromJson(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  static String _titleCase(String value) {
    final normalized = value.replaceAll('_', ' ').trim();

    if (normalized.isEmpty) {
      return 'Unknown Alert';
    }

    return normalized
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }
}
