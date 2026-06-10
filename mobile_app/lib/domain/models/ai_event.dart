class AiEvent {
  final int id;
  final String eventType;
  final double? confidenceScore;
  final String? imagePath;
  final bool isAcknowledged;
  final DateTime? timestamp;
  final int? premiseId;
  final int? profileId;

  const AiEvent({
    required this.id,
    required this.eventType,
    this.confidenceScore,
    this.imagePath,
    required this.isAcknowledged,
    this.timestamp,
    this.premiseId,
    this.profileId,
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
    );
  }

  static double? _doubleFromJson(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }
}
