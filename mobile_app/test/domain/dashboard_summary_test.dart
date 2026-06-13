import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_security_system/domain/models/dashboard_summary.dart';

void main() {
  test('parses dashboard summary response', () {
    final summary = DashboardSummary.fromJson({
      'system_status': 'critical_alert',
      'camera_status': 'online',
      'known_person_today_count': 3,
      'unknown_person_today_count': 2,
      'unacknowledged_count': 4,
      'event_trend': [
        {'label': '2026-06-13', 'count': 5},
      ],
      'event_type_counts': {
        'known_person': 3,
        'unknown_person': 2,
        'blacklisted_person': 1,
        'other': 4,
      },
      'latest_critical_event': {
        'id': 9,
        'event_type': 'unknown_person',
        'timestamp': '2026-06-13T10:00:00Z',
        'confidence_score': 82.4,
        'is_acknowledged': false,
      },
    });

    expect(summary.systemStatus, 'critical_alert');
    expect(summary.cameraStatus, 'online');
    expect(summary.knownPersonTodayCount, 3);
    expect(summary.unknownPersonTodayCount, 2);
    expect(summary.unacknowledgedCount, 4);
    expect(summary.eventTrend.single.count, 5);
    expect(summary.eventTypeCounts.total, 10);
    expect(summary.latestCriticalEvent?.id, 9);
  });
}
