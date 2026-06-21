import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_security_system/domain/models/dashboard_summary.dart';

void main() {
  test('parses dashboard summary response', () {
    final summary = DashboardSummary.fromJson({
      'backend_online': true,
      'camera_online': true,
      'ai_detection_active': true,
      'sensor_online': false,
      'sensor_status': 'not_configured',
      'system_status': 'critical_alert',
      'camera_status': 'online',
      'known_person_today_count': 3,
      'unknown_person_today_count': 2,
      'fall_today_count': 1,
      'environment_alert_today_count': 0,
      'unacknowledged_count': 4,
      'critical_alert_count': 2,
      'unacknowledged_critical_count': 1,
      'event_trend': [
        {'label': '2026-06-13', 'count': 5},
      ],
      'event_type_counts': {'known_person': 3, 'unknown_person': 2, 'other': 4},
      'latest_critical_event': {
        'id': 9,
        'event_type': 'unknown_person',
        'timestamp': '2026-06-13T10:00:00Z',
        'confidence_score': 82.4,
        'is_acknowledged': false,
      },
      'latest_detection': {
        'id': 10,
        'event_type': 'known_person',
        'timestamp': '2026-06-13T10:05:00Z',
        'profile_name': 'John Tan',
        'premise_name': 'Living Room',
        'is_acknowledged': true,
      },
    });

    expect(summary.backendOnline, isTrue);
    expect(summary.cameraOnline, isTrue);
    expect(summary.aiDetectionActive, isTrue);
    expect(summary.sensorOnline, isFalse);
    expect(summary.sensorStatus, 'not_configured');
    expect(summary.systemStatus, 'critical_alert');
    expect(summary.cameraStatus, 'online');
    expect(summary.knownPersonTodayCount, 3);
    expect(summary.unknownPersonTodayCount, 2);
    expect(summary.fallTodayCount, 1);
    expect(summary.environmentAlertTodayCount, 0);
    expect(summary.unacknowledgedCount, 4);
    expect(summary.criticalAlertCount, 2);
    expect(summary.unacknowledgedCriticalCount, 1);
    expect(summary.eventTrend.single.count, 5);
    expect(summary.eventTypeCounts.total, 9);
    expect(summary.latestCriticalEvent?.id, 9);
    expect(summary.latestDetection?.profileName, 'John Tan');
  });
}
