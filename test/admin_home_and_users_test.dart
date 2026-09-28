import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/admin_portal/data/admin_student_repository.dart';
import 'package:supercampus_mobile/src/features/admin_portal/presentation/admin_dashboard_screen.dart';
import 'package:supercampus_mobile/src/features/admin_portal/presentation/admin_users_page.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';

const _adminSession = UserSession(
  email: 'admin@mec.local',
  displayName: 'Arun Iyer',
  role: UserRole.admin,
  roleId: 'tenant_admin',
  roleIds: ['tenant_admin'],
);

const _student = ManagedUserRole(id: 'r-student', key: 'student', name: 'Student');

List<Map<String, Object?>> _usersJson(Map<String, String> names) => [
  {
    'id': 'u-1',
    'name': names['u-1'] ?? 'Asha Kumar',
    'email': 'asha@mec.local',
    'active': true,
    'yearOfStudy': null,
    'roles': [
      {'id': 'r-student', 'key': 'student', 'name': 'Student'},
    ],
  },
  {
    'id': 'u-2',
    'name': 'Bala Raman',
    'email': 'bala@mec.local',
    'active': true,
    'yearOfStudy': '2',
    'roles': [
      {'id': 'r-student', 'key': 'student', 'name': 'Student'},
    ],
  },
  {
    'id': 'u-3',
    'name': 'Chitra Devi',
    'email': 'chitra@mec.local',
    'active': true,
    'roles': <Object>[],
  },
];

void main() {
  group('administrator home', () {
    Future<void> pump(
      WidgetTester tester, {
      Future<List<ManagedTenantUser>> Function()? loader,
    }) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminDashboardScreen(
            session: _adminSession,
            permissions: EffectivePermissions(grants: {'*'}),
            onOpenModule: (_, [_]) {},
            onSignOut: () {},
            onProfileTap: () {},
            onAlertsTap: () {},
            loadAdminUsers: loader,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('lists each workspace once and leaves teaching tools out', (
      tester,
    ) async {
      await pump(tester);

      for (final title in [
        'Users & roles',
        'Student directory',
        'Announcements',
        'Shops & sales',
        'Student wallets',
        'Tuition & fees',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      for (final removed in [
        'Attendance Desk',
        'Timetable',
        'Examinations',
        'Central Library',
        'All Services',
        'Residency & Info',
      ]) {
        expect(find.text(removed), findsNothing, reason: removed);
      }
      expect(find.textContaining('Arun'), findsOneWidget);
    });

    testWidgets('shows counts from the users endpoint only', (tester) async {
      final users = [
        const ManagedTenantUser(
          id: '1',
          name: 'A',
          email: 'a@x',
          roles: [_student],
          active: true,
        ),
        const ManagedTenantUser(
          id: '2',
          name: 'B',
          email: 'b@x',
          roles: [_student],
          active: true,
          yearOfStudy: 3,
        ),
        const ManagedTenantUser(
          id: '3',
          name: 'C',
          email: 'c@x',
          roles: [],
          active: false,
        ),
      ];
      await pump(tester, loader: () async => users);

      expect(find.text('Active users'), findsOneWidget);
      expect(find.text('1 inactive'), findsOneWidget);
      expect(find.text('Need attention'), findsOneWidget);
      expect(find.text('1 no year · 1 no role'), findsOneWidget);
    });

    testWidgets('a failed read never shows zeros', (tester) async {
      await pump(tester, loader: () async => throw Exception('offline'));
      expect(find.textContaining('could not be loaded'), findsOneWidget);
      expect(find.text('Active users'), findsNothing);
    });
  });

  group('user management', () {
    late List<http.Request> requests;
    late Map<String, String> names;
    late AdminStudentRepository repository;

    setUp(() {
      requests = [];
      names = {};
      repository = AdminStudentRepository(
        baseUrl: 'https://api.supercampus.ai',
        accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
        client: MockClient((request) async {
          requests.add(request);
          final path = request.url.path;
          if (request.method == 'GET' && path.endsWith('/authorization/users')) {
            return http.Response(jsonEncode({'data': _usersJson(names)}), 200);
          }
          if (path.endsWith('/authorization/roles')) {
            return http.Response(
              jsonEncode({
                'data': [
                  {'id': 'r-student', 'key': 'student', 'name': 'Student'},
                  {'id': 'r-staff', 'key': 'staff', 'name': 'Faculty'},
                ],
              }),
              200,
            );
          }
          if (request.method == 'PUT' && path.endsWith('/authorization/users/u-1')) {
            names['u-1'] = jsonDecode(request.body)['name'] as String;
          }
          return http.Response(jsonEncode({'data': {}}), 200);
        }),
      );
    });

    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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
    }

    testWidgets('assigns a year to a student listed under "Year not set"', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Year not set'), findsOneWidget);

      await tester.tap(find.widgetWithText(InkWell, 'Assign year').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Year 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save year'));
      await tester.pumpAndSettle();

      final put = requests.lastWhere((r) => r.url.path.endsWith('/year'));
      expect(put.method, 'PUT');
      expect(put.url.path, endsWith('/authorization/users/u-1/year'));
      expect(jsonDecode(put.body), {'yearOfStudy': 2});
    });

    testWidgets('offers "Assign role" on a user without a role', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Assign role'));
      await tester.pumpAndSettle();
      expect(find.text('Choose at least one role for Chitra Devi.'), findsOneWidget);
    });

    testWidgets('a rename is saved to the server and read back from it', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.text('Asha Kumar'));
      await tester.pumpAndSettle();
      expect(find.text('Deactivate user'), findsOneWidget);
      expect(find.text('Year of study'), findsOneWidget);

      await tester.tap(find.text('Edit name and email'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)).first,
        'Asha K',
      );
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      final put = requests.lastWhere(
        (r) => r.method == 'PUT' && r.url.path.endsWith('/users/u-1'),
      );
      expect(jsonDecode(put.body)['name'], 'Asha K');
      expect(
        requests.last.method == 'GET' ||
            requests.any(
              (r) =>
                  r.method == 'GET' &&
                  r.url.path.endsWith('/authorization/users') &&
                  requests.indexOf(r) > requests.indexOf(put),
            ),
        isTrue,
      );
      expect(find.text('Asha K'), findsOneWidget);
    });

    testWidgets('a new student needs a year of study', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Add user'));
      await tester.pumpAndSettle();

      final fields = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(fields.at(0), 'Dev Anand');
      await tester.enterText(fields.at(1), 'dev@mec.local');
      await tester.enterText(fields.at(2), 'Password!2026');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('Student'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create user'));
      await tester.pumpAndSettle();
      expect(find.text("Choose the student's year of study."), findsOneWidget);

      await tester.tap(find.text('Year 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create user'));
      await tester.pumpAndSettle();

      final post = requests.lastWhere((r) => r.method == 'POST');
      expect(jsonDecode(post.body)['yearOfStudy'], 1);
    });
  });
}
