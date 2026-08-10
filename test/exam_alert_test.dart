import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/timetable/data/timetable_models.dart';
import 'package:supercampus_mobile/src/features/timetable/presentation/widgets/exam_alert_section.dart';

TimetableEntry _exam({required String timeSlot, DateTime? date}) =>
    TimetableEntry(
      id: 'exam-1',
      subjectCode: 'CS302',
      subjectName: 'Operating Systems',
      facultyId: 'f1',
      facultyName: 'Prof. Sarah Jenkins',
      className: 'CS-3A',
      dayOfWeek: 'Wednesday',
      timeSlot: timeSlot,
      periodIndex: 1,
      periodType: PeriodType.examType,
      examTitle: 'Midterm Examination',
      examDate: date ?? DateTime(2026, 8, 12),
      hallNumber: 'Hall 3B',
      seatNumber: 'Desk #24',
    );

void main() {
  group('examStartOf', () {
    test('reads a slot that spells out both meridiems', () {
      final start = examStartOf(_exam(timeSlot: '08:30 AM – 10:20 AM'));
      expect(start, DateTime(2026, 8, 12, 8, 30));
    });

    test('borrows the meridiem the start time leaves off', () {
      final start = examStartOf(_exam(timeSlot: '02:00 - 02:50 PM'));
      expect(start, DateTime(2026, 8, 12, 14, 0));
    });

    test(
      'pulls the start back a half day when borrowing overshoots the end',
      () {
        // 11:30 borrowing the end's PM would land after 12:20 PM, so it is a
        // morning slot that runs over noon.
        final start = examStartOf(_exam(timeSlot: '11:30 - 12:20 PM'));
        expect(start, DateTime(2026, 8, 12, 11, 30));
      },
    );

    test('falls back to the date when the slot has no clock time', () {
      final start = examStartOf(_exam(timeSlot: 'Second session'));
      expect(start, DateTime(2026, 8, 12));
    });

    test('has no start without a date', () {
      final undated = TimetableEntry(
        id: 'exam-2',
        subjectCode: 'CS301',
        subjectName: 'Database Systems',
        facultyId: 'f1',
        facultyName: 'Prof. Sarah Jenkins',
        className: 'CS-3A',
        dayOfWeek: 'Friday',
        timeSlot: '09:30 AM – 11:10 AM',
        periodIndex: 1,
        periodType: PeriodType.examType,
      );

      expect(examStartOf(undated), isNull);
    });
  });

  testWidgets('offers an alert time and reports when it would arrive', (
    tester,
  ) async {
    final exam = _exam(
      timeSlot: '08:30 AM – 10:20 AM',
      // Far enough out that every preset is still ahead of now.
      date: DateTime.now().add(const Duration(days: 30)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExamAlertSection(exam: exam)),
      ),
    );

    expect(find.text('Remind me about this exam'), findsOneWidget);
    expect(find.text('Choose when to be alerted'), findsOneWidget);

    await tester.tap(find.text('1 day before'));
    await tester.pump();

    expect(find.textContaining('Notifies you on'), findsOneWidget);
    expect(find.text('Set alert'), findsOneWidget);
  });

  testWidgets('a preset that has already passed cannot be chosen', (
    tester,
  ) async {
    // An exam an hour from now: "1 day before" is long gone.
    final soon = DateTime.now().add(const Duration(hours: 1));
    final exam = _exam(
      timeSlot:
          '${soon.hour.toString().padLeft(2, '0')}:'
          '${soon.minute.toString().padLeft(2, '0')} '
          '${soon.hour < 12 ? 'AM' : 'PM'} – 11:59 PM',
      date: DateTime(soon.year, soon.month, soon.day),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ExamAlertSection(exam: exam)),
      ),
    );

    await tester.tap(find.text('1 day before'));
    await tester.pump();

    // Nothing was selected, so there is still nothing to confirm.
    expect(find.text('Choose when to be alerted'), findsOneWidget);
    expect(find.textContaining('Notifies you on'), findsNothing);
  });
}
