import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/advisor/data/advisor_students_repository.dart';
import 'package:supercampus_mobile/src/features/advisor/presentation/advisor_students_section.dart';

void main() {
  testWidgets('advisor sees mini cards and can open full student data', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdvisorStudentsSection(
            source: _StudentsSource([
              const AdvisorStudent(
                userId: 'user-1',
                studentId: 'student-1',
                number: 'MEC25AD01',
                name: 'Abinaya S',
                departmentCode: 'AIDS',
                status: 'active',
                email: 'abinaya@example.com',
                phone: '6380214119',
                departmentName: 'Artificial Intelligence & Data Science',
                programmeName: 'B.Tech AI & DS',
                academicYear: '2026-27',
                sectionName: 'AIDS - Section A',
                campusName: 'MEC Main Campus',
                profile: {'residency': 'day_scholar'},
              ),
              const AdvisorStudent(
                userId: 'user-2',
                studentId: 'student-2',
                number: 'MEC25AD02',
                name: 'Bharathi P',
                departmentCode: 'AIDS',
                status: 'active',
              ),
            ]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your students'), findsOneWidget);
    expect(find.text('Abinaya S'), findsOneWidget);
    expect(find.text('Bharathi P'), findsOneWidget);

    await tester.tap(find.text('Abinaya S'));
    await tester.pumpAndSettle();

    expect(find.text('abinaya@example.com'), findsOneWidget);
    expect(find.text('6380214119'), findsOneWidget);
    expect(find.text('B.Tech AI & DS'), findsOneWidget);
  });

  testWidgets('advisor can create a manual test for a student', (tester) async {
    final source = _StudentsSource([
      const AdvisorStudent(
        userId: 'user-1',
        studentId: 'student-1',
        number: 'MEC25AD01',
        name: 'Abinaya S',
        departmentCode: 'AIDS',
        status: 'active',
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdvisorStudentsSection(source: source)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abinaya S'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Other test'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other test'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Test name'),
      'Weekly quiz 3',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'Marks'), '17.5');
    await tester.enterText(find.widgetWithText(TextFormField, 'Out of'), '20');
    await tester.tap(find.text('Save marks'));
    await tester.pumpAndSettle();

    expect(source.savedInput?.kind, AdvisorAssessmentKind.test);
    expect(source.savedInput?.title, 'Weekly quiz 3');
    expect(find.text('17.5 / 20'), findsOneWidget);
  });
}

class _StudentsSource implements AdvisorStudentsSource {
  _StudentsSource(this.students);
  final List<AdvisorStudent> students;
  AdvisorAssessmentInput? savedInput;

  @override
  Future<List<AdvisorStudent>> loadStudents() async => students;

  @override
  Future<List<AdvisorAssessment>> loadAssessments(String studentId) async =>
      const [];

  @override
  Future<AdvisorAssessment> saveAssessment(
    String studentId,
    AdvisorAssessmentInput input, {
    String? assessmentId,
  }) async {
    savedInput = input;
    return AdvisorAssessment(
      id: assessmentId ?? 'assessment-1',
      kind: input.kind,
      title: input.title,
      semester: input.semester,
      marksObtained: input.marksObtained,
      maximumMarks: input.maximumMarks,
      notes: input.notes,
    );
  }
}
