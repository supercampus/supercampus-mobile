import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/accountant_wallet_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/accountant_wallet_screen.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_cart_screen.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/student_canteen_home.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/student_wallet_screen.dart';
import 'package:supercampus_mobile/src/features/vendor_management/data/vendor_models.dart';
import 'package:supercampus_mobile/src/features/vendor_management/data/vendor_repository.dart';
import 'package:supercampus_mobile/src/features/vendor_management/presentation/vendor_management_shell.dart';

// The user's example: the campus canteen with Meals, Beverages and Snacks
// counters. Akhil runs Meals and Beverages, Shashi runs Snacks, and the
// accounts desk can limit credit to one counter.
const _canteen = CanteenShop(
  id: 'shop-canteen',
  shopKey: 'mec-canteen',
  name: 'Campus Canteen',
  category: 'canteen',
);
const _meals = CanteenShop(
  id: 'shop-meals',
  shopKey: 'mec-canteen-meals',
  name: 'Meals',
  category: 'canteen',
  parentShopKey: 'mec-canteen',
);
const _drinks = CanteenShop(
  id: 'shop-drinks',
  shopKey: 'mec-canteen-beverages',
  name: 'Beverages',
  category: 'canteen',
  parentShopKey: 'mec-canteen',
);
const _snacks = CanteenShop(
  id: 'shop-snacks',
  shopKey: 'mec-canteen-snacks',
  name: 'Snacks',
  category: 'canteen',
  parentShopKey: 'mec-canteen',
);
const _laundry = CanteenShop(
  id: 'shop-laundry',
  shopKey: 'mec-laundry',
  name: 'Campus Laundry',
  category: 'laundry',
);
const _shops = [_canteen, _meals, _drinks, _snacks, _laundry];

CanteenMenuItem _item(String id, String name, String shopKey, double price) =>
    CanteenMenuItem(
      id: id,
      name: name,
      description: '',
      category: 'food',
      price: price,
      isVegetarian: true,
      shopKey: shopKey,
    );

final _meal = _item('meal', 'Veg Meals', 'mec-canteen-meals', 45);
final _soda = _item('soda', 'Lime Soda', 'mec-canteen-beverages', 20);
final _samosa = _item('samosa', 'Samosa', 'mec-canteen-snacks', 15);

/// ₹50 for the whole canteen, ₹100 for Snacks only.
const _balances = {'mec-canteen': 50.0, 'mec-canteen-snacks': 100.0};

CanteenStore _store({List<CanteenShop> shops = _shops}) => CanteenStore(
  user: const CanteenUser(
    id: 'student-1',
    name: 'Student One',
    email: 'student001@mec.local',
    rollNumber: 'MEC001',
    department: 'CSE',
  ),
  walletBalances: _balances,
  menu: [_meal, _soda, _samosa],
  orders: const [],
  walletTransactions: const [],
  shops: shops,
);

void main() {
  group('scoped canteen credit', () {
    test('a counter spends its own credit first, then the canteen credit', () {
      final plan = planWalletDebits(
        [(shop: 'mec-canteen-snacks', total: 120)],
        _balances,
        _shops,
      );
      expect(plan.failedAt, isNull);
      expect(plan.debits.single, const [
        WalletDebit(bucket: 'mec-canteen-snacks', amount: 100),
        WalletDebit(bucket: 'mec-canteen', amount: 20),
      ]);
    });

    test('other counters can use only the canteen credit, shared once', () {
      final plan = planWalletDebits(
        [
          (shop: 'mec-canteen-meals', total: 45),
          (shop: 'mec-canteen-beverages', total: 20),
        ],
        _balances,
        _shops,
      );
      expect(plan.failedAt, 1);
      expect(plan.debits.single, const [
        WalletDebit(bucket: 'mec-canteen', amount: 45),
      ]);
    });

    test('the breakdown names general and counter-only credit', () {
      final breakdown = walletBreakdownOf(
        'mec-canteen-snacks',
        _balances,
        _shops,
      );
      expect(breakdown.walletKey, 'mec-canteen');
      expect(breakdown.total, 150);
      expect(breakdown.spendableAt('mec-canteen-snacks'), 150);
      expect(breakdown.spendableAt('mec-canteen-meals'), 50);
      // A canteen without counters is one plain wallet.
      final plain = walletBreakdownOf('mec-laundry', {
        'mec-laundry': 30,
      }, _shops);
      expect(plain.hasCounters, isFalse);
      expect(plain.total, 30);
    });

    test('a counter is never "the canteen" a link opens', () {
      const shops = [_snacks, _canteen];
      expect(firstShopKeyOfCategory(shops, 'canteen'), 'mec-canteen');
      expect(walletKeyOf('mec-canteen-snacks', shops), 'mec-canteen');
    });
  });

  testWidgets('the storefront groups the canteen by counter', (tester) async {
    tester.view.physicalSize = const Size(1600, 2800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    String? openedWallet;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudentCanteenHome(
            store: _store(),
            cart: const {},
            onAdd: (_) {},
            onRemove: (_) {},
            onOpenCart: () {},
            onOpenWallet: (key) => openedWallet = key,
            onOpenProfile: () {},
            onOpenOrders: () {},
            onExitModule: () {},
            onPayLaundryCharge: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Counters are not storefronts of their own.
    expect(find.text('Campus Canteen'), findsOneWidget);
    expect(find.text('Campus Laundry'), findsOneWidget);
    for (final counter in [_meals, _drinks, _snacks]) {
      expect(
        find.byKey(ValueKey('counter-section-${counter.shopKey}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('counter-filter-${counter.shopKey}')),
        findsOneWidget,
      );
    }
    expect(find.text('Veg Meals'), findsOneWidget);
    expect(find.text('Samosa'), findsOneWidget);
    // Snacks can spend its own ₹100 plus the ₹50 canteen credit.
    expect(find.text('₹150 to spend here'), findsOneWidget);
    expect(find.text('₹50 to spend here'), findsNWidgets(2));
    // The pill shows the whole canteen wallet.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('shop-wallet-balance-pill')))
          .data,
      '₹150',
    );

    await tester.tap(
      find.byKey(const ValueKey('counter-filter-mec-canteen-snacks')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Samosa'), findsOneWidget);
    expect(find.text('Veg Meals'), findsNothing);
    expect(find.text('Lime Soda'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('counter-filter-mec-canteen-meals')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Veg Meals'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('shop-wallet-balance-pill')))
          .data,
      '₹50',
    );

    await tester.tap(find.byKey(const ValueKey('shop-wallet-balance-pill')));
    expect(openedWallet, 'mec-canteen');
  });

  testWidgets('a closed counter says so inside its canteen', (tester) async {
    tester.view.physicalSize = const Size(1600, 2800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const closedSnacks = CanteenShop(
      id: 'shop-snacks',
      shopKey: 'mec-canteen-snacks',
      name: 'Snacks',
      category: 'canteen',
      parentShopKey: 'mec-canteen',
      isOpen: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudentCanteenHome(
            store: _store(
              shops: const [_canteen, _meals, _drinks, closedSnacks],
            ),
            cart: const {},
            onAdd: (_) {},
            onRemove: (_) {},
            onOpenCart: () {},
            onOpenWallet: (_) {},
            onOpenProfile: () {},
            onOpenOrders: () {},
            onExitModule: () {},
            onPayLaundryCharge: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('Samosa'), findsNothing);
    expect(find.text('Veg Meals'), findsOneWidget);
  });

  testWidgets('the wallet shows its credit by scope and per counter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 2800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudentWalletSheet(
            store: _store(),
            shopKey: 'mec-canteen',
            onTopUp: (_) async => throw UnimplementedError(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('student-wallet-balance')))
          .data,
      '₹150',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('student-wallet-breakdown')))
          .data,
      'General ₹50 · Snacks only ₹100',
    );
    expect(find.text('Meals ₹50'), findsOneWidget);
    expect(find.text('Beverages ₹50'), findsOneWidget);
    expect(find.text('Snacks ₹150'), findsOneWidget);
  });

  testWidgets('the cart says which credit pays each counter', (tester) async {
    // The test font is far wider than the app's; the quantity stepper's
    // overflow is a test-font artefact, not what this test is about.
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      onError?.call(details);
    };
    addTearDown(() => FlutterError.onError = onError);
    tester.view.physicalSize = const Size(1600, 2800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CanteenCartScreen(
          menu: [_meal, _soda, _samosa],
          shops: _shops,
          cart: const {'samosa': 8, 'meal': 1},
          walletBalances: _balances,
          onAdd: (_) {},
          onRemove: (_) {},
          onPlaceOrder: (_) async => throw UnimplementedError(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // One wallet line for the canteen, one split line per counter.
    expect(find.text('Campus Canteen wallet: ₹150'), findsOneWidget);
    expect(find.textContaining('2 separate QR codes'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(
                const ValueKey('cart-wallet-split-mec-canteen-meals'),
              ),
              matching: find.byType(Text),
            ),
          )
          .data,
      'Meals · ₹45 canteen credit',
    );
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(
                const ValueKey('cart-wallet-split-mec-canteen-snacks'),
              ),
              matching: find.byType(Text),
            ),
          )
          .data,
      'Snacks · not enough credit here',
    );
  });

  testWidgets('the accounts desk limits a credit to one counter', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);
    final repository = _ScopedWalletRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AccountantWalletScreen(
          repository: repository,
          accountantName: 'Abhinaya',
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-student-wallets')));
    await tester.pumpAndSettle();

    // The person's canteen pill is the whole wallet; counters are not wallets.
    expect(
      find.byKey(const ValueKey('wallet-balance-student-1-mec-canteen-snacks')),
      findsNothing,
    );
    expect(find.text('₹150'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('credit-student-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('wallet-store-mec-canteen-snacks')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('wallet-store-mec-canteen')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wallet-scope-all')), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('wallet-scope-mec-canteen-snacks')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Only Snacks accepts it'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('wallet-amount')), '100');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('wallet-review-recharge')));
    await tester.pumpAndSettle();
    expect(find.text('Spendable Snacks only.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-wallet-recharge')));
    await tester.pumpAndSettle();

    expect(repository.credits.single, ('mec-canteen-snacks', 100.0));
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('wallet-recharge-new-balance')),
          )
          .data,
      '₹200',
    );

    // A whole-canteen credit lands in the canteen's general credit.
    await tester.tap(find.byKey(const ValueKey('wallet-recharge-done')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('credit-student-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wallet-store-mec-canteen')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('wallet-amount')), '50');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('wallet-review-recharge')));
    await tester.pumpAndSettle();
    expect(find.text('Spendable at every counter.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-wallet-recharge')));
    await tester.pumpAndSettle();
    expect(repository.credits.last, ('mec-canteen', 50.0));
  });

  testWidgets('the admin adds a counter under a canteen and sees it nested', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _CounterVendorRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: VendorManagementShell(
          session: const UserSession(
            email: 'admin@mec.local',
            displayName: 'MEC Admin',
            role: UserRole.admin,
            roleId: 'tenant_admin',
            roleIds: ['tenant_admin'],
          ),
          onExitModule: () {},
          repository: repository,
          permissions: const EffectivePermissions(grants: {'*'}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vendors'));
    await tester.pumpAndSettle();

    // Snacks is listed right under its canteen, labelled as its counter.
    expect(find.textContaining('Counter of Campus Canteen'), findsOneWidget);
    final canteenY = tester
        .getTopLeft(find.byKey(const ValueKey('vendor-shop-mec-canteen')))
        .dy;
    final snacksY = tester
        .getTopLeft(
          find.byKey(const ValueKey('vendor-shop-mec-canteen-snacks')),
        )
        .dy;
    final laundryY = tester
        .getTopLeft(find.byKey(const ValueKey('vendor-shop-mec-laundry')))
        .dy;
    expect(snacksY, greaterThan(canteenY));
    expect(snacksY, lessThan(laundryY));

    await tester.tap(find.byKey(const ValueKey('vendor-shop-mec-canteen')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('counter-row-mec-canteen-snacks')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('add-counter')));
    await tester.pumpAndSettle();
    expect(find.text('Add counter to Campus Canteen'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Counter name'),
      'Meals',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('shop-form-submit')));
    await tester.pumpAndSettle();

    final draft = repository.created.single;
    expect(draft.parentShopKey, 'mec-canteen');
    expect(draft.shopKey, 'mec-canteen-meals');
    expect(draft.category, 'canteen');
    expect(draft.sortOrder, 2);
    expect(find.text('Meals'), findsOneWidget);
  });
}

class _ScopedWalletRepository implements AccountantWalletRepository {
  final credits = <(String, double)>[];
  var _account = const WalletAccount(
    userId: 'student-1',
    name: 'Student One',
    email: 'student001@mec.local',
    studentNumber: 'MEC001',
    walletBalances: {'mec-canteen': 50, 'mec-canteen-snacks': 100},
  );

  static const _stores = [
    WalletStore(
      shopKey: 'mec-canteen',
      name: 'Campus Canteen',
      category: 'canteen',
    ),
    WalletStore(
      shopKey: 'mec-canteen-meals',
      name: 'Meals',
      category: 'canteen',
      parentShopKey: 'mec-canteen',
    ),
    WalletStore(
      shopKey: 'mec-canteen-snacks',
      name: 'Snacks',
      category: 'canteen',
      parentShopKey: 'mec-canteen',
    ),
  ];

  @override
  Future<WalletDirectoryPage> listWallets({
    String search = '',
    WalletAudience audience = WalletAudience.all,
    int? year,
    int offset = 0,
    int limit = 50,
  }) async => WalletDirectoryPage(
    accounts: [_account],
    total: 1,
    stores: _stores,
    counts: const WalletDirectoryCounts(all: 1, students: 1),
  );

  @override
  Future<AccountantWalletCredit> creditWallet({
    required String userId,
    required String shopKey,
    required double amount,
    required String idempotencyKey,
    String? reference,
  }) async {
    credits.add((shopKey, amount));
    final balance = _account.balanceFor(shopKey) + amount;
    _account = _account.withBalance(shopKey, balance);
    return AccountantWalletCredit(balance: balance, shopKey: shopKey);
  }

  @override
  Future<AccountantWalletCredit> debitWallet({
    required String userId,
    required String shopKey,
    required double amount,
    required String reason,
    required String idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<List<AccountantWalletTransaction>> listTransactions({
    int limit = 50,
  }) async => const [];

  @override
  Future<WalletTopUpSettings> getWalletTopUpSettings() async =>
      WalletTopUpSettings.defaults;

  @override
  Future<WalletTopUpSettings> updateWalletTopUpSettings({
    required double minimumAmount,
    required double maximumAmount,
  }) => throw UnimplementedError();
}

VendorShop _vendor(
  String key,
  String name,
  String category, {
  String? parent,
}) => VendorShop(
  id: 'id-$key',
  shopKey: key,
  name: name,
  category: category,
  description: '',
  isActive: true,
  isOpen: true,
  parentShopKey: parent,
);

class _CounterVendorRepository implements VendorRepository, ShopAdministration {
  final created = <VendorShopDraft>[];
  List<VendorShop> shops = [
    _vendor('mec-canteen', 'Campus Canteen', 'canteen'),
    _vendor('mec-laundry', 'Campus Laundry', 'laundry'),
    // Listed last by the server, shown under its canteen.
    _vendor('mec-canteen-snacks', 'Snacks', 'canteen', parent: 'mec-canteen'),
  ];

  @override
  Future<List<VendorShop>> listVendors() async => shops;

  @override
  Future<VendorShop> createVendor(VendorShopDraft draft) async {
    created.add(draft);
    final shop = _vendor(
      draft.shopKey,
      draft.name,
      draft.category,
      parent: draft.parentShopKey,
    );
    shops = [...shops, shop];
    return shop;
  }

  @override
  Future<List<VendorShop>> reorderVendors(List<String> shopKeys) async => shops;

  @override
  Future<List<ShopStaffCandidate>> listShopStaffCandidates() async => const [];

  @override
  Future<SalesDashboardData> getSalesDashboard({
    SalesPeriod period = SalesPeriod.today,
  }) async => SalesDashboardData(period: period);

  @override
  Future<SalesOrderPage> listSalesOrders({
    SalesPeriod period = SalesPeriod.all,
    String? shopKey,
    OrderStatusFilter status = OrderStatusFilter.all,
    int limit = 100,
  }) async => const SalesOrderPage();

  @override
  Future<VendorShop> updateVendor(String shopId, VendorShopDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> toggleVendorStatus(VendorShop shop, bool active) =>
      throw UnimplementedError();
}
