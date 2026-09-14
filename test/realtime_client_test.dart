import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/core/realtime/realtime_client.dart';

void main() {
  test(
    'native transport exchanges a ticket and receives websocket events',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final requests = <String>[];
      final serverDone = Completer<void>();
      server.listen((request) async {
        requests.add(request.uri.path);
        if (request.uri.path == '/api/auth/realtime-token') {
          await request.drain<void>();
          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(
              jsonEncode({
                'data': {'token': 'socket-ticket'},
              }),
            );
          await request.response.close();
          return;
        }
        if (request.uri.path == '/api/v1/realtime/ws' &&
            request.uri.queryParameters['access_token'] == 'socket-ticket') {
          final socket = await WebSocketTransformer.upgrade(request);
          socket.add(
            jsonEncode({
              'id': 'ready-1',
              'type': 'realtime.ready',
              'version': 1,
              'occurred_at': '2026-08-31T08:00:00Z',
              'data': {'tenantId': 'tenant-1', 'userId': 'user-1'},
            }),
          );
          await socket.close();
          if (!serverDone.isCompleted) serverDone.complete();
          return;
        }
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
      });

      final client = RealtimeClient(
        baseUrl: 'http://${server.address.address}:${server.port}',
        accessTokenProvider: ({bool forceRefresh = false}) async =>
            'access-token',
        preferPolling: false,
      );
      addTearDown(() async {
        await client.dispose();
        await server.close(force: true);
      });

      final ready = client.events.firstWhere(
        (event) => event.type == 'realtime.ready',
      );
      await client.start();
      final event = await ready.timeout(const Duration(seconds: 3));

      expect(event.data['tenantId'], 'tenant-1');
      expect(requests, ['/api/auth/realtime-token', '/api/v1/realtime/ws']);
      await serverDone.future.timeout(const Duration(seconds: 3));
    },
  );

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
