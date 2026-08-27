import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/access/module_catalog.dart';
import 'package:supercampus_mobile/src/features/attendance/data/attendance_repository.dart';
import 'package:supercampus_mobile/src/features/attendance/presentation/attendance_shell.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';

/// The grants and scopes faculty01@mec.local actually receives from
/// /api/v1/bootstrap: section reach, and not one approve or publish. Scope is
/// the only thing separating them from a student, which is why this persona is
/// the one worth testing.
EffectivePermissions facultyPermissions() => EffectivePermissions.fromJson({
  'grants': [
    'attendance.roster.read',
    'attendance.roster.update',
    'attendance.records.create',
    'attendance.session.create',
    'academics.marks.read',
    'academics.assignments.read',
  ],
  'scopes': {
    'attendance.roster.read': 'assigned',
    'attendance.roster.update': 'assigned',
    'attendance.records.create': 'assigned',
    'attendance.session.create': 'assigned',
    'academics.marks.read': 'assigned',
    'academics.assignments.read': 'assigned',
  },
});

const _session = UserSession(
  email: 'faculty01@mec.local',
  displayName: 'Divya Raman',
  role: UserRole.staff,
  staffId: 'MECEMP008',
  // Staff have no section of their own. This is exactly the condition that
  // used to send `null` to the roster endpoint and get a 400 back.
  sectionId: null,
);

/// Mirrors the real payloads: only classes assigned to the teacher in today's
/// published timetable, each carrying the section and timetable entry.
Map<String, dynamic> _context() => {
  'data': {
    'classes': [
      {
        'timetableEntryId': '11111111-1111-4111-8111-111111111111',
        'subjectOfferingId': '22222222-2222-4222-8222-222222222222',
        'sectionId': 'section-aids',
        'sectionName': 'AIDS - Section A',
        'subjectCode': 'AIDS103',
        'subjectName': 'Operating Systems',
        'periodLabel': 'Period 1',
      },
      {
        'timetableEntryId': '33333333-3333-4333-8333-333333333333',
        'subjectOfferingId': '44444444-4444-4444-8444-444444444444',
        'sectionId': 'section-cse',
        'sectionName': 'CSE - Section A',
        'subjectCode': 'CSE104',
        'subjectName': 'Computer Networks',
        'periodLabel': 'Period 2',
      },
    ],
  },
};

Map<String, dynamic> _roster(String sectionId) => {
  'data': {
    'students': sectionId == 'section-aids'
        ? [
            {
              'studentUserId': 'u-1',
              'studentName': 'Priya Kumar',
              'studentNumber': 'MEC26AI001',
              'sectionId': sectionId,
            },
            {
              'studentUserId': 'u-2',
              'studentName': 'Arun Raman',
              'studentNumber': 'MEC26AI002',
              'sectionId': sectionId,
            },
          ]
        : [
            {
              'studentUserId': 'u-9',
              'studentName': 'Sneha Iyer',
              'studentNumber': 'MEC26CS001',
              'sectionId': sectionId,
            },
          ],
  },
};

void main() {
  late List<String> calls;
  final entries = <Map<String, dynamic>>[];

  AttendanceRepository repository({
    bool noClasses = false,
    List<Map<String, dynamic>> sessions = const [],
  }) {
    calls = [];
    final client = MockClient((request) async {
      final path = request.url.path;
      calls.add('${request.method} $path?${request.url.query}');

      if (path.endsWith('/attendance/classes')) {
        final body = _context();
        if (noClasses) {
          (body['data'] as Map<String, dynamic>)['classes'] = [];
        }
        return http.Response(jsonEncode(body), 200);
      }
      if (path.endsWith('/attendance/roster')) {
        final sectionId = request.url.queryParameters['sectionId'];
        // The endpoint this screen exists to satisfy: a roster is only ever
        // asked for against a section.
        if (sectionId == null || sectionId.isEmpty) {
          return http.Response(
            jsonEncode({
              'error': 'sectionId is required at this access level',
              'code': 'bad_request',
            }),
            400,
          );
        }
        return http.Response(jsonEncode(_roster(sectionId)), 200);
      }
      if (path.endsWith('/attendance/sessions') && request.method == 'GET') {
        return http.Response(
          jsonEncode({
            'data': {'sessions': sessions},
          }),
          200,
        );
      }
      if (path.endsWith('/attendance/sessions') && request.method == 'POST') {
        return http.Response(
          jsonEncode({
            'data': {'id': 'session-1'},
          }),
          201,
        );
      }
      if (path.contains('/sessions/session-1/entries')) {
        entries
          ..clear()
          ..addAll(
            ((jsonDecode(request.body) as Map<String, dynamic>)['entries']
                    as List)
                .cast<Map<String, dynamic>>(),
          );
        return http.Response(jsonEncode({'data': {}}), 200);
      }
      return http.Response(jsonEncode({'data': {}}), 200);
    });

    return AttendanceRepository(
      baseUrl: 'http://api.test',
      accessToken: 'token',
      client: client,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    AttendanceRepository repo, {
    String? timetableEntryId,
    String? sectionId,
    String? subjectName,
    String? periodLabel,
    bool openImmediately = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceShell(
          session: _session,
          permissions: facultyPermissions(),
          onExitModule: () {},
          repository: repo,
          initialTimetableEntryId: timetableEntryId,
          initialSectionId: sectionId,
          initialSubjectName: subjectName,
          initialPeriodLabel: periodLabel,
          openSelectedClassImmediately: openImmediately,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('faculty land on a class, not on an empty roster', (
    tester,
  ) async {
    await pump(tester, repository());

    // The first assigned class is chosen so the common case takes no taps.
    expect(find.text('Operating Systems'), findsWidgets);
    expect(find.text('Start attendance'), findsOneWidget);
  });

  testWidgets('the roster is never requested without a section', (
    tester,
  ) async {
    await pump(tester, repository());

    final rosterCalls = calls.where((c) => c.contains('/attendance/roster'));
    expect(rosterCalls, isNotEmpty);
    for (final call in rosterCalls) {
      expect(
        call.contains('sectionId=section-'),
        isTrue,
        reason: 'a section-scoped roster call must name its section: $call',
      );
    }
  });

  testWidgets('marking a class loads that section and only that section', (
    tester,
  ) async {
    await pump(tester, repository());

    await tester.tap(find.text('Start attendance'));
    await tester.pumpAndSettle();

    expect(find.text('Priya Kumar'), findsOneWidget);
    expect(find.text('Arun Raman'), findsOneWidget);
    // A student of the other section must not appear on this roll.
    expect(find.text('Sneha Iyer'), findsNothing);
    expect(find.text('2 present'), findsOneWidget);
  });

  testWidgets('switching class swaps the roster', (tester) async {
    await pump(tester, repository());

    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Computer Networks'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start attendance'));
    await tester.pumpAndSettle();

    expect(find.text('Sneha Iyer'), findsOneWidget);
    expect(find.text('Priya Kumar'), findsNothing);
  });

  testWidgets('a dashboard row opens the exact subject, section and period', (
    tester,
  ) async {
    await pump(
      tester,
      repository(),
      timetableEntryId: '33333333-3333-4333-8333-333333333333',
      sectionId: 'section-cse',
      subjectName: 'Computer Networks',
      periodLabel: 'Period 2',
    );

    expect(find.text('Computer Networks'), findsWidgets);
    expect(find.text('CSE - Section A'), findsOneWidget);
    expect(find.text('CSE104'), findsOneWidget);
    expect(find.text('Period 2'), findsOneWidget);
    expect(calls.any((call) => call.contains('sectionId=section-cse')), isTrue);

    await tester.tap(find.text('Start attendance'));
    await tester.pumpAndSettle();
    expect(find.text('Sneha Iyer'), findsOneWidget);
    expect(find.text('Priya Kumar'), findsNothing);
  });

  testWidgets('a dashboard class card bypasses the attendance overview', (
    tester,
  ) async {
    await pump(
      tester,
      repository(
        sessions: [
          {
            'id': 'draft-eda',
            'subjectName': 'Operating Systems',
            'heldOn': '2026-08-26',
            'periodLabel': 'Period 1',
            'status': 'draft',
          },
        ],
      ),
      timetableEntryId: '11111111-1111-4111-8111-111111111111',
      sectionId: 'section-aids',
      subjectName: 'Operating Systems',
      periodLabel: 'Period 1',
      openImmediately: true,
    );

    expect(find.text('Resume unfinished roll'), findsNothing);
    expect(find.text('Recent rolls'), findsNothing);
    expect(find.text('Priya Kumar'), findsOneWidget);
    expect(find.text('Arun Raman'), findsOneWidget);
    expect(find.text('2 present'), findsOneWidget);
  });

  testWidgets('a dashboard class card starts a new exact roll directly', (
    tester,
  ) async {
    await pump(
      tester,
      repository(),
      timetableEntryId: '33333333-3333-4333-8333-333333333333',
      sectionId: 'section-cse',
      subjectName: 'Computer Networks',
      periodLabel: 'Period 2',
      openImmediately: true,
    );

    expect(find.text('Start attendance'), findsNothing);
    expect(find.text('Sneha Iyer'), findsOneWidget);
    expect(find.text('1 present'), findsOneWidget);
    expect(
      calls.any(
        (call) => call == 'POST /api/v1/operations/attendance/sessions?',
      ),
      isTrue,
    );
  });

  testWidgets('class cannot be switched while a roll is open', (tester) async {
    await pump(tester, repository());

    await tester.tap(find.text('Start attendance'));
    await tester.pumpAndSettle();

    // Marks belong to the roster they were made against; swapping underneath
    // them would publish the wrong students.
    expect(find.text('Change'), findsNothing);
    expect(find.text('Publish to switch'), findsNothing);
    expect(find.text('ACTIVE CLASS'), findsOneWidget);
    expect(find.text('Period 1'), findsOneWidget);
  });

  testWidgets('a swipe on the roll reaches the published entries', (
    tester,
  ) async {
    entries.clear();
    await pump(tester, repository());

    await tester.tap(find.text('Start attendance'));
    await tester.pumpAndSettle();

    // Left on the first student: the gesture, not a segmented control, is what
    // records the mark. A flick rather than a long drag, because that is how a
    // roll is actually taken — momentum projection is what commits it.
    await tester.fling(find.text('Priya Kumar'), const Offset(-160, 0), 2000);
    await tester.pumpAndSettle();
    expect(find.text('1 present'), findsOneWidget);
    expect(find.text('1 absent'), findsOneWidget);

    await tester.tap(find.textContaining('Publish 1 absent'));
    await tester.pumpAndSettle();

    final priya = entries.firstWhere((e) => e['studentUserId'] == 'u-1');
    final arun = entries.firstWhere((e) => e['studentUserId'] == 'u-2');
    expect(priya['status'], 'absent');
    expect(arun['status'], 'present');
  });

  testWidgets('an unfinished roll is offered back, not buried in history', (
    tester,
  ) async {
    await pump(
      tester,
      repository(
        sessions: [
          {
            'id': 'draft-1',
            'subjectName': 'Operating Systems',
            'heldOn': '2026-08-22',
            'periodLabel': '01:18',
            'status': 'draft',
          },
        ],
      ),
    );

    // A draft is an interrupted roll. The screenful of dead "draft" rows was
    // the thing worth removing.
    expect(find.text('Resume unfinished roll'), findsOneWidget);
    expect(find.text('Start attendance'), findsNothing);
    expect(find.text('Nothing published yet'), findsOneWidget);
  });

  testWidgets('published rolls are the history, drafts are not', (
    tester,
  ) async {
    await pump(
      tester,
      repository(
        sessions: [
          {
            'id': 'draft-1',
            'subjectName': 'Computer Networks',
            'heldOn': '2026-08-22',
            'status': 'draft',
          },
          {
            'id': 'done-1',
            'subjectName': 'Operating Systems',
            'heldOn': '2026-08-21',
            'status': 'published_to_hod',
          },
        ],
      ),
    );

    expect(find.text('Recent rolls'), findsOneWidget);
    expect(find.text('2026-08-21'), findsOneWidget);
    // The draft belongs to another class, so it is neither resumed here nor
    // listed as something that happened.
    expect(find.text('2026-08-22'), findsNothing);
    expect(find.text('Start attendance'), findsOneWidget);
  });

  testWidgets('resuming opens the roll for marking', (tester) async {
    await pump(
      tester,
      repository(
        sessions: [
          {
            'id': 'draft-1',
            'subjectName': 'Operating Systems',
            'heldOn': '2026-08-22',
            'periodLabel': '01:18',
            'status': 'draft',
          },
        ],
      ),
    );

    await tester.tap(find.text('Resume unfinished roll'));
    await tester.pumpAndSettle();

    expect(find.text('Priya Kumar'), findsOneWidget);
    expect(find.text('2 present'), findsOneWidget);
  });

  testWidgets('staff with no teaching assignment are told why', (tester) async {
    await pump(tester, repository(noClasses: true));

    expect(find.text('No classes assigned yet'), findsOneWidget);
    // Not a silent empty roster.
    expect(find.text('Start attendance'), findsNothing);
  });

  testWidgets('a student never reaches the marking view', (tester) async {
    final student = EffectivePermissions.fromJson({
      'grants': ['attendance.leave.create', 'academics.marks.read'],
      'scopes': {
        'attendance.leave.create': 'own',
        'academics.marks.read': 'own',
      },
    });
    expect(student.scopeFor(ModuleCatalog.attendance), PermissionScope.own);

    await tester.pumpWidget(
      MaterialApp(
        home: AttendanceShell(
          session: _session,
          permissions: student,
          onExitModule: () {},
          repository: repository(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Start attendance'), findsNothing);
    expect(find.text('Change'), findsNothing);
    expect(
      calls.any((call) => call.contains('academic-assignments')),
      isFalse,
      reason: 'a learner has no classes to teach',
    );
  });
}
