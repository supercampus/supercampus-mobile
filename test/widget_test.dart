import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/app.dart';

/// Expands [moduleId] in the module accordion, then opens it.
///
/// An item carries `module-bar-<id>` while collapsed and `open-module-<id>`
/// once expanded, so the key names whatever tapping it will do next.
Future<void> _openModule(WidgetTester tester, String moduleId) async {
  final bar = find.byKey(ValueKey('module-bar-$moduleId'));
  if (tester.any(bar)) {
    await tester.ensureVisible(bar);
    await tester.tap(bar);
    await tester.pumpAndSettle();
  }

  final open = find.byKey(ValueKey('open-module-$moduleId'));
  await tester.ensureVisible(open);
  await tester.tap(open);
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

    // The granted modules are listed as collapsed accordion bars.
    expect(find.byKey(const ValueKey('module-bar-canteen')), findsOneWidget);
    expect(find.byKey(const ValueKey('module-bar-gatepass')), findsOneWidget);

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

  testWidgets('scrolling steps the expanded module one at a time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SupercampusApp());
    await _signIn(tester);

    // First module in catalog order starts expanded.
    expect(find.byKey(const ValueKey('open-module-timetable')), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('module-bar-attendance')),
      const Offset(0, -90),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('open-module-attendance')), findsOneWidget);
    expect(find.byKey(const ValueKey('module-bar-timetable')), findsOneWidget);

    // Dragging back returns to the previous module, once the step lock has
    // expired.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.drag(
      find.byKey(const ValueKey('module-bar-timetable')),
      const Offset(0, 90),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('open-module-timetable')), findsOneWidget);
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

  testWidgets('the nav bar avatar opens the account sheet and signs out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SupercampusApp());
    await _signIn(tester);

    await tester.tap(find.byKey(const ValueKey('nav-avatar')));
    await tester.pumpAndSettle();

    expect(find.text('Your account'), findsOneWidget);
    expect(find.text('student@example.com'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-sign-out')));
    await tester.pumpAndSettle();

    expect(find.text('Select Your Campus Portal'), findsOneWidget);
  });

  testWidgets('search finds a granted module and opens it', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SupercampusApp());
    await _signIn(tester);

    await tester.tap(find.byKey(const ValueKey('home-search')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('search-field')), 'cant');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Canteen').last);
    await tester.pumpAndSettle();

    expect(find.text('Canteen is open'), findsOneWidget);
  });

  testWidgets('the scan button opens the scanner', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SupercampusApp());
    await _signIn(tester);

    await tester.tap(find.byKey(const ValueKey('nav-center')));
    await tester.pumpAndSettle();

    expect(find.text('Scan counter QR'), findsOneWidget);
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
