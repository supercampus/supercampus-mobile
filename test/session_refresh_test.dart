import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/app.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/access/permissions_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/data/backend_auth_repository.dart';

void main() {
  test('login sends the selected institution domain', () async {
    final client = MockClient((request) async {
      expect(request.headers['x-tenant-id'], 'mec');
      expect(request.headers['x-client-surface'], 'app');
      expect(jsonDecode(request.body), {
        'email': 'student@mec.edu',
        'password': 'password123',
        'sessionMode': 'token',
      });
      return http.Response(
        jsonEncode({
          'data': {
            'student': {
              'email': 'student@mec.edu',
              'name': 'Student',
              'role': 'student',
            },
            'roles': ['student'],
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 15))
                .toIso8601String(),
          },
        }),
        200,
      );
    });
    final repository = BackendAuthRepository(
      baseUrl: 'http://localhost:4000',
      client: client,
    );

    final session = await repository.signIn(
      email: 'student@mec.edu',
      password: 'password123',
      tenantDomain: 'mec',
    );

    expect(session.refreshToken, 'refresh-token');
  });

  test(
    'login retries without sessionMode for the deployed legacy API',
    () async {
      var attempts = 0;
      final client = MockClient((request) async {
        attempts += 1;
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (attempts == 1) {
          expect(body['sessionMode'], 'token');
          return http.Response(
            'Failed to deserialize the JSON body: sessionMode: unknown field '
            '`sessionMode`, expected `email` or `password`',
            422,
          );
        }
        expect(body, {
          'email': 'abinaya2006sathya@gmail.com',
          'password': 'ABIN4119',
        });
        return http.Response(
          jsonEncode({
            'data': {
              'student': {
                'email': 'abinaya2006sathya@gmail.com',
                'name': 'Abinaya S',
                'role': 'student',
                'roll': 'MEC25AD01',
              },
              'roles': ['student'],
              'accessToken': 'access-token',
              'expiresAt': DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: 15))
                  .toIso8601String(),
            },
          }),
          200,
        );
      });
      final repository = BackendAuthRepository(
        baseUrl: 'https://api.supercampus.ai',
        client: client,
      );

      final session = await repository.signIn(
        email: 'abinaya2006sathya@gmail.com',
        password: 'ABIN4119',
        tenantDomain: 'mec',
      );

      expect(attempts, 2);
      expect(session.displayName, 'Abinaya S');
      expect(session.idNumber, 'MEC25AD01');
    },
  );

  test('backend refresh returns the rotated access session', () async {
    final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 15));
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/auth/refresh');
      expect(request.headers['x-client-surface'], 'app');
      expect(jsonDecode(request.body), {'refreshToken': 'refresh-token'});
      return http.Response(
        jsonEncode({
          'data': {
            'student': {
              'email': 'student@example.com',
              'name': 'Student',
              'role': 'student',
            },
            'roles': ['student'],
            'accessToken': 'rotated-token',
            'refreshToken': 'rotated-refresh-token',
            'expiresAt': expiresAt.toIso8601String(),
          },
        }),
        200,
      );
    });
    final repository = BackendAuthRepository(
      baseUrl: 'http://localhost:4000',
      client: client,
    );

    final refreshed = await repository.refresh(_session('old-token'));

    expect(refreshed.jwtToken, 'rotated-token');
    expect(refreshed.refreshToken, 'rotated-refresh-token');
    expect(refreshed.accessTokenExpiresAt, expiresAt);
  });

  test('explicit portal family controls a custom college role', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'data': {
            'student': {
              'email': 'coordinator@mec.edu',
              'name': 'Coordinator',
              'role': 'knowledge_centre_incharge',
              'portalFamilies': ['staff'],
            },
            'roles': ['knowledge_centre_incharge'],
            'accessToken': 'access-token',
            'expiresAt': DateTime.now()
                .toUtc()
                .add(const Duration(minutes: 15))
                .toIso8601String(),
          },
        }),
        200,
      ),
    );
    final repository = BackendAuthRepository(
      baseUrl: 'http://localhost:4000',
      client: client,
    );

    final session = await repository.signIn(
      email: 'coordinator@mec.edu',
      password: 'password123',
      tenantDomain: 'mec',
    );

    expect(session.role, UserRole.staff);
    expect(session.activePortalFamily, PortalFamily.staff);
    expect(session.roleId, 'knowledge_centre_incharge');
  });

  test('login connection failures name the configured API origin', () async {
    final client = MockClient((request) async {
      throw http.ClientException('Failed host lookup', request.url);
    });
    final repository = BackendAuthRepository(
      baseUrl: 'https://api.supercampus.ai',
      client: client,
    );

    await expectLater(
      repository.signIn(
        email: 'student@mec.edu',
        password: 'password123',
        tenantDomain: 'mec',
      ),
      throwsA(
        isA<AuthenticationException>().having(
          (error) => error.message,
          'message',
          contains('https://api.supercampus.ai'),
        ),
      ),
    );
  });

  testWidgets('renews an expiring session before polling permissions', (
    tester,
  ) async {
    final auth = _ExpiringAuthRepository();
    final permissions = _RecordingPermissionsRepository();
    await tester.pumpWidget(
      SupercampusApp(authRepository: auth, permissionsRepository: permissions),
    );
    await tester.tap(find.byKey(const ValueKey('start-sign-in')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('institution-domain')),
      'mec',
    );
    await tester.tap(find.byKey(const ValueKey('continue-from-institution')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(auth.refreshCalls, 1);
    expect(permissions.tokens, containsAllInOrder(['old-token', 'new-token']));
  });
}

UserSession _session(
  String token, {
  bool expiring = false,
  String refreshToken = 'refresh-token',
}) => UserSession(
  email: 'student@example.com',
  displayName: 'Student',
  role: UserRole.student,
  jwtToken: token,
  refreshToken: refreshToken,
  accessTokenExpiresAt: DateTime.now().add(
    Duration(seconds: expiring ? 5 : 900),
  ),
);

class _ExpiringAuthRepository implements AuthRepository {
  int refreshCalls = 0;

  @override
  Future<UserSession> signIn({
    required String email,
    required String password,
    required String tenantDomain,
    UserRole? roleHint,
  }) async => _session('old-token', expiring: true);

  @override
  Future<UserSession> refresh(UserSession session) async {
    refreshCalls += 1;
    return _session('new-token');
  }

  @override
  Future<void> sendPasswordReset(String email) async {}
}

class _RecordingPermissionsRepository implements PermissionsRepository {
  final List<String?> tokens = [];

  @override
  Future<EffectivePermissions> loadFor(UserSession session) async {
    tokens.add(session.jwtToken);
    return const EffectivePermissions.empty();
  }
}
