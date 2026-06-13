import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_security_system/services/event_service.dart';
import 'package:smart_home_security_system/services/notification_service.dart';
import 'package:smart_home_security_system/services/notification_websocket_service.dart';
import 'package:smart_home_security_system/services/token_service.dart';

class FakeTokenService implements TokenService {
  FakeTokenService(this.token);

  final String? token;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<void> deleteToken() async {}

  @override
  Future<String?> getCurrentUserId() async => null;

  @override
  Future<bool> hasToken() async => token != null && token!.isNotEmpty;

  @override
  Future<void> saveToken(String token) async {}
}

class FakeEventService implements EventService {
  FakeEventService(this.payloads);

  final List<Map<String, dynamic>> payloads;

  @override
  Future<List<Map<String, dynamic>>> fetchRecentNotificationPayloads({
    int limit = 20,
  }) async {
    return payloads.take(limit).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeNotificationService implements NotificationService {
  final _notifiedEventIds = <int>{};
  final seenEventIds = <int>[];
  final shownEventIds = <int>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> markAiEventSeen(Map<String, dynamic> payload) async {
    final id = int.tryParse(payload['id']?.toString() ?? '');
    if (id != null) {
      _notifiedEventIds.add(id);
      seenEventIds.add(id);
    }
  }

  @override
  Future<void> showAiEventNotification(Map<String, dynamic> payload) async {
    final id = int.tryParse(payload['id']?.toString() ?? '');
    if (id != null && _notifiedEventIds.add(id)) {
      shownEventIds.add(id);
    }
  }

  @override
  Future<bool> hasNotified(int eventId) async {
    return _notifiedEventIds.contains(eventId);
  }

  @override
  Future<void> markNotified(int eventId) async {
    _notifiedEventIds.add(eventId);
  }

  @override
  Future<void> clearNotifiedEventIds() async {}
}

void main() {
  test(
    'start baselines old recent events without showing notifications',
    () async {
      final oldPayload = {
        'id': 1,
        'event_type': 'unknown_person',
        'premise_id': 1,
        'timestamp': DateTime.now()
            .subtract(const Duration(minutes: 5))
            .toUtc()
            .toIso8601String(),
        'priority': 'Warning',
        'message': 'Unknown person detected.',
      };
      final notificationService = FakeNotificationService();
      final service = NotificationWebSocketService(
        tokenService: FakeTokenService(null),
        eventService: FakeEventService([oldPayload]),
        notificationService: notificationService,
      );

      await service.start();
      await Future<void>.delayed(Duration.zero);

      expect(notificationService.seenEventIds, [1]);
      expect(notificationService.shownEventIds, isEmpty);
      expect(service.shouldReconnect, isFalse);
    },
  );

  test('recoverMissedEvents only shows events after session start', () async {
    final oldPayload = {
      'id': 2,
      'timestamp': DateTime.now()
          .subtract(const Duration(minutes: 5))
          .toUtc()
          .toIso8601String(),
    };
    final newPayload = {
      'id': 3,
      'timestamp': DateTime.now()
          .add(const Duration(seconds: 1))
          .toUtc()
          .toIso8601String(),
    };
    final notificationService = FakeNotificationService();
    final service = NotificationWebSocketService(
      tokenService: FakeTokenService(null),
      eventService: FakeEventService([oldPayload, newPayload]),
      notificationService: notificationService,
    );

    await service.start();
    await service.recoverMissedEvents();

    expect(notificationService.shownEventIds, [3]);
  });

  test('network connect failure keeps reconnect enabled', () async {
    final service = NotificationWebSocketService(
      tokenService: FakeTokenService('valid-token'),
      eventService: FakeEventService(const []),
      notificationService: FakeNotificationService(),
      channelFactory: (_) => throw Exception('network down'),
    );

    await service.start();

    expect(service.shouldReconnect, isTrue);
    await service.stop();
  });
}
