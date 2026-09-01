import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_security_system/domain/models/retention_settings.dart';

void main() {
  test('parses retention settings and serializes update payload', () {
    final settings = RetentionSettings.fromJson({
      'premise_id': 4,
      'auto_delete_images': true,
      'image_retention_days': 30,
      'event_retention_days': 90,
      'sensor_retention_days': 7,
      'preserve_unacknowledged': true,
      'preserve_critical': false,
    });

    expect(settings.premiseId, 4);
    expect(settings.eventRetentionDays, 90);
    expect(settings.sensorRetentionDays, 7);
    expect(settings.preserveCritical, isFalse);
    expect(settings.toUpdateJson(), {
      'auto_delete_images': true,
      'image_retention_days': 30,
      'event_retention_days': 90,
      'sensor_retention_days': 7,
      'preserve_unacknowledged': true,
      'preserve_critical': false,
    });
  });

  test('parses cleanup result counts', () {
    final result = RetentionCleanupResult.fromJson({
      'events_deleted': 2,
      'sensor_readings_deleted': 50,
      'images_deleted': 1,
      'image_references_cleared': 3,
      'image_delete_failures': 0,
    });

    expect(result.eventsDeleted, 2);
    expect(result.sensorReadingsDeleted, 50);
    expect(result.imagesDeleted, 1);
    expect(result.imageReferencesCleared, 3);
    expect(result.imageDeleteFailures, 0);
  });
}
