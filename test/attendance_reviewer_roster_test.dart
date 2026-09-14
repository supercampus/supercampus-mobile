import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/features/attendance/data/attendance_repository.dart';
import 'package:supercampus_mobile/src/features/attendance/presentation/attendance_shell.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';

void main() {
  for (final persona in [
    (
      'class_advisor',
      'Class Advisor',
      'assigned',
      'Assigned-class view',
      'submitted_to_advisor',
    ),
    (
      'hod',
      'Head of Department',
      'department',
      'Department view',
      'submitted_to_hod',
    ),
    (
      'principal',
      'Principal',
      'institution',
      'Institution view',
      'submitted_to_principal',
    ),
  ]) {
    testWidgets('${persona.$2} sees present students for a subject', (
      tester,
    ) async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/attendance/sessions')) {
          return http.Response(
            jsonEncode({
              'data': {
                'sessions': [
                  {
                    'id': 'session-1',
                    'subjectName': 'Operating Systems',
                    'heldOn': '2026-09-02',
                    'periodLabel': 'Period 1',
                    'status': persona.$5,
                    'departmentCode': 'CSE',
                    'departmentName': 'Computer Science and Engineering',
                    'presentCount': 1,
                    'absentCount': 1,
                    'onDutyCount': 0,
                  },
                ],
                'departments': persona.$1 == 'principal'
                    ? [
                        {'code': 'AIDS', 'name': 'AI and Data Science'},
                        {'code': 'AIML', 'name': 'AI and Machine Learning'},
                        {
                          'code': 'CSBS',
                          'name': 'Computer Science and Business Systems',
                        },
                        {
                          'code': 'CSE',
                          'name': 'Computer Science and Engineering',
                        },
                        {'code': 'CYBER', 'name': 'Cyber Security'},
                        {'code': 'IT', 'name': 'Information Technology'},
                      ]
                    : persona.$1 == 'hod'
                    ? [
                        {
                          'code': 'CSE',
                          'name': 'Computer Science and Engineering',
                        },
                      ]
                    : [],
              },
            }),
            200,
          );
        }
        if (path.endsWith('/attendance/reports')) {
          return http.Response(
            jsonEncode({
              'data': {'reports': []},
            }),
            200,
          );
        }
        if (path.endsWith('/attendance/sessions/session-1/entries')) {
          return http.Response(
            jsonEncode({
              'data': {
                'entries': [
                  {
                    'studentUserId': 'student-1',
                    'studentName': 'Priya Kumar',
                    'studentNumber': 'MEC26AI001',
                    'status': 'present',
                  },
                  {
                    'studentUserId': 'student-2',
                    'studentName': 'Arun Raman',
                    'studentNumber': 'MEC26AI002',
                    'status': 'absent',
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'data': {}}), 200);
      });
      final permissionAction = persona.$1 == 'principal'
          ? 'attendance.reports.publish'
          : 'attendance.reports.create';
      final permissions = EffectivePermissions.fromJson({
        'grants': [permissionAction, 'attendance.session.publish'],
        'scopes': {
          permissionAction: persona.$3,
          'attendance.session.publish': persona.$3,
        },
      });
      final session = UserSession(
        email: '${persona.$1}@mec.local',
        displayName: persona.$2,
        role: UserRole.staff,
        roleId: persona.$1,
        roleName: persona.$2,
        roleIds: [persona.$1],
      );
      final repository = AttendanceRepository(
        baseUrl: 'http://api.test',
        accessToken: 'token',
        client: client,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AttendanceShell(
            session: session,
            permissions: permissions,
            onExitModule: () {},
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining(persona.$4), findsOneWidget);
      expect(find.text('Present 1'), findsOneWidget);
      expect(find.text('Absent 1'), findsOneWidget);
      expect(find.text('OD 0'), findsOneWidget);
      if (persona.$1 == 'principal') {
        expect(find.textContaining('AIDS'), findsOneWidget);
        expect(find.textContaining('AIML'), findsOneWidget);
        expect(find.textContaining('CSBS'), findsOneWidget);
        expect(find.textContaining('CSE'), findsOneWidget);
        expect(find.textContaining('CYBER'), findsOneWidget);
        expect(find.textContaining('IT'), findsOneWidget);
        expect(find.text('No attendance submitted'), findsNWidgets(5));
      }
      final reviewCard = find.byKey(
        const ValueKey('attendance-review-session-1'),
      );
      await tester.ensureVisible(reviewCard);
      await tester.tap(reviewCard);
      await tester.pumpAndSettle();

      expect(find.textContaining('1 present'), findsOneWidget);
      expect(find.text('Priya Kumar'), findsOneWidget);
      expect(find.text('MEC26AI001'), findsOneWidget);
      expect(find.text('Arun Raman'), findsOneWidget);
      expect(find.text('PRESENT'), findsOneWidget);
      expect(find.text('ABSENT'), findsOneWidget);
      expect(find.text('PK'), findsOneWidget);
      expect(find.text('AR'), findsOneWidget);
      final priyaPhoto = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Priya Kumar student photo',
      );
      expect(priyaPhoto, findsOneWidget);
      expect(
        find.descendant(of: priyaPhoto, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('attendance-export-format')),
        findsOneWidget,
      );
      expect(find.text('PDF'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('download-attendance-report')),
        findsOneWidget,
      );
      expect(find.text('Download'), findsOneWidget);
      if (persona.$1 == 'principal') {
        expect(find.text('Approve & send'), findsNothing);
        expect(find.text('Enquire'), findsNothing);
      } else {
        expect(find.text('Approve & send'), findsOneWidget);
      }
    });
  }

  testWidgets('advisor queue excludes attendance already sent to HOD', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/attendance/sessions')) {
        return http.Response(
          jsonEncode({
            'data': {
              'sessions': [
                {
                  'id': 'waiting',
                  'subjectName': 'Discrete Mathematics',
                  'heldOn': '2026-09-03',
                  'periodLabel': 'Period 4',
                  'status': 'submitted_to_advisor',
                },
                {
                  'id': 'forwarded',
                  'subjectName': 'Library',
                  'heldOn': '2026-09-02',
                  'periodLabel': 'Period 7',
                  'status': 'submitted_to_hod',
                },
              ],
              'departments': [],
            },
          }),
          200,
        );
      }
      return http.Response(jsonEncode({'data': {}}), 200);
    });
    final permissions = EffectivePermissions.fromJson({
      'grants': ['attendance.reports.create'],
      'scopes': {'attendance.reports.create': 'assigned'},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceShell(
          session: const UserSession(
            email: 'advisor@mec.local',
            displayName: 'Class Advisor',
            role: UserRole.staff,
            roleId: 'class_advisor',
            roleName: 'Class Advisor',
            roleIds: ['class_advisor'],
          ),
          permissions: permissions,
          onExitModule: () {},
          repository: AttendanceRepository(
            baseUrl: 'http://api.test',
            accessToken: 'token',
            client: client,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Discrete Mathematics'), findsOneWidget);
    expect(find.text('Library'), findsNothing);
  });

  testWidgets('HOD retains attendance after sending it to the principal', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/attendance/sessions')) {
        return http.Response(
          jsonEncode({
            'data': {
              'sessions': [
                {
                  'id': 'sent-to-principal',
                  'subjectName': 'Discrete Mathematics',
                  'heldOn': '2026-09-03',
                  'periodLabel': 'Period 4',
                  'status': 'submitted_to_principal',
                  'departmentCode': 'CSE',
                  'departmentName': 'Computer Science and Engineering',
                },
              ],
              'departments': [
                {'code': 'CSE', 'name': 'Computer Science and Engineering'},
              ],
            },
          }),
          200,
        );
      }
      if (request.url.path.endsWith('/attendance/reports')) {
        return http.Response(
          jsonEncode({
            'data': {'reports': []},
          }),
          200,
        );
      }
      return http.Response(jsonEncode({'data': {}}), 200);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceShell(
          session: const UserSession(
            email: 'hod.cse@mec.local',
            displayName: 'CSE HOD',
            role: UserRole.staff,
            roleId: 'hod',
            roleName: 'HOD',
            roleIds: ['staff', 'hod'],
          ),
          permissions: EffectivePermissions.fromJson({
            'grants': ['attendance.reports.create'],
            'scopes': {'attendance.reports.create': 'department'},
          }),
          onExitModule: () {},
          repository: AttendanceRepository(
            baseUrl: 'http://api.test',
            accessToken: 'token',
            client: client,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Discrete Mathematics'), findsOneWidget);
    expect(find.text('Received by principal'), findsOneWidget);
  });
}
