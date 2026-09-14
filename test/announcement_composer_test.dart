import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/widgets/announcement_composer.dart';

void main() {
  testWidgets('requires and returns the standard announcement fields', (
    tester,
  ) async {
    AnnouncementDraft? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                saved = await showAnnouncementComposer(context);
              },
              child: const Text('Compose'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Compose'));
    await tester.pumpAndSettle();

    expect(find.text('Announcement type'), findsOneWidget);
    expect(find.text('Select date'), findsOneWidget);
    expect(find.text('Title'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Announcement image'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Announcement type'),
      'Campus Event',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title'),
      'Innovation Day',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Description'),
      'Student registrations are now open.',
    );
    await tester.tap(find.text('Choose announcement date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DateTime.now().day.toString()).last);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save announcement'));
    await tester.tap(find.text('Save announcement'));
    await tester.pumpAndSettle();

    expect(saved?.type, 'Campus Event');
    expect(saved?.title, 'Innovation Day');
    expect(saved?.description, 'Student registrations are now open.');
    expect(saved?.date.day, DateTime.now().day);
  });
}
