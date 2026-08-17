import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/app.dart';
import 'package:supercampus_mobile/src/core/access/mock_permissions_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/data/mock_auth_repository.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/module_stack.dart';

Widget _testApp() => SupercampusApp(
  authRepository: MockAuthRepository(),
  permissionsRepository: const MockPermissionsRepository(),
);

/// Brings [moduleId] into the module frame, then opens it.
///
/// A card carries `module-bar-<id>` while it waits out of frame and
/// `open-module-<id>` once it is in it, so the key names whatever tapping it
/// will do next. Only one card is in the frame at a time; the dot rail is the
/// direct way to any of the others.
Future<void> _openModule(WidgetTester tester, String moduleId) async {
  final open = find.byKey(ValueKey('open-module-$moduleId'));

  if (!tester.any(open)) {
    final dot = find.byKey(ValueKey('module-dot-$moduleId'));
    await tester.ensureVisible(dot);
    await tester.tap(dot);
    await tester.pumpAndSettle();
  }

  await tester.ensureVisible(open);
  await tester.tap(open);
  await tester.pumpAndSettle();
}

Future<void> _signIn(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('start-sign-in')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('institution-domain')),
    'mec',
  );
  await tester.tap(find.byKey(const ValueKey('continue-from-institution')));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byType(TextFormField).at(0),
    'student@example.com',
  );
  await tester.enterText(find.byType(TextFormField).at(1), 'password123');
  await tester.ensureVisible(find.text('Sign in'));
  await tester.tap(find.text('Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  // The module bars drift forever while at rest, so `pumpAndSettle` would
  // never settle. The same accessibility switch a user flips turns it off.
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
  });

  testWidgets('shows the student login form', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());

    expect(find.text('Your campus, in one place.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('start-sign-in')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('institution-domain')),
      'mec',
    );
    await tester.tap(find.byKey(const ValueKey('continue-from-institution')));
    await tester.pumpAndSettle();

    expect(find.text('SuperCampus'), findsNothing);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('validates empty login fields', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await tester.tap(find.byKey(const ValueKey('start-sign-in')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('institution-domain')),
      'mec',
    );
    await tester.tap(find.byKey(const ValueKey('continue-from-institution')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '');
    await tester.enterText(find.byType(TextFormField).at(1), '');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pump();

    expect(find.text('Enter your email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('signs in and opens the canteen cart', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await _signIn(tester);

    // Every granted module has a dot on the frame's rail, in or out of frame.
    expect(find.byKey(const ValueKey('module-dot-canteen')), findsOneWidget);
    expect(find.byKey(const ValueKey('module-dot-gatepass')), findsOneWidget);

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

  testWidgets('scrolling steps the front module one at a time', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await _signIn(tester);

    // First module in catalog order starts in front of the deck.
    expect(
      find.byKey(const ValueKey('open-module-examination')),
      findsOneWidget,
    );

    final frame = find.byType(ModuleStack);
    await tester.fling(frame, const Offset(0, -60), 600);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('open-module-timetable')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-module-examination')), findsNothing);

    // Flicking back returns to the previous module.
    await tester.fling(frame, const Offset(0, 60), 600);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('open-module-examination')),
      findsOneWidget,
    );
  });

  testWidgets('opens the order history tab', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
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

    await tester.pumpWidget(_testApp());
    await _signIn(tester);

    await tester.tap(find.byKey(const ValueKey('nav-avatar')));
    await tester.pumpAndSettle();

    expect(find.text('Your account'), findsOneWidget);
    expect(find.text('student@example.com'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('profile-sign-out')));
    await tester.pumpAndSettle();

    expect(find.text('SuperCampus'), findsOneWidget);
  });

  testWidgets('search finds a granted module and opens it', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await _signIn(tester);

    await tester.tap(find.byKey(const ValueKey('home-search')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('search-field')), 'cant');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Canteen').last);
    await tester.pumpAndSettle();

    expect(find.text('Canteen is open'), findsOneWidget);
  });

  testWidgets('modules sheet hides modules without grants', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await _signIn(tester);

    await tester.tap(find.byKey(const ValueKey('nav-modules')));
    await tester.pumpAndSettle();

    expect(find.text('Modules'), findsWidgets);
    expect(find.text('Canteen'), findsOneWidget);
    expect(find.text('Vendor Management'), findsNothing);
    expect(find.text('Not enabled for your account'), findsNothing);
  });

  testWidgets('the scan button opens the scanner', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
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

    await tester.pumpWidget(_testApp());
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
