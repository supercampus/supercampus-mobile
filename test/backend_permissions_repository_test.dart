import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/core/access/backend_permissions_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';

const _session = UserSession(
  email: 'student@example.com',
  displayName: 'Student',
  role: UserRole.student,
  jwtToken: 'test-token',
);

void main() {
  test('marks a 401 response as an expired session', () async {
    final repository = BackendPermissionsRepository(
      baseUrl: 'http://127.0.0.1:4000',
      client: MockClient((_) async => http.Response('{}', 401)),
    );

    await expectLater(
      repository.loadFor(_session),
      throwsA(
        isA<PermissionsException>()
            .having((error) => error.sessionExpired, 'sessionExpired', isTrue)
            .having((error) => error.message, 'message', contains('expired')),
      ),
    );
  });

  test('does not mark a 403 response as an expired session', () async {
    final repository = BackendPermissionsRepository(
      baseUrl: 'http://127.0.0.1:4000',
      client: MockClient((_) async => http.Response('{}', 403)),
    );

    await expectLater(
      repository.loadFor(_session),
      throwsA(
        isA<PermissionsException>().having(
          (error) => error.sessionExpired,
          'sessionExpired',
          isFalse,
        ),
      ),
    );
  });
}
