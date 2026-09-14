import 'package:flutter_test/flutter_test.dart';
import '../lib/src/features/admin_portal/presentation/student_account_import_page.dart';

void main() {
  test('accepts eight characters and rejects seven', () {
    final row = ['Student','413200000002','test@example.test','9000000000','CSE','1','A','Abcd1234'];
    expect(parseStudentAccounts([studentAccountHeaders,row]), hasLength(1));
    row[7] = 'Abcd123';
    expect(() => parseStudentAccounts([studentAccountHeaders,row]), throwsFormatException);
  });
  final valid = ['Student Name','413200000001','student@example.test','9000000000','CSE','1','A','UniquePassword!123'];
  test('first-year identity stays attached to its own row', () {
    final result = parseStudentAccounts([studentAccountHeaders, valid]);
    expect(result.single['name'], 'Student Name');
    expect(result.single['year'], 1);
    expect(result.single['rollNo'], '413200000001');
  });
  test('rejects duplicate, invalid year and weak passwords', () {
    expect(() => parseStudentAccounts([studentAccountHeaders,valid,valid]), throwsFormatException);
    final wrongYear = [...valid]..[5] = '0';
    expect(() => parseStudentAccounts([studentAccountHeaders,wrongYear]), throwsFormatException);
    final weak = [...valid]..[7] = 'short';
    expect(() => parseStudentAccounts([studentAccountHeaders,weak]), throwsFormatException);
  });
  test('CSV preserves quoted names and exact password bytes', () {
    final parsed = parseStudentCsv('"Name, With Comma",two,"pass""word"\r\n');
    expect(parsed.single, ['Name, With Comma','two','pass"word']);
    expect(() => parseStudentCsv('"unclosed'), throwsFormatException);
  });
}
