import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/modules/data/glance_source.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/today_glance.dart';

void main() {
  test('latest published roll is the final box', () {
    final marks = recentAttendanceMarks([
      {'status': 'absent'},
      {'status': 'present'},
      {'status': 'od'},
    ]);

    expect(marks, [
      null,
      null,
      null,
      null,
      AttendanceMark.onDuty,
      AttendanceMark.present,
      AttendanceMark.absent,
    ]);
  });

  test('only the latest seven rolls remain in chronological order', () {
    final marks = recentAttendanceMarks([
      {'status': 'od'},
      {'status': 'absent'},
      {'status': 'present'},
      {'status': 'present'},
      {'status': 'absent'},
      {'status': 'present'},
      {'status': 'od'},
      {'status': 'absent'},
    ]);

    expect(marks, [
      AttendanceMark.onDuty,
      AttendanceMark.present,
      AttendanceMark.absent,
      AttendanceMark.present,
      AttendanceMark.present,
      AttendanceMark.absent,
      AttendanceMark.onDuty,
    ]);
  });
}
