import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/timetable/data/timetable_repository.dart';

void main() {
  test('home and timetable resolve a UUID claim to the authorized class', () {
    final selected = studentTimetableClassFor(
      availableClasses: const ['AIDS - Section A', 'Elective Group 1'],
      claimedSectionId: '5ca7cd48-b35c-43d3-81ac-f302b05e2c77',
    );

    expect(selected, 'AIDS - Section A');
  });

  test('a matching readable section claim remains selected', () {
    final selected = studentTimetableClassFor(
      availableClasses: const ['AIDS - Section A', 'AIDS - Section B'],
      claimedSectionId: 'aids - section b',
    );

    expect(selected, 'AIDS - Section B');
  });
}
