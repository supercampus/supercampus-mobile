import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_orders_screen.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/student_wallet_screen.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/wallet_transaction_details_screen.dart';

const _shops = [
  CanteenShop(
    id: 's1',
    shopKey: 'mec-canteen',
    name: 'Campus Canteen',
    category: 'canteen',
  ),
  CanteenShop(
    id: 's2',
    shopKey: 'mec-stationery',
    name: 'Stationery Store',
    category: 'stationery',
  ),
  CanteenShop(
    id: 's3',
    shopKey: 'mec-laundry',
    name: 'Campus Laundry',
    category: 'laundry',
  ),
];

final _day = DateTime(2026, 9, 20, 12);

CanteenOrder _order(
  String id,
  String itemName, {
  String? shopKey,
  String lineStore = 'mec-canteen',
  String? customer = 'me',
  int dayOffset = 0,
}) {
  return CanteenOrder(
    id: id,
    orderNumber: '${id.hashCode % 9000 + 1000}',
    lines: [
      CartLine(
        item: CanteenMenuItem(
          id: 'item-$id',
          name: itemName,
          description: '',
          category: 'meals',
          price: 40,
          isVegetarian: true,
          store: MenuStoreLabel.parse(lineStore),
          shopKey: lineStore,
        ),
        quantity: 1,
      ),
    ],
    total: 40,
    status: CanteenOrderStatus.completed,
    fulfilmentMode: FulfilmentMode.pickup,
    createdAt: _day.subtract(Duration(days: dayOffset)),
    customerUserId: customer,
    shopKey: shopKey,
  );
}

WalletTransaction _transaction(
  String id,
  String shopKey,
  String description, {
  String? referenceId,
  WalletTransactionType type = WalletTransactionType.debit,
}) {
  return WalletTransaction(
    id: id,
    shopKey: shopKey,
    type: type,
    amount: 40,
    description: description,
    createdAt: _day,
    kind: type == WalletTransactionType.debit ? 'order_debit' : 'manual_top_up',
    referenceId: referenceId,
  );
}

LaundryCharge _charge(
  String id,
  String name,
  LaundryChargeStatus status, {
  String? claimedBy,
}) {
  return LaundryCharge(
    id: id,
    serviceType: LaundryServiceType.wash,
    name: name,
    description: '',
    quantity: 2,
    unitLabel: 'kg',
    unitPrice: 20,
    total: 40,
    status: status,
    createdAt: _day,
    paidAt: status == LaundryChargeStatus.paid ? _day : null,
    claimedBy: claimedBy,
  );
}

CanteenStore _store() {
  return CanteenStore(
    user: const CanteenUser(
      id: 'me',
      name: 'Test Student',
      email: 'student@example.com',
      rollNumber: 'MEC26CS001',
      department: 'CSE',
    ),
    walletBalances: const {
      'mec-canteen': 300,
      'mec-stationery': 200,
      'mec-laundry': 100,
    },
    shops: _shops,
    menu: const [],
    orders: [
      _order('o-canteen', 'Masala Dosa', shopKey: 'mec-canteen'),
      // Placed before orders carried a shop: only the line's legacy store.
      _order('o-canteen-legacy', 'Legacy Idli', lineStore: 'classic'),
      _order(
        'o-bites-legacy',
        'Legacy Puff',
        shopKey: 'bites',
        lineStore: 'bites',
      ),
      _order(
        'o-stationery',
        'Blue Pen',
        shopKey: 'mec-stationery',
        lineStore: 'mec-stationery',
      ),
      _order('o-stationery-legacy', 'Legacy Notebook', lineStore: 'stationery'),
      // Someone else's order in a staff member's counter queue.
      _order(
        'o-not-mine',
        'Queue Samosa',
        shopKey: 'mec-canteen',
        customer: 'someone-else',
      ),
    ],
    walletTransactions: [
      _transaction(
        't-canteen',
        'mec-canteen',
        'Canteen order debit',
        referenceId: 'o-canteen',
      ),
      _transaction(
        't-canteen-topup',
        'mec-canteen',
        'Canteen wallet top-up',
        type: WalletTransactionType.credit,
      ),
      _transaction('t-canteen-legacy', 'classic', 'Legacy canteen debit'),
      _transaction(
        't-stationery',
        'mec-stationery',
        'Stationery order debit',
        referenceId: 'o-stationery',
      ),
      _transaction(
        't-stationery-legacy',
        'stationery',
        'Legacy stationery debit',
      ),
      _transaction(
        't-laundry',
        'mec-laundry',
        'Campus Laundry payment',
        referenceId: 'ch-paid',
      ),
    ],
    laundryCharges: [
      _charge('ch-paid', 'Shirts wash', LaundryChargeStatus.paid),
      _charge('ch-claimed', 'Bedsheet wash', LaundryChargeStatus.claimed),
      // Raised at the counter but not yet claimed by anyone.
      _charge('ch-open', 'Unclaimed bag', LaundryChargeStatus.pending),
      // Another student's charge, visible only in an operator's payload.
      _charge(
        'ch-other',
        'Other student towels',
        LaundryChargeStatus.paid,
        claimedBy: 'someone-else',
      ),
    ],
  );
}

const _allOrderTitles = [
  'Masala Dosa',
  'Legacy Idli',
  'Legacy Puff',
  'Blue Pen',
  'Legacy Notebook',
  'Queue Samosa',
  'Shirts wash',
  'Bedsheet wash',
  'Unclaimed bag',
  'Other student towels',
];

const _allTransactions = [
  'Canteen order debit',
  'Canteen wallet top-up',
  'Legacy canteen debit',
  'Stationery order debit',
  'Legacy stationery debit',
  'Campus Laundry payment',
];

Future<void> _pumpWallet(WidgetTester tester, String shopKey) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StudentWalletSheet(
          store: _store(),
          shopKey: shopKey,
          onTopUp: (_) async => throw UnimplementedError(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectOnly(
  WidgetTester tester, {
  required List<String> orders,
  required List<String> transactions,
}) async {
  for (final title in _allOrderTitles) {
    expect(
      find.text(title),
      orders.contains(title) ? findsOneWidget : findsNothing,
      reason: 'order "$title"',
    );
  }
  await tester.tap(find.text('Transactions'));
  await tester.pumpAndSettle();
  for (final description in _allTransactions) {
    expect(
      find.text(description),
      transactions.contains(description) ? findsOneWidget : findsNothing,
      reason: 'transaction "$description"',
    );
  }
}

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
  });

  test('legacy store keys resolve onto their configured shop', () {
    expect(resolveShopKey('classic', _shops), 'mec-canteen');
    expect(resolveShopKey('canteen', _shops), 'mec-canteen');
    expect(resolveShopKey('bites', _shops), 'mec-canteen');
    expect(resolveShopKey('stationery', _shops), 'mec-stationery');
    expect(resolveShopKey('mec-laundry', _shops), 'mec-laundry');
    // With no shops configured, two keys of one kind still agree.
    expect(sameShop('classic', 'mec-canteen', const []), isTrue);
    expect(sameShop('stationery', 'mec-canteen', const []), isFalse);
  });

  testWidgets('Campus Canteen wallet shows only canteen orders and '
      'transactions', (tester) async {
    await _pumpWallet(tester, 'mec-canteen');
    expect(find.text('Campus Canteen'), findsOneWidget);
    await _expectOnly(
      tester,
      orders: const ['Masala Dosa', 'Legacy Idli', 'Legacy Puff'],
      transactions: const [
        'Canteen order debit',
        'Canteen wallet top-up',
        'Legacy canteen debit',
      ],
    );
  });

  testWidgets('Stationery Store wallet shows only stationery orders and '
      'transactions', (tester) async {
    await _pumpWallet(tester, 'mec-stationery');
    expect(find.text('Stationery Store'), findsOneWidget);
    await _expectOnly(
      tester,
      orders: const ['Blue Pen', 'Legacy Notebook'],
      transactions: const [
        'Stationery order debit',
        'Legacy stationery debit',
      ],
    );
  });

  testWidgets('a legacy stationery key opens the same stationery wallet', (
    tester,
  ) async {
    await _pumpWallet(tester, 'stationery');
    await _expectOnly(
      tester,
      orders: const ['Blue Pen', 'Legacy Notebook'],
      transactions: const [
        'Stationery order debit',
        'Legacy stationery debit',
      ],
    );
  });

  testWidgets('Campus Laundry wallet shows only its own charges and '
      'payments', (tester) async {
    await _pumpWallet(tester, 'mec-laundry');
    expect(find.text('Campus Laundry'), findsOneWidget);
    await _expectOnly(
      tester,
      orders: const ['Shirts wash', 'Bedsheet wash'],
      transactions: const ['Campus Laundry payment'],
    );
  });

  testWidgets('tapping a wallet order opens its pickup view', (tester) async {
    await _pumpWallet(tester, 'mec-canteen');
    await tester.tap(find.byKey(const ValueKey('wallet-order-o-canteen')));
    await tester.pumpAndSettle();
    expect(find.byType(FullScreenOrderQrScreen), findsOneWidget);
    final screen = tester.widget<FullScreenOrderQrScreen>(
      find.byType(FullScreenOrderQrScreen),
    );
    expect(screen.order.id, 'o-canteen');
  });

  testWidgets('tapping a paid laundry charge opens its payment details', (
    tester,
  ) async {
    await _pumpWallet(tester, 'mec-laundry');
    await tester.tap(find.byKey(const ValueKey('wallet-laundry-ch-paid')));
    await tester.pumpAndSettle();
    final screen = tester.widget<WalletTransactionDetailsScreen>(
      find.byType(WalletTransactionDetailsScreen),
    );
    expect(screen.transaction.id, 't-laundry');
  });

  testWidgets('tapping a transaction opens its details page', (tester) async {
    await _pumpWallet(tester, 'mec-stationery');
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('wallet-transaction-t-stationery')),
    );
    await tester.pumpAndSettle();
    final screen = tester.widget<WalletTransactionDetailsScreen>(
      find.byType(WalletTransactionDetailsScreen),
    );
    expect(screen.transaction.id, 't-stationery');
  });
}
