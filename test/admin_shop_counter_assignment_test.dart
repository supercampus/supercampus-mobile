import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/admin_portal/data/admin_student_repository.dart';
import 'package:supercampus_mobile/src/features/admin_portal/presentation/admin_users_page.dart';

/// Giving someone a shop-counter role opens the counter choice in the same
/// flow, so a new captain is never left with an empty queue.
void main() {
  testWidgets('granting a counter role asks which shops, and saves them', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final repository = AdminStudentRepository(
      baseUrl: 'https://api.supercampus.ai',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
      client: MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/authorization/users')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'user-9',
                  'name': 'New Captain',
                  'email': 'newcap@mec.local',
                  'active': true,
                  'roles': [
                    {'id': 'role-staff', 'key': 'staff', 'name': 'Staff'},
                  ],
                },
              ],
            }),
            200,
          );
        }
        if (path.endsWith('/authorization/roles')) {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'role-staff',
                  'key': 'staff',
                  'name': 'Staff',
                  'active': true,
                  'permissions': [],
                },
                {
                  // Named freely by the tenant: only the grants matter.
                  'id': 'role-cap',
                  'key': 'counter_crew',
                  'name': 'Canteen captain',
                  'active': true,
                  'permissions': [
                    {'key': 'canteen.orders.manage', 'scope': 'assigned'},
                  ],
                },
              ],
            }),
            200,
          );
        }
        if (path.endsWith('/canteen/shops/assignments/user-9')) {
          if (request.method == 'PUT') {
            return http.Response(jsonEncode({'data': {}}), 200);
          }
          return http.Response(
            jsonEncode({
              'data': {
                'userId': 'user-9',
                'shops': [
                  {
                    'shopKey': 'mec-stationery',
                    'name': 'Campus Stationery',
                    'category': 'stationery',
                    'assignmentRole': null,
                  },
                  {
                    'shopKey': 'mec-canteen',
                    'name': 'Canteen',
                    'category': 'canteen',
                    'assignmentRole': null,
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'data': {}}), 200);
      }),
    );

    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AdminUsersPage(repository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Manage New Captain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit roles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Canteen captain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save roles'));
    await tester.pumpAndSettle();

    // The counter choice follows straight away, in the admin's shop order.
    expect(find.text('Choose counters'), findsOneWidget);
    final stationery = tester.getTopLeft(find.text('Campus Stationery')).dy;
    final canteen = tester.getTopLeft(find.text('Canteen')).dy;
    expect(stationery, lessThan(canteen));

    await tester.tap(find.text('Canteen'));
    await tester.pumpAndSettle();
    expect(find.text('Captain'), findsOneWidget);
    await tester.tap(find.text('Save counters'));
    await tester.pumpAndSettle();

    final put = requests.lastWhere(
      (r) => r.method == 'PUT' && r.url.path.contains('/assignments/'),
    );
    expect(jsonDecode(put.body), {
      'assignments': [
        {'shopKey': 'mec-canteen', 'assignmentRole': 'captain'},
      ],
    });
    expect(find.text('Choose counters'), findsNothing);
  });

  test('roles carry their permission keys', () async {
    final repository = AdminStudentRepository(
      baseUrl: 'https://api.supercampus.ai',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'r',
                'key': 'captain',
                'name': 'Captain',
                'active': true,
                'permissions': [
                  {'key': 'canteen.orders.manage'},
                ],
              },
            ],
          }),
          200,
        ),
      ),
    );
    final roles = await repository.listRoles();
    expect(roles.single.permissionKeys, ['canteen.orders.manage']);
  });
}
