import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/attendance/presentation/attendance_roster_row.dart';

/// A class is present until told otherwise, so present is the resting state and
/// the two swipes are the exceptions to it: left marks absent, right grants on
/// duty. Tapping a marked row puts the student back to present.
Future<void> pumpRow(
  WidgetTester tester, {
  required List<AttendanceMark> marked,
  AttendanceMark mark = AttendanceMark.present,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            child: AttendanceRosterRow(
              name: 'Priya Kumar',
              number: 'MEC26AI001',
              programme: 'B.E. Artificial Intelligence and Data Science',
              department: 'AIDS',
              mark: mark,
              onMark: marked.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('marking by swipe', () {
    testWidgets('dragging left marks absent', (tester) async {
      final marked = <AttendanceMark>[];
      await pumpRow(tester, marked: marked);

      await tester.drag(find.text('Priya Kumar'), const Offset(-220, 0));
      await tester.pumpAndSettle();

      expect(marked, [AttendanceMark.absent]);
    });

    testWidgets('dragging right grants on duty', (tester) async {
      final marked = <AttendanceMark>[];
      await pumpRow(tester, marked: marked);

      await tester.drag(find.text('Priya Kumar'), const Offset(220, 0));
      await tester.pumpAndSettle();

      expect(marked, [AttendanceMark.onDuty]);
    });

    testWidgets('right does not mark present, which is the resting state', (
      tester,
    ) async {
      final marked = <AttendanceMark>[];
      await pumpRow(tester, marked: marked, mark: AttendanceMark.absent);

      await tester.drag(find.text('Priya Kumar'), const Offset(220, 0));
      await tester.pumpAndSettle();

      // Right is on duty in both directions of travel; present is reached by
      // tapping, not by swiping back.
      expect(marked, [AttendanceMark.onDuty]);
    });

    testWidgets('a short drag that stops before the threshold marks nothing', (
      tester,
    ) async {
      final marked = <AttendanceMark>[];
      await pumpRow(tester, marked: marked);

      // A brushed row must not silently change a student's attendance.
      await tester.drag(find.text('Priya Kumar'), const Offset(-40, 0));
      await tester.pumpAndSettle();

      expect(marked, isEmpty);
    });

    testWidgets('a short hard flick still commits, because momentum projects', (
      tester,
    ) async {
      final marked = <AttendanceMark>[];
      await pumpRow(tester, marked: marked);

      await tester.fling(find.text('Priya Kumar'), const Offset(-60, 0), 1800);
      await tester.pumpAndSettle();

      expect(marked, [AttendanceMark.absent]);
    });

    testWidgets('the row returns home rather than leaving the roll', (
      tester,
    ) async {
      final marked = <AttendanceMark>[];
      await pumpRow(tester, marked: marked);

      await tester.drag(find.text('Priya Kumar'), const Offset(-220, 0));
      await tester.pumpAndSettle();

      // The student is still on the roll; only their mark changed.
      expect(find.text('Priya Kumar'), findsOneWidget);
      expect(find.textContaining('MEC26AI001'), findsOneWidget);
    });

    testWidgets('the action names itself while dragging, before release', (
      tester,
    ) async {
      final marked = <AttendanceMark>[];
      await pumpRow(tester, marked: marked);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Priya Kumar')),
      );
      await gesture.moveBy(const Offset(-150, 0));
      await tester.pump();

      expect(find.text('Absent'), findsOneWidget);
      expect(marked, isEmpty, reason: 'nothing commits until release');

      await gesture.up();
      await tester.pumpAndSettle();
    });

    testWidgets('swiping the way a student is already marked does nothing', (
      tester,
    ) async {
      final marked = <AttendanceMark>[];
      await pumpRow(tester, marked: marked, mark: AttendanceMark.absent);

      // Already absent, so there is no "mark absent" left to reveal.
      await tester.drag(find.text('Priya Kumar'), const Offset(-260, 0));
      await tester.pumpAndSettle();

      expect(marked, isEmpty);
    });
  });

  group('getting back to present', () {
    testWidgets('a tap clears an absence', (tester) async {
      final marked = <AttendanceMark>[];
      await pumpRow(tester, marked: marked, mark: AttendanceMark.absent);

      await tester.tap(find.text('Priya Kumar'));
      await tester.pumpAndSettle();

      expect(marked, [AttendanceMark.present]);
    });

    testWidgets('a tap clears an on-duty consent', (tester) async {
      final marked = <AttendanceMark>[];
      await pumpRow(tester, marked: marked, mark: AttendanceMark.onDuty);

      await tester.tap(find.text('Priya Kumar'));
      await tester.pumpAndSettle();

      expect(marked, [AttendanceMark.present]);
    });

    testWidgets('tapping an unmarked student does nothing', (tester) async {
      final marked = <AttendanceMark>[];
      await pumpRow(tester, marked: marked);

      // Already present. A tap here would be a no-op that still redraws.
      await tester.tap(find.text('Priya Kumar'));
      await tester.pumpAndSettle();

      expect(marked, isEmpty);
    });
  });

  group('the mark is always readable', () {
    testWidgets('the badge carries the mark colour and glyph', (tester) async {
      for (final mark in AttendanceMark.values) {
        await pumpRow(tester, marked: <AttendanceMark>[], mark: mark);
        expect(
          find.byIcon(mark.icon),
          findsOneWidget,
          reason: '${mark.label} glyph missing',
        );
      }
    });

    testWidgets("the colours are the reference card's", (tester) async {
      // Sampled from the artwork rather than guessed at.
      expect(AttendanceMark.present.color, const Color(0xFF00B207));
      expect(AttendanceMark.onDuty.color, const Color(0xFFFFD600));
      expect(AttendanceMark.absent.color, const Color(0xFFC90000));
    });

    testWidgets('the second line names the roll, degree and department', (
      tester,
    ) async {
      await pumpRow(tester, marked: <AttendanceMark>[]);
      expect(find.textContaining('MEC26AI001'), findsOneWidget);
      expect(find.textContaining('B.E., AIDS'), findsOneWidget);
    });

    testWidgets('a student with no programme still shows their number', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: AttendanceRosterRow(
                  name: 'Priya Kumar',
                  number: 'MEC26AI001',
                  mark: AttendanceMark.present,
                  onMark: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('MEC26AI001'), findsOneWidget);
    });

    testWidgets('initials stand in until a photo exists', (tester) async {
      await pumpRow(tester, marked: <AttendanceMark>[]);
      // Most students have no photograph, so this is the ordinary case.
      expect(find.text('PK'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a photograph set in the tenant admin replaces the initials', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 400,
                child: AttendanceRosterRow(
                  name: 'Priya Kumar',
                  number: 'MEC26AI001',
                  photoUrl:
                      'https://res.cloudinary.com/demo/image/upload/v1/mec/p.png',
                  mark: AttendanceMark.present,
                  onMark: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // The widget test has no network, so the image resolves to the error
      // builder and the initials show through. What is assertable here is that
      // the photograph was reached for at all, and at the URL the tenant admin
      // stored — the fallback itself is the subject of the test above.
      expect(find.byType(Image), findsOneWidget);
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as NetworkImage).url,
        'https://res.cloudinary.com/demo/image/upload/v1/mec/p.png',
      );
    });

    testWidgets('the wire values are the ones the API stores', (tester) async {
      expect(AttendanceMark.present.wire, 'present');
      expect(AttendanceMark.absent.wire, 'absent');
      expect(AttendanceMark.onDuty.wire, 'od');
      expect(AttendanceMark.fromWire('od'), AttendanceMark.onDuty);
      expect(AttendanceMark.fromWire('absent'), AttendanceMark.absent);
      // An unset or unknown mark means the student has not been called out of
      // the default, which is present.
      expect(AttendanceMark.fromWire(null), AttendanceMark.present);
      expect(AttendanceMark.fromWire('unexpected'), AttendanceMark.present);
    });
  });
}
