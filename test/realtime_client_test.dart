import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/core/realtime/realtime_client.dart';

void main() {
  test(
    'browser transport reads authenticated changes without a websocket',
    () async {
      final requests = <Uri>[];
      final client = RealtimeClient(
        baseUrl: 'https://api.test',
        accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
        preferPolling: true,
        httpClient: MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            jsonEncode({
              'data': {
                'changes': [
                  {
                    'sequence': 12,
                    'module': 'authorization',
                    'eventType': 'authorization.changed',
                    'createdAt': '2026-08-26T10:30:00Z',
                  },
                ],
              },
            }),
            200,
          );
        }),
      );

      final event = client.events.first;
      await client.start();

      expect((await event).type, 'authorization.changed');
      expect(client.status, RealtimeConnectionStatus.connected);
      expect(requests, hasLength(1));
      expect(requests.single.path, '/api/v1/operations/changes');
      expect(requests.single.queryParameters['after'], '0');
      expect(requests.single.queryParameters['limit'], '100');

      await client.dispose();
    },
  );
}
