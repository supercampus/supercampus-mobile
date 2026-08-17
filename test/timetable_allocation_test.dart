import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/timetable/data/mock_timetable_repository.dart';

void main() {
  test('allocator generates seven periods for every working day', () {
    final repository = MockTimetableRepository();
    final config = repository.getConfig().copyWith(batchSection: 'ECE-2A');

    final generated = repository.generateAiCandidate(config);

    expect(generated, hasLength(config.workingDays.length * 7));
    expect(generated.every((entry) => entry.className == 'ECE-2A'), isTrue);
    expect(
      generated.every((entry) => entry.subjectCode.startsWith('EC')),
      isTrue,
    );
    for (final day in config.workingDays) {
      final periods = generated
          .where((entry) => entry.dayOfWeek == day)
          .map((entry) => entry.periodIndex)
          .toSet();
      expect(periods, {1, 2, 3, 4, 5, 6, 7});
    }
  });

  test('assigning a generated timetable replaces the selected class only', () {
    final repository = MockTimetableRepository();
    final originalOtherClass = repository.getEntriesForClass('CS-3A').length;
    final config = repository.getConfig().copyWith(batchSection: 'ME-2B');
    final generated = repository.generateAiCandidate(config);

    repository.replaceClassSchedule('ME-2B', generated);

    expect(repository.getEntriesForClass('ME-2B'), hasLength(generated.length));
    expect(
      repository.getEntriesForClass('CS-3A'),
      hasLength(originalOtherClass),
    );
  });

  test(
    'staff timetable includes assignments across classes and departments',
    () {
      final repository = MockTimetableRepository();
      final faculty = repository.getFacultyList().first;
      final csAssignment = repository
          .getEntriesForClass('CS-3A')
          .first
          .copyWith(
            id: 'STAFF-CS',
            facultyId: faculty.id,
            facultyName: faculty.name,
          );
      final eceAssignment = csAssignment.copyWith(
        id: 'STAFF-ECE',
        className: 'ECE-2A',
        periodIndex: 7,
      );
      repository.addEntry(eceAssignment);

      final staffEntries = repository.getEntriesForFaculty(
        faculty.name,
        facultyId: faculty.id,
      );

      expect(staffEntries.map((entry) => entry.className), contains('CS-3A'));
      expect(staffEntries.map((entry) => entry.className), contains('ECE-2A'));
    },
  );
}
