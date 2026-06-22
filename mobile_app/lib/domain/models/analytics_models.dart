class SensorTrendPoint {
  final DateTime timestamp;
  final double? temperature;
  final double? humidity;
  final int? gas;

  const SensorTrendPoint({
    required this.timestamp,
    this.temperature,
    this.humidity,
    this.gas,
  });

  factory SensorTrendPoint.fromJson(Map<String, dynamic> json) {
    return SensorTrendPoint(
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      temperature: _doubleFromJson(json['temperature']),
      humidity: _doubleFromJson(json['humidity']),
      gas: _intFromJson(json['gas']),
    );
  }

  static double? _doubleFromJson(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static int? _intFromJson(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}

class SensorAnalytics {
  final String range;
  final List<SensorTrendPoint> points;

  const SensorAnalytics({required this.range, required this.points});

  const SensorAnalytics.empty() : range = '24h', points = const [];

  factory SensorAnalytics.fromJson(Map<String, dynamic> json) {
    return SensorAnalytics(
      range: json['range']?.toString() ?? '24h',
      points: (json['points'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(SensorTrendPoint.fromJson)
          .toList(),
    );
  }
}

class EventCount {
  final String eventType;
  final int count;

  const EventCount({required this.eventType, required this.count});

  factory EventCount.fromJson(Map<String, dynamic> json) {
    return EventCount(
      eventType: json['event_type']?.toString() ?? 'unknown',
      count: SensorTrendPoint._intFromJson(json['count']) ?? 0,
    );
  }
}

class EventAnalytics {
  final String range;
  final List<EventCount> counts;

  const EventAnalytics({required this.range, required this.counts});

  const EventAnalytics.empty() : range = '7d', counts = const [];

  factory EventAnalytics.fromJson(Map<String, dynamic> json) {
    return EventAnalytics(
      range: json['range']?.toString() ?? '7d',
      counts: (json['counts'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(EventCount.fromJson)
          .toList(),
    );
  }

  bool get hasActivity => counts.any((item) => item.count > 0);
}
