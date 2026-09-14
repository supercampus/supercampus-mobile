import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/timetable/data/timetable_models.dart';
import 'package:supercampus_mobile/src/features/timetable/presentation/widgets/daily_period_strip.dart';

void main() {
  testWidgets('renders seven compact vertical daily periods', (tester) async {
    final entries = List.generate(
      7,
      (index) => TimetableEntry(
        id: 'entry-$index',
        subjectCode: 'SUB${index + 1}',
        subjectName: 'Subject ${index + 1}',
        facultyId: 'staff-${index + 1}',
        facultyName: 'Staff ${index + 1}',
        className: 'CS-3A',
        dayOfWeek: 'Monday',
        timeSlot: 'Period ${index + 1}',
        periodIndex: index + 1,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DailyPeriodStrip(
            periodsPerDay: 7,
            entries: entries,
            audience: TimetableAudience.student,
          ),
        ),
      ),
    );

    expect(find.text('7 of 7 assigned'), findsOneWidget);
    expect(find.byKey(const ValueKey('daily-period-strip')), findsOneWidget);
    expect(
      tester.widget<Column>(find.byKey(const ValueKey('daily-period-strip'))),
      isA<Column>(),
    );
    expect(find.text('Subject 1'), findsOneWidget);
    expect(find.text('Subject 7'), findsOneWidget);
    expect(find.text('SUB1'), findsNothing);
  });

  testWidgets(
    'cleans timetable abbreviations and mojibake from subject names',
    (tester) async {
      final entry = TimetableEntry(
        id: 'entry-1',
        subjectCode: 'CS25C01',
        subjectName: 'Operating Systems â€“(OS)',
        facultyId: 'staff-1',
        facultyName: 'Dr. Faculty',
        className: 'CS-3A',
        dayOfWeek: 'Monday',
        timeSlot: '10:30 – 11:20',
        periodIndex: 1,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DailyPeriodStrip(
              periodsPerDay: 1,
              entries: [entry],
              audience: TimetableAudience.student,
            ),
          ),
        ),
      );

      expect(find.text('Operating Systems'), findsOneWidget);
      expect(find.textContaining('CS25C01'), findsNothing);
      expect(find.textContaining('â€'), findsNothing);
    },
  );
}
