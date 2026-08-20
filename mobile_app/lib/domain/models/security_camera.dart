class SecurityCamera {
  final int id;
  final String name;
  final String? location;
  final String connectionStatus;
  final String streamUrl;
  final String? username;
  final bool enabled;
  final bool detectionEnabled;
  final bool snapshotEnabled;
  final double confidenceThreshold;

  const SecurityCamera({
    required this.id,
    required this.name,
    this.location,
    required this.connectionStatus,
    required this.streamUrl,
    this.username,
    required this.enabled,
    required this.detectionEnabled,
    required this.snapshotEnabled,
    required this.confidenceThreshold,
  });
  bool get isOnline => connectionStatus == 'online';
  factory SecurityCamera.fromJson(Map<String, dynamic> json) => SecurityCamera(
    id: (json['id'] as num).toInt(),
    name: json['name'].toString(),
    location: json['location']?.toString(),
    connectionStatus: json['connection_status']?.toString() ?? 'offline',
    streamUrl: json['stream_url'].toString(),
    username: json['username']?.toString(),
    enabled: json['enabled'] == true,
    detectionEnabled: json['detection_enabled'] == true,
    snapshotEnabled: json['snapshot_enabled'] == true,
    confidenceThreshold:
        (json['confidence_threshold'] as num?)?.toDouble() ?? .7,
  );
}

class DiscoveredCamera {
  final String id;
  final String name;
  final String host;
  final String serviceUrl;

  const DiscoveredCamera({
    required this.id,
    required this.name,
    required this.host,
    required this.serviceUrl,
  });

  factory DiscoveredCamera.fromJson(Map<String, dynamic> json) =>
      DiscoveredCamera(
        id: json['id'].toString(),
        name: json['name'].toString(),
        host: json['host'].toString(),
        serviceUrl: json['service_url'].toString(),
      );
}
