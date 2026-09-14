import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/features/notifications/data/notification_repository.dart';

void main() {
  test(
    'loads the notification inbox with unread and deep-link metadata',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/operations/notifications');
        expect(request.headers['authorization'], 'Bearer access-token');
        expect(request.headers['x-client-surface'], 'app');

        return http.Response(
          jsonEncode({
            'data': {
              'unreadCount': 1,
              'notifications': [
                {
                  'id': 'notification-1',
                  'category': 'wallet',
                  'eventType': 'wallet.credited',
                  'title': 'Wallet credited',
                  'body': 'Rs 500 was added to your wallet.',
                  'createdAt': '2026-08-30T08:30:00Z',
                  'deepLink': '/modules/wallet',
                  'priority': 'high',
                  'requiresAction': false,
                  'readAt': null,
                  'data': {'amount': 500},
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final repository = NotificationRepository(
        baseUrl: 'https://api.supercampus.ai',
        accessTokenProvider: ({forceRefresh = false}) async => 'access-token',
        client: client,
      );

      final inbox = await repository.inbox();

      expect(inbox.unreadCount, 1);
      expect(inbox.notifications, hasLength(1));
      expect(inbox.notifications.single.eventType, 'wallet.credited');
      expect(inbox.notifications.single.deepLink, '/modules/wallet');
      expect(inbox.notifications.single.isRead, isFalse);
      expect(inbox.notifications.single.data['amount'], 500);
    },
  );

  test('marks one notification and the full inbox as read', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      paths.add(request.url.path);
      return http.Response(
        jsonEncode({
          'data': {'ok': true},
        }),
        200,
      );
    });
    final repository = NotificationRepository(
      baseUrl: 'https://api.supercampus.ai',
      accessTokenProvider: ({forceRefresh = false}) async => 'access-token',
      client: client,
    );

    await repository.markRead('notification-1');
    await repository.markAllRead();

    expect(paths, [
      '/api/v1/operations/notifications/notification-1/read',
      '/api/v1/operations/notifications/read-all',
    ]);
  });

  test('registers and unregisters an FCM device token', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({
          'data': {'ok': true},
        }),
        200,
      );
    });
    final repository = NotificationRepository(
      baseUrl: 'https://api.supercampus.ai',
      accessTokenProvider: ({forceRefresh = false}) async => 'access-token',
      client: client,
    );

    await repository.registerDevice(
      token: 'a-valid-fcm-registration-token',
      platform: 'android',
      deviceName: 'Demo phone',
      locale: 'en_IN',
    );
    await repository.unregisterDevice('a-valid-fcm-registration-token');

    expect(requests, hasLength(2));
    expect(requests[0].method, 'POST');
    expect(requests[1].method, 'DELETE');
    expect(
      requests.map((request) => request.url.path),
      everyElement('/api/v1/operations/notifications/devices'),
    );
    expect(jsonDecode(requests[0].body), {
      'token': 'a-valid-fcm-registration-token',
      'platform': 'android',
      'provider': 'fcm',
      'deviceName': 'Demo phone',
      'locale': 'en_IN',
    });
    expect(jsonDecode(requests[1].body), {
      'token': 'a-valid-fcm-registration-token',
    });
  });
}
