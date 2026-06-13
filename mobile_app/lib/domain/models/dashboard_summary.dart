import 'ai_event.dart';

class DashboardSummary {
  final String systemStatus;
  final String cameraStatus;
  final int knownPersonTodayCount;
  final int unknownPersonTodayCount;
  final int unacknowledgedCount;
  final List<EventTrendPoint> eventTrend;
  final EventTypeCounts eventTypeCounts;
  final AiEvent? latestCriticalEvent;

  const DashboardSummary({
    required this.systemStatus,
    required this.cameraStatus,
    required this.knownPersonTodayCount,
    required this.unknownPersonTodayCount,
    required this.unacknowledgedCount,
    required this.eventTrend,
    required this.eventTypeCounts,
    this.latestCriticalEvent,
  });

  factory DashboardSummary.empty() {
    return const DashboardSummary(
      systemStatus: 'unknown',
      cameraStatus: 'unknown',
      knownPersonTodayCount: 0,
      unknownPersonTodayCount: 0,
      unacknowledgedCount: 0,
      eventTrend: [],
      eventTypeCounts: EventTypeCounts.empty(),
    );
  }

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final latestCriticalEvent = json['latest_critical_event'];

    return DashboardSummary(
      systemStatus: json['system_status']?.toString() ?? 'unknown',
      cameraStatus: json['camera_status']?.toString() ?? 'unknown',
      knownPersonTodayCount: _intFromJson(json['known_person_today_count']),
      unknownPersonTodayCount: _intFromJson(json['unknown_person_today_count']),
      unacknowledgedCount: _intFromJson(json['unacknowledged_count']),
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
    );
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
  final int blacklistedPerson;
  final int other;

  const EventTypeCounts({
    required this.knownPerson,
    required this.unknownPerson,
    required this.blacklistedPerson,
    required this.other,
  });

  const EventTypeCounts.empty()
    : knownPerson = 0,
      unknownPerson = 0,
      blacklistedPerson = 0,
      other = 0;

  factory EventTypeCounts.fromJson(Map<String, dynamic> json) {
    return EventTypeCounts(
      knownPerson: DashboardSummary._intFromJson(json['known_person']),
      unknownPerson: DashboardSummary._intFromJson(json['unknown_person']),
      blacklistedPerson: DashboardSummary._intFromJson(
        json['blacklisted_person'],
      ),
      other: DashboardSummary._intFromJson(json['other']),
    );
  }

  int get total => knownPerson + unknownPerson + blacklistedPerson + other;
}
