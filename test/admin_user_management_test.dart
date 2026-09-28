import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/admin_portal/data/admin_student_repository.dart';
import 'package:supercampus_mobile/src/features/admin_portal/presentation/admin_users_page.dart';

void main() {
  late List<http.Request> requests;
  late AdminStudentRepository repository;

  setUp(() {
    requests = [];
    repository = AdminStudentRepository(
      baseUrl: 'https://api.supercampus.ai',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/authorization/users')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'user-1',
                  'name': 'Vishnu S',
                  'email': 'vsnu4education@gmail.com',
                  'active': true,
                  'roles': [
                    {'id': 'role-1', 'key': 'student', 'name': 'Student'},
                  ],
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/authorization/roles')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'role-1',
                  'key': 'student',
                  'name': 'Student',
                  'active': true,
                },
                {
                  'id': 'role-2',
                  'key': 'class_advisor',
                  'name': 'Class Advisor',
                  'active': true,
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/password')) {
          return http.Response('', 204);
        }
        return http.Response(jsonEncode({'data': {}}), 200);
      }),
    );
  });

  testWidgets('lists MEC users with email and role management actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminUsersPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MEC accounts'), findsOneWidget);
    expect(find.text('Vishnu S'), findsOneWidget);
    expect(find.text('vsnu4education@gmail.com'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Add user'), findsOneWidget);

    await tester.tap(find.byTooltip('Manage Vishnu S'));
    await tester.pumpAndSettle();
    expect(find.text('Edit roles'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
  });

  testWidgets('offers deactivation with a confirmation, never on oneself', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminUsersPage(
          repository: repository,
          currentUserEmail: 'admin@mec.local',
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Manage Vishnu S'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deactivate user'));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate user?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Deactivate'));
    await tester.pumpAndSettle();
    final statusRequest = requests.lastWhere(
      (request) => request.url.path.endsWith('/status'),
    );
    expect(statusRequest.method, 'PUT');
    expect(
      statusRequest.url.path,
      endsWith('/authorization/users/user-1/status'),
    );
    expect(jsonDecode(statusRequest.body), {'active': false});

    // The same account seen by itself has no deactivate action.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminUsersPage(
          key: const ValueKey('self'),
          repository: repository,
          currentUserEmail: 'vsnu4education@gmail.com',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Manage Vishnu S'));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate user'), findsNothing);
  });

  testWidgets('never offers a role the administrator cannot grant', (
    tester,
  ) async {
    final privileged = AdminStudentRepository(
      baseUrl: 'https://api.supercampus.ai',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/authorization/users')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'user-1',
                  'name': 'Vishnu S',
                  'email': 'vsnu4education@gmail.com',
                  'active': false,
                  'roles': [
                    {'id': 'role-1', 'key': 'student', 'name': 'Student'},
                  ],
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/authorization/roles')) {
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 'role-1', 'key': 'student', 'name': 'Student'},
                {
                  'id': 'role-9',
                  'key': 'superadmin',
                  'name': 'Super Administrator',
                  'assignable': false,
                },
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'data': {}}), 200);
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminUsersPage(repository: privileged),
      ),
    );
    await tester.pumpAndSettle();

    // Inactive accounts stay listed, marked, and can be brought back.
    expect(find.text('Inactive'), findsOneWidget);
    await tester.tap(find.byTooltip('Manage Vishnu S'));
    await tester.pumpAndSettle();
    expect(find.text('Reactivate user'), findsOneWidget);
    await tester.tap(find.text('Edit roles'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Super Administrator'),
      ),
      findsNothing,
    );
  });

  test(
    'sends role and password changes to the tenant user endpoints',
    () async {
      await repository.setUserRoles('user-1', const ['role-2']);
      await repository.setUserPassword('user-1', 'NewPassword!2026');

      expect(
        requests[0].url.path,
        endsWith('/authorization/users/user-1/roles'),
      );
      expect(jsonDecode(requests[0].body)['roleIds'], ['role-2']);
      expect(
        requests[1].url.path,
        endsWith('/authorization/users/user-1/password'),
      );
      expect(jsonDecode(requests[1].body)['password'], 'NewPassword!2026');
    },
  );
}
