import 'package:flutter_test/flutter_test.dart';
import 'package:smart_home_security_system/domain/models/ai_event.dart';

void main() {
  test('parses pinned state from event response', () {
    final event = AiEvent.fromJson({
      'id': 12,
      'event_type': 'unknown_person',
      'is_acknowledged': true,
      'is_pinned': true,
    });

    expect(event.id, 12);
    expect(event.isAcknowledged, isTrue);
    expect(event.isPinned, isTrue);
  });

  test('defaults pinned state to false for older responses', () {
    final event = AiEvent.fromJson({
      'id': 13,
      'event_type': 'known_person',
      'is_acknowledged': false,
    });

    expect(event.isPinned, isFalse);
  });
}
