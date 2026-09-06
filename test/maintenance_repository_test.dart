import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/features/maintenance/data/maintenance_repository.dart';

void main() {
  test('loads the public maintenance window before authentication', () async {
    final repository = MaintenanceRepository(
      baseUrl: 'https://api.example.test',
      client: MockClient((request) async {
        expect(request.url.path, '/api/maintenance');
        expect(request.headers.containsKey('authorization'), isFalse);
        return http.Response(
          '{"data":{"active":true,"startsAt":"2026-09-06T04:00:00Z",'
          '"endsAt":"2026-09-06T06:00:00Z","message":"Upgrade"}}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );

    final window = await repository.publicStatus();

    expect(window.active, isTrue);
    expect(window.message, 'Upgrade');
    expect(window.endsAt, isNotNull);
  });

  test('sends administrator schedules in UTC', () async {
    final repository = MaintenanceRepository(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'admin-token',
      client: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/admin/maintenance');
        expect(request.headers['authorization'], 'Bearer admin-token');
        expect(request.body, contains('"enabled":true'));
        return http.Response(
          '{"data":{"enabled":true,"startsAt":"2026-09-06T04:00:00Z",'
          '"endsAt":"2026-09-06T06:00:00Z","message":"Upgrade"}}',
          200,
        );
      }),
    );

    final saved = await repository.save(
      enabled: true,
      startsAt: DateTime.parse('2026-09-06T09:30:00+05:30'),
      endsAt: DateTime.parse('2026-09-06T11:30:00+05:30'),
      message: 'Upgrade',
    );

    expect(saved.enabled, isTrue);
  });
}
