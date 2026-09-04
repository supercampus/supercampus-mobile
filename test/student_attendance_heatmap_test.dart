import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/academics/presentation/student_academics_shell.dart';
import 'package:supercampus_mobile/src/features/attendance/data/attendance_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';

void main() {
  testWidgets('overall card owns the weekly attendance heatmap', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentAcademicsShell(
          session: const UserSession(
            email: 'student@example.com',
            displayName: 'Student One',
            role: UserRole.student,
          ),
          onExitModule: () {},
          attendanceRepository: _FakeAttendanceRepository(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    Finder heatCell(String label) => find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == label,
    );

    expect(find.text('Overall attendance'), findsOneWidget);
    expect(
      find.text('9 present  •  2 absent  •  1 OD  •  0 leave'),
      findsOneWidget,
    );
    expect(heatCell('Monday period 1: absent'), findsOneWidget);
    expect(heatCell('Monday period 2: present'), findsOneWidget);
    expect(heatCell('Wednesday period 4: on duty'), findsOneWidget);
    expect(heatCell('Wednesday period 7: on duty'), findsOneWidget);
    expect(heatCell('Friday period 7: present'), findsOneWidget);
    expect(find.text('Recent classes'), findsNothing);
    expect(find.text('Subject attendance'), findsNothing);
  });

  testWidgets('attendance history opens complete class details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentAcademicsShell(
          session: const UserSession(
            email: 'student@example.com',
            displayName: 'Student One',
            role: UserRole.student,
          ),
          onExitModule: () {},
          attendanceRepository: _FakeAttendanceRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('attendance-history-page')), findsNothing);
    final historyLink = find.byKey(const ValueKey('attendance-history-link'));
    await tester.scrollUntilVisible(
      historyLink,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(historyLink);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('attendance-history-page')),
      findsOneWidget,
    );
    expect(find.text('Attendance history'), findsOneWidget);
    expect(find.text('Data Structures'), findsWidgets);
    final historyCard = find.byKey(
      const ValueKey('attendance-history-session-latest'),
    );
    await tester.scrollUntilVisible(
      historyCard,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(historyCard);
    await tester.pumpAndSettle();

    expect(find.text('Friday'), findsOneWidget);
    expect(find.text('Dr. N. Saranya'), findsOneWidget);
    expect(find.text('1:50 PM – 3:30 PM'), findsOneWidget);
    expect(find.text('100 minutes'), findsOneWidget);
    expect(find.text('LH-302'), findsOneWidget);
  });
}

class _FakeAttendanceRepository extends AttendanceRepository {
  _FakeAttendanceRepository()
    : super(baseUrl: 'http://127.0.0.1', accessToken: 'test-token');

  @override
  Future<Map<String, dynamic>> summary(String studentUserId) async => {
    'totalClasses': 12,
    'attendedClasses': 10,
    'presentClasses': 9,
    'absences': 2,
    'onDutyClasses': 1,
    'leaveClasses': 0,
    'percentage': 83,
    'bySubject': [
      {
        'subjectOfferingId': 'offering-1',
        'subjectCode': 'CS101',
        'subjectName': 'Data Structures',
        'totalClasses': 12,
        'presentClasses': 9,
        'absentClasses': 2,
        'onDutyClasses': 1,
        'leaveClasses': 0,
        'percentage': 83,
      },
    ],
    'records': [
      {
        'sessionId': 'session-latest',
        'heldOn': '2026-08-28',
        'subjectCode': 'CS101',
        'subjectName': 'Data Structures',
        'periodLabel': 'Period 6-Period 7',
        'facultyName': 'Dr. N. Saranya',
        'startsAt': '13:50:00',
        'endsAt': '15:30:00',
        'durationMinutes': 100,
        'sectionName': 'CSE - Section A',
        'roomCode': 'LH-302',
        'status': 'present',
      },
      {
        'heldOn': '2026-08-26',
        'periodLabel': 'Period 4-Period 7',
        'status': 'od',
      },
      {'heldOn': '2026-08-24', 'periodLabel': 'Period 2', 'status': 'present'},
      {'heldOn': '2026-08-24', 'periodLabel': 'Period 1', 'status': 'absent'},
    ],
  };
}
