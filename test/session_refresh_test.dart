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
  test('backend refresh returns the rotated access session', () async {
    final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 15));
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/auth/refresh');
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
    expect(refreshed.accessTokenExpiresAt, expiresAt);
  });

  testWidgets('renews an expiring session before polling permissions', (
    tester,
  ) async {
    final auth = _ExpiringAuthRepository();
    final permissions = _RecordingPermissionsRepository();
    await tester.pumpWidget(
      SupercampusApp(authRepository: auth, permissionsRepository: permissions),
    );

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

UserSession _session(String token, {bool expiring = false}) => UserSession(
  email: 'student@example.com',
  displayName: 'Student',
  role: UserRole.student,
  jwtToken: token,
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
    required UserRole role,
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
