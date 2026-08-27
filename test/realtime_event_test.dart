import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/realtime/realtime_event.dart';

void main() {
  group('RealtimeEvent', () {
    test('parses the versioned realtime envelope', () {
      final event = RealtimeEvent.tryParse('''
        {
          "id": "event-1",
          "type": "permissions.updated",
          "version": 2,
          "occurred_at": "2026-08-21T10:15:30Z",
          "data": {"resource": "access-control"}
        }
      ''');

      expect(event, isNotNull);
      expect(event!.id, 'event-1');
      expect(event.type, 'permissions.updated');
      expect(event.version, 2);
      expect(event.occurredAt.toUtc(), DateTime.utc(2026, 8, 21, 10, 15, 30));
      expect(event.data['resource'], 'access-control');
    });

    test('rejects malformed or incomplete messages without throwing', () {
      expect(RealtimeEvent.tryParse('not-json'), isNull);
      expect(RealtimeEvent.tryParse('{"type":"permissions.updated"}'), isNull);
      expect(RealtimeEvent.tryParse(<String, Object?>{}), isNull);
    });
  });
}
