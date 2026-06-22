import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_security_system/domain/models/analytics_models.dart';

void main() {
  test('parses sensor analytics response', () {
    final analytics = SensorAnalytics.fromJson({
      'range': '24h',
      'points': [
        {
          'timestamp': '2026-06-22T12:00:00Z',
          'temperature': 30.7,
          'humidity': 70,
          'gas': 966,
        },
      ],
    });

    expect(analytics.range, '24h');
    expect(analytics.points.single.temperature, 30.7);
    expect(analytics.points.single.humidity, 70.0);
    expect(analytics.points.single.gas, 966);
  });

  test('parses event analytics response', () {
    final analytics = EventAnalytics.fromJson({
      'range': '7d',
      'counts': [
        {'event_type': 'known_person', 'count': 12},
        {'event_type': 'unknown_person', 'count': 3},
      ],
    });

    expect(analytics.range, '7d');
    expect(analytics.counts.first.eventType, 'known_person');
    expect(analytics.counts.first.count, 12);
    expect(analytics.hasActivity, isTrue);
  });

  test('parses event trend analytics response', () {
    final analytics = EventTrendAnalytics.fromJson({
      'range': '7d',
      'bucket': 'daily',
      'points': [
        {
          'label': 'Mon',
          'timestamp': '2026-06-22T00:00:00Z',
          'known_person': 5,
          'unknown_person': 1,
        },
      ],
    });

    expect(analytics.range, '7d');
    expect(analytics.bucket, 'daily');
    expect(analytics.points.single.label, 'Mon');
    expect(analytics.points.single.countFor('known_person'), 5);
    expect(analytics.points.single.countFor('gas_alert'), 0);
  });
}
