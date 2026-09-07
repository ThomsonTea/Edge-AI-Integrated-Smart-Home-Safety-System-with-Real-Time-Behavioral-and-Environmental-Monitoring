import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_security_system/services/notification_service.dart';

void main() {
  test('AI event notifications use a one-shot notification channel', () {
    final details = NotificationService.notificationDetailsForPriority(
      'Critical',
    );
    final android = details.android;

    expect(android, isNotNull);
    expect(android!.channelId, 'ai_event_alerts_v2');
    expect(android.category, AndroidNotificationCategory.event);
    expect(android.onlyAlertOnce, isTrue);
    expect(android.ongoing, isFalse);
    expect(android.autoCancel, isTrue);
    expect(android.audioAttributesUsage, AudioAttributesUsage.notification);
  });

  test('AI event notifications request one normal iOS sound', () {
    final details = NotificationService.notificationDetailsForPriority(
      'Warning',
    );
    final ios = details.iOS;

    expect(ios, isNotNull);
    expect(ios!.presentAlert, isTrue);
    expect(ios.presentBadge, isTrue);
    expect(ios.presentSound, isTrue);
  });
}
