import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/academics/data/student_assessments_repository.dart';
import 'package:supercampus_mobile/src/features/academics/presentation/student_academics_shell.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';

void main() {
  testWidgets('advisor-entered marks appear in student Academics', (
    tester,
  ) async {
    final source = _FakeStudentAssessmentsSource();
    await tester.pumpWidget(
      MaterialApp(
        home: StudentAcademicsShell(
          session: const UserSession(
            email: 'student@example.com',
            displayName: 'Student One',
            role: UserRole.student,
          ),
          onExitModule: () {},
          assessmentsSource: source,
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('marks-results-page')), findsNothing);
    final marksLink = find.byKey(const ValueKey('marks-results-link'));
    await tester.scrollUntilVisible(
      marksLink,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(marksLink);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('marks-results-page')), findsOneWidget);
    expect(find.text('Data Structures Internal 1'), findsOneWidget);
    expect(
      find.text('MA301  •  Internal assessment  •  Semester 2'),
      findsOneWidget,
    );
    expect(find.text('42 / 50'), findsOneWidget);
    expect(find.text('84%'), findsOneWidget);
    expect(source.loads, 1);
  });
}

class _FakeStudentAssessmentsSource implements StudentAssessmentsSource {
  int loads = 0;

  @override
  Future<List<StudentAssessment>> loadAssessments() async {
    loads += 1;
    return const [
      StudentAssessment(
        id: 'assessment-1',
        kind: StudentAssessmentKind.internal,
        title: 'Data Structures Internal 1',
        subjectCode: 'MA301',
        semester: 2,
        marksObtained: 42,
        maximumMarks: 50,
        notes: 'Good improvement',
      ),
    ];
  }
}
