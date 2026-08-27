import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/features/attendance/data/attendance_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/backend_canteen_repository.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/backend_gatepass_repository.dart';

void main() {
  test('canteen store request carries the signed-in bearer token', () async {
    final repository = BackendCanteenRepository(
      baseUrl: 'http://127.0.0.1:4000',
      accessToken: 'canteen-token',
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer canteen-token');
        expect(request.headers['x-client-surface'], 'app');
        return http.Response(
          '{"data":{"user":{},"walletBalance":0,"menu":[],"orders":[],"walletTransactions":[]}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await repository.loadStore();
  });

  test(
    'canteen retries once with a silently refreshed token after 401',
    () async {
      var requests = 0;
      var forcedRefreshes = 0;
      final authorizationHeaders = <String?>[];
      final repository = BackendCanteenRepository(
        baseUrl: 'http://127.0.0.1:4000',
        accessTokenProvider: ({bool forceRefresh = false}) async {
          if (forceRefresh) {
            forcedRefreshes += 1;
            return 'new-token';
          }
          return 'old-token';
        },
        client: MockClient((request) async {
          requests += 1;
          authorizationHeaders.add(request.headers['authorization']);
          if (requests == 1) {
            return http.Response('{"error":"unauthorized"}', 401);
          }
          return http.Response(
            '{"data":{"user":{},"walletBalance":0,"menu":[],"orders":[],"walletTransactions":[]}}',
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      await repository.loadStore();

      expect(requests, 2);
      expect(forcedRefreshes, 1);
      expect(authorizationHeaders, ['Bearer old-token', 'Bearer new-token']);
    },
  );

  test('canteen manager capability enables the owner workspace', () async {
    final repository = BackendCanteenRepository(
      baseUrl: 'http://127.0.0.1:4000',
      accessToken: 'owner-token',
      client: MockClient((request) async {
        return http.Response(
          '{"data":{"user":{"name":"Akhil","email":"akhil@gmail.com"},'
          '"walletBalance":0,"menu":[],"orders":[],"walletTransactions":[],'
          '"canManage":true,"staffState":{"mode":"work","shopOpen":true},'
          '"analytics":{"ordersToday":8,"revenueToday":720,"pending":2}}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final store = await repository.loadStore();

    expect(store.user.name, 'Akhil');
    expect(store.canManage, isTrue);
    expect(store.staffState.mode.name, 'work');
    expect(store.staffState.shopOpen, isTrue);
    expect(store.analytics.ordersToday, 8);
  });

  test('attendance request carries the signed-in bearer token', () async {
    final repository = AttendanceRepository(
      baseUrl: 'http://127.0.0.1:4000',
      accessToken: 'attendance-token',
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer attendance-token');
        expect(request.headers['x-client-surface'], 'app');
        return http.Response(
          '{"data":{"wards":[]}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await repository.wards();
  });

  test('gatepass mutation carries the signed-in bearer token', () async {
    final repository = BackendGatepassRepository(
      baseUrl: 'http://127.0.0.1:4000',
      accessToken: 'gatepass-token',
      studentName: 'Student',
      email: 'student@example.com',
      rollNumber: 'SC-1',
      department: 'CSE',
      client: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer gatepass-token');
        expect(request.headers['x-client-surface'], 'app');
        return http.Response(
          '{"data":{"id":"request-1","state":"cancelled"}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await repository.cancelRequest('request-1');
  });
}
