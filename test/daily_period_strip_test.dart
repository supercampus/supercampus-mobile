import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/timetable/data/timetable_models.dart';
import 'package:supercampus_mobile/src/features/timetable/presentation/widgets/daily_period_strip.dart';

void main() {
  testWidgets('renders seven horizontally scrollable daily periods', (
    tester,
  ) async {
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
      tester
          .widget<ListView>(find.byKey(const ValueKey('daily-period-strip')))
          .scrollDirection,
      Axis.horizontal,
    );
    expect(find.text('Subject 1'), findsOneWidget);

    await tester.fling(
      find.byKey(const ValueKey('daily-period-strip')),
      const Offset(-2200, 0),
      4000,
    );
    await tester.pumpAndSettle();

    expect(find.text('Subject 7'), findsOneWidget);
  });
}
