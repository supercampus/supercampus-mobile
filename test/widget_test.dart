import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/app.dart';
import 'package:supercampus_mobile/src/core/access/mock_permissions_repository.dart';
import 'package:supercampus_mobile/src/features/authentication/data/mock_auth_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/mock_canteen_repository.dart';
import 'package:supercampus_mobile/src/features/gatepass/data/mock_gatepass_repository.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/module_stack.dart';

/// The identity [MockAuthRepository] issues for the credentials [_signIn] uses.
/// The module mocks below are seeded with it so the screens read the same way
/// they would had the shells built their own mocks from the session.
const _mockStudentName = 'Vishnu Sudharshan';
const _mockStudentEmail = 'student@example.com';

/// Module repositories are injected rather than left to default, because a
/// mock sign-in produces a session with no bearer token, and the backend
/// repositories the app would otherwise build require one.
Widget _testApp() => SupercampusApp(
  authRepository: MockAuthRepository(),
  permissionsRepository: const MockPermissionsRepository(),
  canteenRepository: MockCanteenRepository(
    studentName: _mockStudentName,
    email: _mockStudentEmail,
  ),
  gatepassRepository: MockGatepassRepository(
    studentName: _mockStudentName,
    email: _mockStudentEmail,
  ),
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
  final tappableCard = find.ancestor(
    of: open,
    matching: find.byType(GestureDetector),
  );
  await tester.tap(tappableCard.first);
  // Data skeletons correctly stop animating for reduced-motion users. Advance
  // the mock repository timer explicitly before waiting for layout to settle.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
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
  // Skeletons are static when reduced motion is enabled, so explicitly move
  // through the mocked permission request instead of relying on animation
  // frames to advance this timer.
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 300));
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
    expect(find.text('Email address or mobile number'), findsOneWidget);
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

    expect(
      find.text('Enter your email address or mobile number.'),
      findsOneWidget,
    );
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

    expect(find.text('Shops are open'), findsOneWidget);
    // Storefront selection is covered by canteen_storefronts_test.dart. This
    // smoke test follows one real menu item through to the cart.
    expect(find.text('3 Parotta with Veg Kurma'), findsWidgets);

    final addItem = find.byTooltip('Add item');
    await tester.ensureVisible(addItem.last);
    await tester.pumpAndSettle();
    final addInkWell = find.descendant(
      of: addItem.last,
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(addInkWell).onTap!();
    await tester.pump();

    expect(find.text('View cart'), findsOneWidget);
    final cartInkWell = find.ancestor(
      of: find.text('View cart'),
      matching: find.byType(InkWell),
    );
    tester.widget<InkWell>(cartInkWell).onTap!();
    await tester.pumpAndSettle();

    expect(find.text('Your cart'), findsOneWidget);
    // Every shop hands its order over at its own counter, so there is no
    // dine-in / pickup choice left to make.
    expect(find.text('How will you eat?'), findsNothing);
  });

  testWidgets('scrolling steps the front module one at a time', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await _signIn(tester);

    // This account is own-scoped everywhere, so it is a learner: examinations,
    // the timetable and academics fold into one Academics entry, which takes
    // the first of their catalog positions and so starts in front of the deck.
    expect(find.byKey(const ValueKey('open-module-academics')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('open-module-examination')),
      findsNothing,
      reason: 'a learner has no separate Examinations module',
    );
    expect(
      find.byKey(const ValueKey('open-module-timetable')),
      findsNothing,
      reason: 'a learner has no separate Timetable module',
    );

    final frame = find.byType(ModuleStack);
    await tester.fling(frame, const Offset(0, -60), 600);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('open-module-canteen')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-module-academics')), findsNothing);

    // Flicking back returns to the previous module.
    await tester.fling(frame, const Offset(0, 60), 600);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('open-module-academics')), findsOneWidget);
  });

  testWidgets('opens the order history tab', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await _signIn(tester);

    // Orders is a quick action on the canteen card, not a tab inside the
    // module, so the card only has to come into frame — opening the module
    // first would leave the dashboard and take the action with it.
    final canteenDot = find.byKey(const ValueKey('module-dot-canteen'));
    await tester.ensureVisible(canteenDot);
    await tester.tap(canteenDot);
    await tester.pumpAndSettle();

    final ordersAction = find.byKey(const ValueKey('quick-action-orders'));
    await tester.ensureVisible(ordersAction);
    await tester.tap(ordersAction);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('My orders'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
  });

  testWidgets('the profile tab opens the account sheet and signs out', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await _signIn(tester);

    // The account sheet hangs off the nav bar's profile destination; the
    // standalone avatar button it used to sit behind is gone.
    await tester.tap(find.byKey(const ValueKey('nav-profile')));
    await tester.pumpAndSettle();

    expect(find.text(_mockStudentName), findsWidgets);
    expect(find.text(_mockStudentEmail), findsWidgets);

    // Signing out now sits one level in, under Settings, rather than on the
    // account sheet itself.
    await tester.tap(find.text('Settings').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('SuperCampus'), findsOneWidget);
  });

  testWidgets('home header keeps search and AI shortcuts out of the way', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp());
    await _signIn(tester);

    expect(find.byKey(const ValueKey('home-search')), findsNothing);
    expect(find.byKey(const ValueKey('home-insights')), findsNothing);
    expect(find.byKey(const ValueKey('home-alerts')), findsOneWidget);
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
    expect(find.text('Shops'), findsOneWidget);
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

    // The scanner is the wide slab on the right of the one nav bar; the raised
    // circle in the middle of the old two-bar layout is gone.
    await tester.tap(find.byKey(const ValueKey('nav-scan')));
    await tester.pumpAndSettle();

    // The nav opens the campus scan screen, which keeps the camera inside its
    // own card. 'Scan counter QR' is the canteen module's own scanner tab.
    expect(find.text('Scan QR'), findsOneWidget);
    expect(find.byKey(const ValueKey('scan-close')), findsOneWidget);

    // Closing has to actually leave the route. The screen holds a PopScope so
    // it can play its exit first, and popping through that guard rather than
    // around it once stranded the user on a bare black screen with the card
    // already animated away.
    await tester.tap(find.byKey(const ValueKey('scan-close')));
    await tester.pumpAndSettle();

    expect(find.text('Scan QR'), findsNothing);
    expect(find.byKey(const ValueKey('nav-scan')), findsOneWidget);
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
