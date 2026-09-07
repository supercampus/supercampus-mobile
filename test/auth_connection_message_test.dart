import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/data/backend_auth_repository.dart';

void main() {
  test(
    'connection failures show a user-facing message without the API URL',
    () async {
      final repository = BackendAuthRepository(
        baseUrl: 'https://api.supercampus.ai',
        client: MockClient((request) async {
          throw http.ClientException('Failed host lookup', request.url);
        }),
      );

      await expectLater(
        repository.signIn(
          email: 'student@mec.local',
          password: 'password123',
          tenantDomain: 'mec',
        ),
        throwsA(
          isA<AuthenticationException>()
              .having(
                (error) => error.message,
                'message',
                'We couldn’t connect to SuperCampus. Check your internet connection and try again.',
              )
              .having(
                (error) => error.message,
                'message',
                isNot(contains('api.supercampus.ai')),
              ),
        ),
      );
    },
  );
}
