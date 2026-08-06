import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/app.dart';

/// Signs in, then scrolls the module carousel to [moduleId] and opens it.
///
/// The dashboard is a snap carousel, so the target card may not be built yet —
/// drag until its button exists, then tap it.
Future<void> _openModule(WidgetTester tester, String moduleId) async {
  final button = find.byKey(ValueKey('open-module-$moduleId'));

  for (var attempt = 0; attempt < 8 && !tester.any(button); attempt++) {
    await tester.drag(find.byType(PageView), const Offset(0, -300));
    await tester.pumpAndSettle();
  }

  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.enterText(
    find.byType(TextFormField).at(0),
    'student@example.com',
  );
  await tester.enterText(find.byType(TextFormField).at(1), 'password123');
  await tester.ensureVisible(find.text('Enter Student Portal'));
  await tester.tap(find.text('Enter Student Portal'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {});

  testWidgets('shows the student login form', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SupercampusApp());

    expect(find.text('SuperCampus'), findsOneWidget);
    expect(find.text('Select Your Campus Portal'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Enter Student Portal'), findsOneWidget);
  });

  testWidgets('validates empty login fields', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SupercampusApp());

    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.enterText(find.byType(TextFormField).at(1), '');
    await tester.ensureVisible(find.text('Enter Student Portal'));
    await tester.tap(find.text('Enter Student Portal'));
    await tester.pump();

    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('signs in and opens the canteen cart', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SupercampusApp());
    await _signIn(tester);

    expect(find.textContaining('5 modules'), findsOneWidget);
    await _openModule(tester, 'canteen');

    expect(find.text('Canteen is open'), findsOneWidget);
    expect(find.text('Meals'), findsWidgets);
    expect(find.text('Parotta with Veg Kurma'), findsOneWidget);

    await tester.tap(find.byTooltip('Add item').first);
    await tester.pump();

    expect(find.text('View cart'), findsOneWidget);
    await tester.tap(find.text('View cart'));
    await tester.pumpAndSettle();

    expect(find.text('Your cart'), findsOneWidget);
    expect(find.text('How will you eat?'), findsOneWidget);
    expect(find.textContaining('Pay ₹79'), findsOneWidget);
  });

  testWidgets('opens the order history tab', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SupercampusApp());
    await _signIn(tester);
    await _openModule(tester, 'canteen');

    await tester.tap(find.text('Orders'));
    await tester.pump();

    expect(find.text('My orders'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('opens the gatepass module and outpass form', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SupercampusApp());
    await _signIn(tester);
    await _openModule(tester, 'gatepass');

    expect(find.text('You are on campus'), findsOneWidget);
    expect(find.text('Apply outpass'), findsOneWidget);
    expect(find.text('Invite visitor'), findsOneWidget);

    await tester.tap(find.text('Apply outpass'));
    await tester.pumpAndSettle();

    expect(find.text('Apply for outpass'), findsOneWidget);
    expect(find.text('Destination'), findsOneWidget);
  });
}
