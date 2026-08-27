import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/widgets/campus_nav_bar.dart';

void main() {
  testWidgets('home and modules use light inactive and bold selected states', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(selectedId: 'home'));

    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(_label(tester, 'Home').fontWeight, FontWeight.w700);
    expect(_label(tester, 'Modules').fontWeight, FontWeight.w400);

    await tester.pumpWidget(_bar(selectedId: 'modules'));
    await tester.pump();

    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(_label(tester, 'Home').fontWeight, FontWeight.w400);
    expect(_label(tester, 'Modules').fontWeight, FontWeight.w700);
  });

  testWidgets('scan action is a pill aligned with the navigation bar', (
    tester,
  ) async {
    await tester.pumpWidget(_bar(selectedId: 'home'));

    final scan = find.byKey(const ValueKey('nav-scan'));
    final decorationFinder = find.descendant(
      of: scan,
      matching: find.byType(DecoratedBox),
    );
    final decorated = tester.widget<DecoratedBox>(decorationFinder.first);
    final decoration = decorated.decoration as BoxDecoration;
    final radius = decoration.borderRadius! as BorderRadius;

    expect(radius.topLeft.x, closeTo(tester.getSize(scan).height / 2, .1));
  });
}

TextStyle _label(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

Widget _bar({required String selectedId}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.bottomCenter,
      child: CampusNavBar(
        selectedId: selectedId,
        initials: 'AS',
        onHome: () {},
        onModules: () {},
        onProfile: () {},
        onScan: () {},
      ),
    ),
  ),
);
