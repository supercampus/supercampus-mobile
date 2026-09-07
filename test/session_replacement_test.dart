import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/data/backend_auth_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/presentation/login_screen.dart';

void main() {
  test('refresh identifies a session replaced by another device', () async {
    final repository = BackendAuthRepository(
      baseUrl: 'https://api.supercampus.ai',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'code': 'session_replaced',
            'error': 'This account was signed in on another device',
          }),
          401,
        ),
      ),
    );

    await expectLater(
      repository.refresh(
        const UserSession(
          email: 'student@mec.local',
          displayName: 'Student',
          role: UserRole.student,
          refreshToken: 'old-refresh-token',
        ),
      ),
      throwsA(
        isA<AuthenticationException>()
            .having((error) => error.sessionExpired, 'sessionExpired', isTrue)
            .having(
              (error) => error.signedInElsewhere,
              'signedInElsewhere',
              isTrue,
            ),
      ),
    );
  });

  testWidgets('previous device shows a signed-out popup card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(
          authRepository: _UnusedAuthRepository(),
          onSignedIn: (_) {},
          sessionNotice:
              'This account was signed in on another device. For your security, you were signed out here.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Signed out on this device'), findsOneWidget);
    expect(find.textContaining('signed in on another device'), findsOneWidget);
    expect(find.text('Okay'), findsOneWidget);
  });
}

class _UnusedAuthRepository implements AuthRepository {
  @override
  Future<UserSession> refresh(UserSession session) async => session;

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<UserSession> signIn({
    required String email,
    required String password,
    required String tenantDomain,
    UserRole? roleHint,
  }) => throw UnimplementedError();
}
