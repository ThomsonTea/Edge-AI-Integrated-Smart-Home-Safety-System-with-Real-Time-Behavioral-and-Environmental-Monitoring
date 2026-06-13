import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../routing/router.dart';
import '../routing/routes.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const _notifiedEventIdsKey = 'notified_ai_event_ids';
  static const _channelId = 'ai_event_alerts';
  static const _channelName = 'AI Event Alerts';
  static const _channelDescription = 'Real-time smart home security alerts';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Set<int> _inFlightEventIds = <int>{};

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    await _requestPermissions();
    _isInitialized = true;
  }

  Future<void> showAiEventNotification(Map<String, dynamic> payload) async {
    await initialize();

    final eventId = _eventIdFromPayload(payload);
    if (eventId == null || eventId <= 0) {
      return;
    }

    if (_inFlightEventIds.contains(eventId)) {
      return;
    }

    _inFlightEventIds.add(eventId);

    try {
      if (await hasNotified(eventId)) {
        return;
      }

      final priority = payload['priority']?.toString() ?? 'Info';
      final message =
          payload['message']?.toString() ?? 'New security event detected.';

      await _plugin.show(
        eventId,
        '$priority Security Alert',
        message,
        _notificationDetails(priority),
        payload: eventId.toString(),
      );

      await markNotified(eventId);
    } finally {
      _inFlightEventIds.remove(eventId);
    }
  }

  Future<void> markAiEventSeen(Map<String, dynamic> payload) async {
    final eventId = _eventIdFromPayload(payload);

    if (eventId == null || eventId <= 0) {
      return;
    }

    await markNotified(eventId);
  }

  Future<bool> hasNotified(int eventId) async {
    final ids = await _readNotifiedEventIds();
    return ids.contains(eventId);
  }

  Future<void> markNotified(int eventId) async {
    final ids = await _readNotifiedEventIds();
    ids.add(eventId);

    final trimmed = ids.toList()
      ..sort()
      ..removeRange(0, ids.length > 200 ? ids.length - 200 : 0);

    await _storage.write(key: _notifiedEventIdsKey, value: trimmed.join(','));
  }

  Future<void> clearNotifiedEventIds() {
    return _storage.delete(key: _notifiedEventIdsKey);
  }

  NotificationDetails _notificationDetails(String priority) {
    final importance = priority == 'Critical'
        ? Importance.max
        : priority == 'Warning'
        ? Importance.high
        : Importance.defaultImportance;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: importance,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
    );

    return NotificationDetails(android: androidDetails);
  }

  Future<Set<int>> _readNotifiedEventIds() async {
    final value = await _storage.read(key: _notifiedEventIdsKey);

    if (value == null || value.trim().isEmpty) {
      return <int>{};
    }

    return value
        .split(',')
        .map((id) => int.tryParse(id.trim()))
        .whereType<int>()
        .toSet();
  }

  int? _eventIdFromPayload(Map<String, dynamic> payload) {
    return int.tryParse(payload['id']?.toString() ?? '');
  }

  Future<void> _requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  void _handleNotificationResponse(NotificationResponse response) {
    final eventId = int.tryParse(response.payload ?? '');

    if (eventId == null || eventId <= 0) {
      return;
    }

    AppRouter.navigatorKey.currentState?.pushNamed(
      AppRoutes.eventDetail,
      arguments: eventId,
    );
  }
}
