import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/students/student_year.dart';

void main() {
  test('legacy Roman numeral years are recognized', () {
    expect(parseStudentYear('I'), 1);
    expect(parseStudentYear('Year II'), 2);
  });

  test('students without a year join the second-year group', () {
    final groups = groupStudentsByYear<String>(const [
      'legacy',
      'first-year',
    ], (student) => student == 'first-year' ? 1 : null);

    expect(groups.map((group) => group.label), [
      '1st year students',
      '2nd year students',
    ]);
    expect(groups.last.students, ['legacy']);
  });

  test('the removed unassigned label is never returned', () {
    expect(studentYearLabel(null), '2nd year students');
  });
}
