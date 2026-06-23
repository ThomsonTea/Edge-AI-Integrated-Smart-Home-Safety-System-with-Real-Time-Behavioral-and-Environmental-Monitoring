import 'ai_event.dart';

class DashboardSummary {
  final bool backendOnline;
  final bool cameraOnline;
  final bool aiDetectionActive;
  final bool sensorOnline;
  final String sensorStatus;
  final String systemStatus;
  final String cameraStatus;
  final int knownPersonTodayCount;
  final int unknownPersonTodayCount;
  final int fallTodayCount;
  final int safetyAlertTodayCount;
  final int environmentAlertTodayCount;
  final int unacknowledgedCount;
  final int criticalAlertCount;
  final int unacknowledgedCriticalCount;
  final List<EventTrendPoint> eventTrend;
  final EventTypeCounts eventTypeCounts;
  final AiEvent? latestCriticalEvent;
  final AiEvent? latestDetection;

  const DashboardSummary({
    required this.backendOnline,
    required this.cameraOnline,
    required this.aiDetectionActive,
    required this.sensorOnline,
    required this.sensorStatus,
    required this.systemStatus,
    required this.cameraStatus,
    required this.knownPersonTodayCount,
    required this.unknownPersonTodayCount,
    required this.fallTodayCount,
    required this.safetyAlertTodayCount,
    required this.environmentAlertTodayCount,
    required this.unacknowledgedCount,
    required this.criticalAlertCount,
    required this.unacknowledgedCriticalCount,
    required this.eventTrend,
    required this.eventTypeCounts,
    this.latestCriticalEvent,
    this.latestDetection,
  });

  factory DashboardSummary.empty() {
    return const DashboardSummary(
      backendOnline: false,
      cameraOnline: false,
      aiDetectionActive: false,
      sensorOnline: false,
      sensorStatus: 'unknown',
      systemStatus: 'unknown',
      cameraStatus: 'unknown',
      knownPersonTodayCount: 0,
      unknownPersonTodayCount: 0,
      fallTodayCount: 0,
      safetyAlertTodayCount: 0,
      environmentAlertTodayCount: 0,
      unacknowledgedCount: 0,
      criticalAlertCount: 0,
      unacknowledgedCriticalCount: 0,
      eventTrend: [],
      eventTypeCounts: EventTypeCounts.empty(),
    );
  }

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final latestCriticalEvent = json['latest_critical_event'];
    final latestDetection = json['latest_detection'];
    final cameraStatus = json['camera_status']?.toString() ?? 'unknown';

    return DashboardSummary(
      backendOnline: _boolFromJson(json['backend_online'], fallback: true),
      cameraOnline: _boolFromJson(
        json['camera_online'],
        fallback: cameraStatus == 'online',
      ),
      aiDetectionActive: _boolFromJson(json['ai_detection_active']),
      sensorOnline: _boolFromJson(json['sensor_online']),
      sensorStatus: json['sensor_status']?.toString() ?? 'unknown',
      systemStatus: json['system_status']?.toString() ?? 'unknown',
      cameraStatus: cameraStatus,
      knownPersonTodayCount: _intFromJson(json['known_person_today_count']),
      unknownPersonTodayCount: _intFromJson(json['unknown_person_today_count']),
      fallTodayCount: _intFromJson(json['fall_today_count']),
      safetyAlertTodayCount: _intFromJson(
        json['safety_alert_today_count'] ?? json['fall_today_count'],
      ),
      environmentAlertTodayCount: _intFromJson(
        json['environment_alert_today_count'],
      ),
      unacknowledgedCount: _intFromJson(json['unacknowledged_count']),
      criticalAlertCount: _intFromJson(json['critical_alert_count']),
      unacknowledgedCriticalCount: _intFromJson(
        json['unacknowledged_critical_count'],
      ),
      eventTrend: (json['event_trend'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(EventTrendPoint.fromJson)
          .toList(),
      eventTypeCounts: EventTypeCounts.fromJson(
        json['event_type_counts'] is Map<String, dynamic>
            ? json['event_type_counts'] as Map<String, dynamic>
            : const {},
      ),
      latestCriticalEvent: latestCriticalEvent is Map<String, dynamic>
          ? AiEvent.fromJson(latestCriticalEvent)
          : null,
      latestDetection: latestDetection is Map<String, dynamic>
          ? AiEvent.fromJson(latestDetection)
          : null,
    );
  }

  static bool _boolFromJson(dynamic value, {bool fallback = false}) {
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return fallback;
  }

  static int _intFromJson(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class EventTrendPoint {
  final String label;
  final int count;

  const EventTrendPoint({required this.label, required this.count});

  factory EventTrendPoint.fromJson(Map<String, dynamic> json) {
    return EventTrendPoint(
      label: json['label']?.toString() ?? '',
      count: DashboardSummary._intFromJson(json['count']),
    );
  }
}

class EventTypeCounts {
  final int knownPerson;
  final int unknownPerson;
  final int other;

  const EventTypeCounts({
    required this.knownPerson,
    required this.unknownPerson,
    required this.other,
  });

  const EventTypeCounts.empty() : knownPerson = 0, unknownPerson = 0, other = 0;

  factory EventTypeCounts.fromJson(Map<String, dynamic> json) {
    return EventTypeCounts(
      knownPerson: DashboardSummary._intFromJson(json['known_person']),
      unknownPerson: DashboardSummary._intFromJson(json['unknown_person']),
      other: DashboardSummary._intFromJson(json['other']),
    );
  }

  int get total => knownPerson + unknownPerson + other;
}
