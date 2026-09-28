import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/students/student_year.dart';

void main() {
  test('legacy Roman numeral years are recognized', () {
    expect(parseStudentYear('I'), 1);
    expect(parseStudentYear('Year II'), 2);
  });

  test('students without a year are grouped last, not as 2nd year', () {
    final groups = groupStudentsByYear<String>(const [
      'legacy',
      'first-year',
    ], (student) => student == 'first-year' ? 1 : null);

    expect(groups.map((group) => group.label), [
      '1st year students',
      'Year not set',
    ]);
    expect(groups.last.students, ['legacy']);
  });

  test('an academic session is not a year of study', () {
    expect(parseStudentYear('2026-27'), isNull);
    expect(studentYearLabel(null), 'Year not set');
    expect(studentYearLabel(2), '2nd year students');
  });
}
