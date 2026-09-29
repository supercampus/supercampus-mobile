import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/admin_portal/data/admin_roles_repository.dart';
import 'package:supercampus_mobile/src/features/admin_portal/data/admin_student_repository.dart';
import 'package:supercampus_mobile/src/features/admin_portal/presentation/admin_roles_page.dart';
import 'package:supercampus_mobile/src/features/admin_portal/presentation/admin_users_page.dart';

Map<String, dynamic> _user(String id, String name, String email) => {
  'id': id,
  'name': name,
  'email': email,
  'active': true,
  'roles': [
    {'id': 'role-staff', 'key': 'staff', 'name': 'Staff'},
  ],
};

void main() {
  group('user deletion', () {
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
                  _user('me', 'Arun Iyer', 'admin@mec.local'),
                  _user('u1', 'Asha Nair', 'asha@mec.local'),
                  _user('u2', 'Bala Kumar', 'bala@mec.local'),
                ],
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/authorization/roles')) {
            return http.Response(
              jsonEncode({
                'data': [
                  {'id': 'role-staff', 'key': 'staff', 'name': 'Staff'},
                ],
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/bulk-delete')) {
            final ids = (jsonDecode(request.body)['ids'] as List).cast<String>();
            return http.Response(
              jsonEncode({
                'data': {'deleted': ids, 'failed': []},
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'data': {}}), 200);
        }),
      );
    });

    Future<void> pumpPage(WidgetTester tester, {required bool canDelete}) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminUsersPage(
            repository: repository,
            currentUserEmail: 'admin@mec.local',
            canDelete: canDelete,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('select mode is hidden without the delete permission', (
      tester,
    ) async {
      await pumpPage(tester, canDelete: false);
      expect(find.text('Select'), findsNothing);
    });

    testWidgets(
      'select all skips oneself and bulk delete confirms the count first',
      (tester) async {
        await pumpPage(tester, canDelete: true);
        await tester.tap(find.text('Select'));
        await tester.pumpAndSettle();
        expect(find.text('Select users'), findsOneWidget);

        await tester.tap(find.text('Select all'));
        await tester.pumpAndSettle();
        expect(find.text('2 selected'), findsOneWidget);

        await tester.tap(find.byTooltip('Delete selected'));
        await tester.pumpAndSettle();
        expect(find.text('Delete 2 users?'), findsOneWidget);
        expect(find.textContaining('cannot be undone'), findsOneWidget);

        await tester.tap(find.text('Delete 2 users'));
        await tester.pumpAndSettle();

        final delete = requests.singleWhere(
          (request) => request.url.path.endsWith('/bulk-delete'),
        );
        expect(delete.method, 'POST');
        expect(jsonDecode(delete.body), {
          'ids': ['u1', 'u2'],
        });
        expect(find.text('2 users were deleted.'), findsOneWidget);
      },
    );

    testWidgets('cancelling the confirmation deletes nothing', (tester) async {
      await pumpPage(tester, canDelete: true);
      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Asha Nair'));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete selected'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Asha Nair?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        requests.where((request) => request.url.path.endsWith('/bulk-delete')),
        isEmpty,
      );
    });
  });

  group('roles', () {
    test('groups the catalogue by module and hides reserved permissions', () {
      const permissions = [
        PermissionDefinition(
          key: 'fees.records.read',
          moduleKey: 'fees',
          featureKey: 'records',
          action: 'read',
          name: 'View fee records',
        ),
        PermissionDefinition(
          key: '*',
          moduleKey: '*',
          featureKey: '*',
          action: '*',
          name: 'Everything',
        ),
        PermissionDefinition(
          key: 'platform.configuration.update',
          moduleKey: 'platform',
          featureKey: 'configuration',
          action: 'update',
          name: 'Platform',
        ),
        PermissionDefinition(
          key: 'vendor_management.shops.read',
          moduleKey: 'vendor_management',
          featureKey: 'shops',
          action: 'read',
          name: 'View shops',
        ),
      ];
      final groups = groupPermissions(permissions);
      expect(groups.keys, ['fees', 'vendor_management']);
      expect(groupPermissions(permissions, query: 'shops').keys, [
        'vendor_management',
      ]);
      expect(moduleLabel('vendor_management'), 'Vendor management');
      expect(roleKeyFromName(' Hostel Warden! '), 'hostel_warden');
    });

    testWidgets('lists roles with members and guards protected ones', (
      tester,
    ) async {
      final repository = AdminRolesRepository(
        baseUrl: 'https://api.supercampus.ai',
        accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
        client: MockClient((request) async {
          if (request.url.path.endsWith('/authorization/roles')) {
            return http.Response(
              jsonEncode({
                'data': [
                  {
                    'id': 'r1',
                    'key': 'tenant_admin',
                    'name': 'Tenant Admin',
                    'team': 'Administration',
                    'scope': 'Runs the campus',
                    'portalFamily': 'staff',
                    'protected': true,
                    'system': true,
                    'memberCount': 1,
                  },
                  {
                    'id': 'r2',
                    'key': 'warden',
                    'name': 'Warden',
                    'team': 'Hostel',
                    'scope': 'Looks after the hostel',
                    'portalFamily': 'staff',
                    'memberCount': 2,
                    'permissionsBySurface': {
                      'app': [
                        {'key': 'hostel.rooms.read', 'scope': 'institution'},
                      ],
                      'website': [],
                    },
                  },
                ],
              }),
              200,
            );
          }
          return http.Response(jsonEncode({'data': []}), 200);
        }),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminRolesPage(
            repository: repository,
            canCreate: true,
            canUpdate: true,
            canDelete: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Warden'), findsOneWidget);
      expect(find.text('Protected'), findsOneWidget);
      expect(find.text('New role'), findsOneWidget);

      await tester.tap(find.text('Tenant Admin'));
      await tester.pumpAndSettle();
      expect(
        find.text('This is a protected system role. It cannot be changed.'),
        findsOneWidget,
      );
      expect(find.text('Delete role'), findsNothing);
    });
  });
}
