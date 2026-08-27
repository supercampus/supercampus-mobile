import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/canteen/data/mock_canteen_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/student_canteen_home.dart';

/// Drives the real menu screen against the seeded menu, so these assertions
/// break when a storefront stops filtering rather than when a label is reworded.
Future<void> _pumpMenu(WidgetTester tester) async {
  final repository = MockCanteenRepository(
    studentName: 'Test Student',
    email: 'student@example.com',
  );
  // The mock repository sleeps to imitate a round trip, and `testWidgets` runs
  // on a frozen clock, so the load has to happen on the real one.
  final store = (await tester.runAsync(repository.loadStore))!;
  final cart = <String, int>{};

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StudentCanteenHome(
          store: store,
          cart: cart,
          onAdd: (item) => cart[item.id] = (cart[item.id] ?? 0) + 1,
          onRemove: (item) => cart.remove(item.id),
          onOpenCart: () {},
          onOpenWallet: () {},
          onOpenProfile: () {},
          onExitModule: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
  });

  testWidgets('the menu opens on Classic and shows only its items', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpMenu(tester);

    expect(find.text('3 Parotta with Veg Kurma'), findsOneWidget);
    expect(find.text('Kuska'), findsOneWidget);
    // A Bites item must not leak into the Classic counter.
    expect(find.text('Banana cake'), findsNothing);
  });

  testWidgets('switching to Quick Bites swaps the menu over', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpMenu(tester);

    await tester.tap(find.text('Quick Bites'));
    await tester.pumpAndSettle();

    expect(find.text('Banana cake'), findsOneWidget);
    expect(find.text('3 Parotta with Veg Kurma'), findsNothing);
  });

  testWidgets(
    'only Stationery offers aisle filters, and they narrow the list',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pumpMenu(tester);

      // Food storefronts are one flat list, so no "All" chip is offered.
      expect(find.text('All'), findsNothing);

      await tester.tap(find.text('Stationery Store'));
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Shampoo Sachet'), findsOneWidget);
      expect(find.text('Bathing Soap'), findsOneWidget);

      await tester.tap(find.text('Hair Care & Shampoo').last);
      await tester.pumpAndSettle();

      expect(find.text('Shampoo Sachet'), findsOneWidget);
      expect(find.text('Bathing Soap'), findsNothing);
    },
  );

  testWidgets('instant items are badged and the rest are not', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpMenu(tester);

    // Scoped to the instant badge's colour: the "Canteen is open" band uses the
    // same glyph, so a bare icon finder would count it too.
    final instantBadge = find.byWidgetPredicate(
      (widget) =>
          widget is Icon &&
          widget.icon == Icons.bolt &&
          widget.color == const Color(0xFFF97316),
    );

    // Classic seeds three instant items; Kuska is the one that is not.
    expect(instantBadge, findsNWidgets(3));
  });
}
