import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/data/mock_canteen_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_orders_screen.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/student_wallet_screen.dart';

Future<CanteenStore> _loadStore(WidgetTester tester) async {
  final repository = MockCanteenRepository(
    studentName: 'Test Student',
    email: 'student@example.com',
  );
  // The mock sleeps to imitate a round trip and `testWidgets` freezes the
  // clock, so the load runs on the real one.
  return (await tester.runAsync(repository.loadStore))!;
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
  });

  testWidgets('the wallet carries both histories, opening on orders', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = await _loadStore(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentWalletSheet(
            store: store,
            onTopUp: (_) async => throw UnimplementedError(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Both records are reachable from the wallet, which is the only way in now
    // that the balance pill is the entry point.
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Transactions'), findsOneWidget);

    // Orders lead, because "what did I order?" is the commoner question.
    final firstOrder = store.orders.first;
    expect(find.textContaining(firstOrder.lines.first.item.name), findsWidgets);

    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();

    expect(
      find.text(store.walletTransactions.first.description),
      findsOneWidget,
    );
  });

  testWidgets('top-up validation uses the accountant configured range', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await _loadStore(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentWalletSheet(
            store: store,
            topUpSettings: const WalletTopUpSettings(
              minimumAmount: 250,
              maximumAmount: 5000,
            ),
            onTopUp: (_) async => throw UnimplementedError(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top up'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '100');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(
      find.text('Enter an amount between ₹250 and ₹5,000.'),
      findsOneWidget,
    );
  });

  testWidgets('My orders offers a way back out', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = await _loadStore(tester);
    var wentBack = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CanteenOrdersScreen(
            orders: store.orders,
            onBack: () => wentBack = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Reachable only through a quick action, with no nav bar to leave by, this
    // page would otherwise strand the reader on it.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(wentBack, isTrue);
  });

  test(
    'settled and active orders are separable, which both histories rely on',
    () {
      // The owner queue shows active orders and folds the rest into "Settled";
      // the student wallet lists them all. Both depend on this split.
      expect(CanteenOrderStatus.pending.isActive, isTrue);
      expect(CanteenOrderStatus.accepted.isActive, isTrue);
      expect(CanteenOrderStatus.preparing.isActive, isTrue);
      expect(CanteenOrderStatus.ready.isActive, isTrue);

      expect(CanteenOrderStatus.completed.isActive, isFalse);
      expect(CanteenOrderStatus.rejected.isActive, isFalse);
      expect(CanteenOrderStatus.cancelled.isActive, isFalse);
    },
  );
}
