class RetentionSettings {
  final int premiseId;
  final bool autoDeleteImages;
  final int imageRetentionDays;
  final int eventRetentionDays;
  final int sensorRetentionDays;
  final bool preserveUnacknowledged;
  final bool preserveCritical;

  const RetentionSettings({
    required this.premiseId,
    required this.autoDeleteImages,
    required this.imageRetentionDays,
    required this.eventRetentionDays,
    required this.sensorRetentionDays,
    required this.preserveUnacknowledged,
    required this.preserveCritical,
  });

  factory RetentionSettings.fromJson(Map<String, dynamic> json) {
    return RetentionSettings(
      premiseId: int.tryParse(json['premise_id']?.toString() ?? '') ?? 0,
      autoDeleteImages: json['auto_delete_images'] == true,
      imageRetentionDays:
          int.tryParse(json['image_retention_days']?.toString() ?? '') ?? 30,
      eventRetentionDays:
          int.tryParse(json['event_retention_days']?.toString() ?? '') ?? 90,
      sensorRetentionDays:
          int.tryParse(json['sensor_retention_days']?.toString() ?? '') ?? 30,
      preserveUnacknowledged: json['preserve_unacknowledged'] != false,
      preserveCritical: json['preserve_critical'] != false,
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'auto_delete_images': autoDeleteImages,
      'image_retention_days': imageRetentionDays,
      'event_retention_days': eventRetentionDays,
      'sensor_retention_days': sensorRetentionDays,
      'preserve_unacknowledged': preserveUnacknowledged,
      'preserve_critical': preserveCritical,
    };
  }

  RetentionSettings copyWith({
    bool? autoDeleteImages,
    int? imageRetentionDays,
    int? eventRetentionDays,
    int? sensorRetentionDays,
    bool? preserveUnacknowledged,
    bool? preserveCritical,
  }) {
    return RetentionSettings(
      premiseId: premiseId,
      autoDeleteImages: autoDeleteImages ?? this.autoDeleteImages,
      imageRetentionDays: imageRetentionDays ?? this.imageRetentionDays,
      eventRetentionDays: eventRetentionDays ?? this.eventRetentionDays,
      sensorRetentionDays: sensorRetentionDays ?? this.sensorRetentionDays,
      preserveUnacknowledged:
          preserveUnacknowledged ?? this.preserveUnacknowledged,
      preserveCritical: preserveCritical ?? this.preserveCritical,
    );
  }
}

class RetentionCleanupResult {
  final int eventsDeleted;
  final int sensorReadingsDeleted;
  final int imagesDeleted;
  final int imageReferencesCleared;
  final int imageDeleteFailures;

  const RetentionCleanupResult({
    required this.eventsDeleted,
    required this.sensorReadingsDeleted,
    required this.imagesDeleted,
    required this.imageReferencesCleared,
    required this.imageDeleteFailures,
  });

  factory RetentionCleanupResult.fromJson(Map<String, dynamic> json) {
    int read(String key) => int.tryParse(json[key]?.toString() ?? '') ?? 0;

    return RetentionCleanupResult(
      eventsDeleted: read('events_deleted'),
      sensorReadingsDeleted: read('sensor_readings_deleted'),
      imagesDeleted: read('images_deleted'),
      imageReferencesCleared: read('image_references_cleared'),
      imageDeleteFailures: read('image_delete_failures'),
    );
  }
}
