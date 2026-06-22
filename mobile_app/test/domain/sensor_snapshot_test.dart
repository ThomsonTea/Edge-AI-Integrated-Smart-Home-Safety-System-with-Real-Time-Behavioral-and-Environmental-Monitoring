import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_security_system/domain/models/sensor_snapshot.dart';

void main() {
  test('parses connected sensor snapshot response', () {
    final snapshot = SensorSnapshot.fromJson({
      'status': 'connected',
      'temperature': 30.7,
      'humidity': 70,
      'gas': 966,
      'last_updated': '2026-06-22T12:00:00Z',
    });

    expect(snapshot.isConnected, isTrue);
    expect(snapshot.hasCompleteReadings, isTrue);
    expect(snapshot.temperature, 30.7);
    expect(snapshot.humidity, 70.0);
    expect(snapshot.gas, 966);
    expect(
      snapshot.lastUpdated?.toUtc().toIso8601String(),
      '2026-06-22T12:00:00.000Z',
    );
  });

  test('handles disconnected fallback snapshot', () {
    const snapshot = SensorSnapshot.offline();

    expect(snapshot.isConnected, isFalse);
    expect(snapshot.hasCompleteReadings, isFalse);
    expect(snapshot.lastUpdated, isNull);
  });
}
