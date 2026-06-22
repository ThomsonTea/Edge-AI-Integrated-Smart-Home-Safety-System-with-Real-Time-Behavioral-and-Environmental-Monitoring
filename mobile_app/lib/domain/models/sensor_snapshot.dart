class SensorSnapshot {
  final String status;
  final double? temperature;
  final double? humidity;
  final int? gas;
  final DateTime? lastUpdated;

  const SensorSnapshot({
    required this.status,
    this.temperature,
    this.humidity,
    this.gas,
    this.lastUpdated,
  });

  const SensorSnapshot.offline()
    : status = 'disconnected',
      temperature = null,
      humidity = null,
      gas = null,
      lastUpdated = null;

  factory SensorSnapshot.fromJson(Map<String, dynamic> json) {
    return SensorSnapshot(
      status: json['status']?.toString() ?? 'unknown',
      temperature: _doubleFromJson(json['temperature']),
      humidity: _doubleFromJson(json['humidity']),
      gas: _intFromJson(json['gas']),
      lastUpdated: DateTime.tryParse(json['last_updated']?.toString() ?? ''),
    );
  }

  bool get isConnected => status.toLowerCase() == 'connected';

  bool get hasCompleteReadings =>
      temperature != null && humidity != null && gas != null;

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
