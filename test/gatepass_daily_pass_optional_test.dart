import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/backend_gatepass_repository.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/gatepass_models.dart';

/// Activating today's entry QR is allowed to fail without taking the module
/// with it.
///
/// The API refuses `daily-access` with 403 whenever the device is outside the
/// campus fence, which is the ordinary state of a learner who is at home. That
/// used to surface as "Gatepass services are unavailable" over a blank screen,
/// hiding the requests and gate movements that had already loaded fine.
const _overview = {
  'data': {
    'canManage': false,
    'requests': [
      {
        'id': 'req-1',
        'passType': 'outpass',
        'state': 'pending',
        'destination': 'Home',
        'reason': 'Weekend',
        'createdAt': '2026-08-22T00:09:50Z',
        'departureAt': '2026-08-22T03:09:49Z',
      },
    ],
    'movements': [
      {
        'id': 'mv-1',
        'direction': 'exit',
        'checkpoint': 'Main Gate',
        'method': 'qr',
        'createdAt': '2026-08-22T00:10:40Z',
      },
    ],
  },
};

/// What the real API answers when the caller is outside the fence.
const _forbidden = {
  'error': 'This session cannot access the requested tenant or resource',
  'code': 'forbidden',
};

BackendGatepassRepository repositoryReturning({
  int overviewStatus = 200,
  String? overviewBody,
  required int dailyStatus,
  required Map<String, Object?> dailyBody,
}) => BackendGatepassRepository(
  baseUrl: 'http://localhost:4000',
  accessToken: 'test-token',
  studentName: 'Priya Kumar',
  email: 'student001@mec.local',
  rollNumber: 'MEC001',
  department: 'CSE',
  // A fixed fix, so the test exercises the API's answer and not the GPS.
  positionProvider: () async =>
      (latitude: 13.0827, longitude: 80.2707, accuracyMetres: 8.0),
  client: MockClient((request) async {
    if (request.url.path.endsWith('/gatepass/overview')) {
      return http.Response(
        overviewBody ?? jsonEncode(_overview),
        overviewStatus,
      );
    }
    if (request.url.path.endsWith('/gatepass/daily-access')) {
      final location = jsonDecode(request.body) as Map<String, dynamic>;
      expect(location['accuracyMetres'], 8);
      return http.Response(jsonEncode(dailyBody), dailyStatus);
    }
    return http.Response('{}', 404);
  }),
);

void main() {
  test('a 403 from daily-access still yields the rest of the module', () async {
    final store = await repositoryReturning(
      dailyStatus: 403,
      dailyBody: _forbidden,
    ).loadStore();

    // The part that failed is absent and explained...
    expect(store.dailyPass, isNull);
    expect(store.dailyPassIssue, contains('outside the campus boundary'));

    // ...and the part that succeeded is still here.
    expect(store.requests, hasLength(1));
    expect(store.movements, hasLength(1));
  });

  test(
    'the forbidden wording never reaches the reader as "forbidden"',
    () async {
      final store = await repositoryReturning(
        dailyStatus: 403,
        dailyBody: _forbidden,
      ).loadStore();

      expect(store.dailyPassIssue, isNot(contains('forbidden')));
      expect(store.dailyPassIssue, isNot(contains('tenant')));
    },
  );

  test(
    'a plain-string error is read, not replaced with a stock sentence',
    () async {
      final store = await repositoryReturning(
        dailyStatus: 400,
        dailyBody: const {
          'error': 'That is not a valid location',
          'code': 'bad_request',
        },
      ).loadStore();

      expect(store.dailyPassIssue, 'That is not a valid location');
      expect(store.requests, hasLength(1));
    },
  );

  test('an unreadable overview still opens an empty gatepass module', () async {
    final store = await repositoryReturning(
      overviewBody: '<html>not the API</html>',
      dailyStatus: 403,
      dailyBody: _forbidden,
    ).loadStore();

    expect(store.student.email, 'student001@mec.local');
    expect(store.requests, isEmpty);
    expect(store.movements, isEmpty);
    expect(store.dailyPassIssue, contains('outside the campus boundary'));
  });

  test(
    'a 403 puts the reader outside the fence, not in an error state',
    () async {
      final store = await repositoryReturning(
        dailyStatus: 403,
        dailyBody: _forbidden,
      ).loadStore();

      expect(store.zone, CampusZone.outside);
    },
  );

  test('activating a pass is what proves the device is inside', () async {
    final store = await repositoryReturning(
      dailyStatus: 201,
      dailyBody: const {
        'data': {
          'id': 'pass-1',
          'validOn': '2026-08-23',
          'validFrom': '2026-08-23T04:00:00Z',
          'validUntil': '2026-08-24T00:00:00Z',
          'qrPayload': 'live-token-abc',
          'location': {
            'latitude': 13.0105,
            'longitude': 80.2357,
            'accuracyMetres': 8.0,
          },
          'campusGeofence': {
            'latitude': 13.0104,
            'longitude': 80.2356,
            'radiusMetres': 400.0,
          },
        },
      },
    ).loadStore();

    expect(store.zone, CampusZone.inside);
    expect(store.dailyPass?.qrPayload, 'live-token-abc');
    expect(store.dailyPassIssue, isNull);
    expect(store.student.isOnCampus, isTrue);
    expect(store.mapLocation?.studentLatitude, 13.0105);
    expect(store.mapLocation?.campusLatitude, 13.0104);
    expect(store.mapLocation?.radiusMetres, 400.0);
  });

  test(
    'a failure that says nothing about location leaves the zone unknown',
    () async {
      final store = await repositoryReturning(
        dailyStatus: 500,
        dailyBody: const {'error': 'boom', 'code': 'internal'},
      ).loadStore();

      expect(store.zone, CampusZone.unknown);
      expect(store.dailyPass, isNull);
    },
  );

  test(
    'an empty body — a stale API with no such route — is not a zone claim',
    () async {
      final repo = BackendGatepassRepository(
        baseUrl: 'http://localhost:4000',
        accessToken: 'test-token',
        studentName: 'Priya Kumar',
        email: 'student001@mec.local',
        rollNumber: 'MEC001',
        department: 'CSE',
        positionProvider: () async =>
            (latitude: 13.0827, longitude: 80.2707, accuracyMetres: 8.0),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/gatepass/overview')) {
            return http.Response(jsonEncode(_overview), 200);
          }
          // What api.supercampus.ai actually answers: 404, empty body.
          return http.Response('', 404);
        }),
      );
      final store = await repo.loadStore();

      expect(store.zone, CampusZone.unknown);
      expect(store.requests, hasLength(1));
    },
  );

  test(
    'an empty 404 names the stale server instead of blaming the payload',
    () async {
      final repo = BackendGatepassRepository(
        baseUrl: 'http://localhost:4000',
        accessToken: 'test-token',
        studentName: 'Priya Kumar',
        email: 'student001@mec.local',
        rollNumber: 'MEC001',
        department: 'CSE',
        positionProvider: () async =>
            (latitude: 13.0827, longitude: 80.2707, accuracyMetres: 8.0),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/gatepass/overview')) {
            return http.Response(jsonEncode(_overview), 200);
          }
          return http.Response('', 404);
        }),
      );
      final store = await repo.loadStore();

      expect(store.dailyPassIssue, contains('older'));
      expect(store.dailyPassIssue, isNot(contains('unreadable')));
    },
  );

  test('an overview that 404s still opens the module', () async {
    final repo = BackendGatepassRepository(
      baseUrl: 'http://localhost:4000',
      accessToken: 'test-token',
      studentName: 'Priya Kumar',
      email: 'student001@mec.local',
      rollNumber: 'MEC001',
      department: 'CSE',
      positionProvider: () async =>
          (latitude: 13.0827, longitude: 80.2707, accuracyMetres: 8.0),
      // Exactly what api.supercampus.ai answers today: no gatepass routes.
      client: MockClient((_) async => http.Response('', 404)),
    );

    final store = await repo.loadStore();

    expect(store.requests, isEmpty);
    expect(store.movements, isEmpty);
    expect(store.dailyPass, isNull);
    expect(store.zone, CampusZone.unknown);
  });
}
