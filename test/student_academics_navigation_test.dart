import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/academics/data/student_assessments_repository.dart';
import 'package:supercampus_mobile/src/features/academics/presentation/student_academics_shell.dart';
import 'package:supercampus_mobile/src/features/attendance/data/attendance_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';

void main() {
  testWidgets('Academics top displays timetable, history, marks, and attendance without overview table', (
    tester,
  ) async {
    final fakeRepo = _FakeAttendanceRepository();
    final fakeSource = _FakeStudentAssessmentsSource();

    await tester.pumpWidget(
      MaterialApp(
        home: StudentAcademicsShell(
          session: const UserSession(
            email: 'student@example.com',
            displayName: 'Student One',
            role: UserRole.student,
          ),
          onExitModule: () {},
          attendanceRepository: fakeRepo,
          assessmentsSource: fakeSource,
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Verify the 4 key sections are present at the top
    expect(find.text('Class Timetable'), findsOneWidget);
    expect(find.byKey(const ValueKey('attendance-history-link')), findsOneWidget);
    expect(find.byKey(const ValueKey('marks-results-link')), findsOneWidget);
    expect(find.text('Attendance (overall attendance)'), findsOneWidget);

    // 2. Verify Attendance Overview subject breakdown table is REMOVED
    expect(find.text('Attendance Overview'), findsNothing);
    expect(
      find.text('Subject-wise breakdown of attended and missed classes'),
      findsNothing,
    );
    expect(find.text('Discrete Mathematics -C'), findsNothing);

    // 3. Verify Week number, navigation controls and week picker
    expect(find.byKey(const ValueKey('attendance-week-picker')), findsOneWidget);
    expect(find.byKey(const ValueKey('attendance-prev-week')), findsOneWidget);
    expect(find.byKey(const ValueKey('attendance-next-week')), findsOneWidget);

    // Initial week should display week text (e.g. Week 4)
    expect(find.textContaining('Week 4'), findsOneWidget);

    // 4. Test Previous Week navigation
    await tester.tap(find.byKey(const ValueKey('attendance-prev-week')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Week 3'), findsOneWidget);

    // 5. Test Next Week navigation
    await tester.tap(find.byKey(const ValueKey('attendance-next-week')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Week 4'), findsOneWidget);

    // 6. Test Preferred Week picker modal sheet
    await tester.tap(find.byKey(const ValueKey('attendance-week-picker')));
    await tester.pumpAndSettle();

    expect(find.text('Select Week'), findsOneWidget);
    expect(find.text('Week 1'), findsOneWidget);
    expect(find.text('Week 2'), findsOneWidget);

    // Select Week 2
    await tester.tap(find.text('Week 2'));
    await tester.pumpAndSettle();

    // Picker closed and Week 2 is now active
    expect(find.text('Select Week'), findsNothing);
    expect(find.textContaining('Week 2'), findsOneWidget);
  });
}

class _FakeStudentAssessmentsSource implements StudentAssessmentsSource {
  @override
  Future<List<StudentAssessment>> loadAssessments() async => const [];
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
        'records': [
          {
            'sessionId': 'session-latest',
            'heldOn': '2026-08-28',
            'subjectCode': 'CS101',
            'subjectName': 'Data Structures',
            'periodLabel': 'Period 6-Period 7',
            'startsAt': '13:50:00',
            'endsAt': '15:30:00',
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
