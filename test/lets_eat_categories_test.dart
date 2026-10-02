import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/admin_portal/data/admin_student_repository.dart';
import 'package:supercampus_mobile/src/features/admin_portal/presentation/shop_counter_sheet.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/student_canteen_home.dart';
import 'package:supercampus_mobile/src/features/vendor_management/data/vendor_models.dart';
import 'package:supercampus_mobile/src/features/vendor_management/data/vendor_repository.dart';
import 'package:supercampus_mobile/src/features/vendor_management/presentation/vendor_management_shell.dart';

// The user's request: the canteen is called "Let's eat!" and is split into
// categories (All · Bites · Mess). "Let's eat!" has no owner or captain of
// its own; owners and captains belong only to the categories.
const _letsEat = "Let's eat!";

VendorShop _vendor(
  String key,
  String name,
  String category, {
  String? parent,
  bool hasCategories = false,
  int uncategorized = 0,
  List<ShopStaffAssignment> operators = const [],
}) => VendorShop(
  id: 'id-$key',
  shopKey: key,
  name: name,
  category: category,
  description: '',
  isActive: true,
  isOpen: true,
  parentShopKey: parent,
  hasCategories: hasCategories,
  uncategorizedItemCount: uncategorized,
  operators: operators,
);

class _CategoryVendorRepository
    implements
        VendorRepository,
        ShopAdministration,
        CategoryMenuAdministration {
  _CategoryVendorRepository({this.retireOnCreate = 0});

  final int retireOnCreate;
  final created = <VendorShopDraft>[];
  final updated = <VendorShopDraft>[];
  final moves = <(String, List<String>, String)>[];
  var items = <ShopMenuItemSummary>[
    const ShopMenuItemSummary(
      id: 'puffs',
      name: 'Veg Puffs',
      category: 'Snacks',
      price: 20,
    ),
    const ShopMenuItemSummary(
      id: 'thali',
      name: 'Mini Thali',
      category: 'Meals',
      price: 35,
    ),
  ];

  List<VendorShop> get shops => [
    _vendor(
      'mec-canteen',
      _letsEat,
      'canteen',
      hasCategories: true,
      uncategorized: items.length,
      // A stale server row must still never be shown as the canteen's staff.
      operators: const [
        ShopStaffAssignment(userId: 'u-1', role: 'owner', name: 'Old Owner'),
      ],
    ),
    _vendor('mec-canteen-bites', 'Bites', 'canteen', parent: 'mec-canteen'),
    _vendor('mec-canteen-mess', 'Mess', 'canteen', parent: 'mec-canteen'),
    _vendor('mec-laundry', 'Campus Laundry', 'laundry'),
    for (final draft in created)
      _vendor(
        draft.shopKey,
        draft.name,
        draft.category,
        parent: draft.parentShopKey,
      ),
  ];

  @override
  Future<List<VendorShop>> listVendors() async => shops;

  @override
  Future<VendorShop> createVendor(VendorShopDraft draft) async {
    created.add(draft);
    return VendorShop(
      id: 'id-${draft.shopKey}',
      shopKey: draft.shopKey,
      name: draft.name,
      category: draft.category,
      description: '',
      isActive: true,
      isOpen: true,
      parentShopKey: draft.parentShopKey,
      parentStaffRemoved: [
        for (var i = 0; i < retireOnCreate; i++)
          ShopStaffAssignment(userId: 'old-$i', role: 'captain'),
      ],
    );
  }

  @override
  Future<VendorShop> updateVendor(String shopId, VendorShopDraft draft) async {
    updated.add(draft);
    return shops.firstWhere((shop) => shop.id == shopId);
  }

  @override
  Future<List<ShopMenuItemSummary>> listShopItems(String shopKey) async =>
      items;

  @override
  Future<int> moveItemsToCategory({
    required String parentShopKey,
    required List<String> itemIds,
    required String targetShopKey,
  }) async {
    moves.add((parentShopKey, itemIds, targetShopKey));
    items = [
      for (final item in items)
        if (!itemIds.contains(item.id)) item,
    ];
    return items.length;
  }

  @override
  Future<List<VendorShop>> reorderVendors(List<String> shopKeys) async => shops;

  @override
  Future<List<ShopStaffCandidate>> listShopStaffCandidates() async => const [
    ShopStaffCandidate(
      userId: 'u-9',
      name: 'Bites Owner',
      email: 'bites@mec.local',
      suggestedRole: 'owner',
    ),
  ];

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
  Future<void> toggleVendorStatus(VendorShop shop, bool active) async {}
}

Future<void> _openVendors(
  WidgetTester tester,
  _CategoryVendorRepository repository,
) async {
  tester.view.physicalSize = const Size(390, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
}

const _shopLetsEat = CanteenShop(
  id: 'shop-canteen',
  shopKey: 'mec-canteen',
  name: _letsEat,
  category: 'canteen',
);
const _shopBites = CanteenShop(
  id: 'shop-bites',
  shopKey: 'mec-canteen-bites',
  name: 'Bites',
  category: 'canteen',
  parentShopKey: 'mec-canteen',
);
const _shopMess = CanteenShop(
  id: 'shop-mess',
  shopKey: 'mec-canteen-mess',
  name: 'Mess',
  category: 'canteen',
  parentShopKey: 'mec-canteen',
);

CanteenMenuItem _item(String id, String name, String shopKey) =>
    CanteenMenuItem(
      id: id,
      name: name,
      description: '',
      category: 'food',
      price: 20,
      isVegetarian: true,
      shopKey: shopKey,
    );

void main() {
  testWidgets("the register calls them categories of Let's eat!", (
    tester,
  ) async {
    final repository = _CategoryVendorRepository();
    await _openVendors(tester, repository);

    expect(find.textContaining('Category of $_letsEat'), findsNWidgets(2));
    // The canteen's row counts its categories instead of listing staff.
    expect(find.textContaining('2 categories'), findsOneWidget);
    expect(find.textContaining('Counter of'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('vendor-shop-mec-canteen')));
    await tester.pumpAndSettle();
    expect(find.text(_letsEat), findsWidgets);
    expect(find.text('Categories'), findsOneWidget);
    expect(find.byKey(const ValueKey('staff-per-category')), findsOneWidget);
    expect(
      find.textContaining('Staff are assigned per category'),
      findsOneWidget,
    );
    // No owner or captain of its own, even if the server still had one.
    expect(find.text('Old Owner'), findsNothing);
    expect(find.text('Owner'), findsNothing);
    expect(
      find.byKey(const ValueKey('counter-row-mec-canteen-bites')),
      findsOneWidget,
    );
    expect(find.text('Add category'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('uncategorized-items-banner')),
      findsOneWidget,
    );
    expect(find.textContaining("2 items aren't in a category yet"), findsOne);
  });

  testWidgets('the admin moves the canteen items into a category', (
    tester,
  ) async {
    final repository = _CategoryVendorRepository();
    await _openVendors(tester, repository);
    await tester.tap(find.byKey(const ValueKey('vendor-shop-mec-canteen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move-items')));
    await tester.pumpAndSettle();

    expect(find.text('Move items to categories'), findsOneWidget);
    expect(find.text('Veg Puffs'), findsOneWidget);
    expect(find.text('Mini Thali'), findsOneWidget);
    // Nothing chosen yet: the button asks for a choice.
    expect(find.text('Choose items to move'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('move-item-thali')));
    await tester.tap(
      find.byKey(const ValueKey('move-target-mec-canteen-mess')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Move 1 item to Mess'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('move-items-submit')));
    await tester.pumpAndSettle();

    final (parent, ids, target) = repository.moves.single;
    expect(
      [parent, ...ids, target],
      ['mec-canteen', 'thali', 'mec-canteen-mess'],
    );
    expect(find.text('Moved 1 item to Mess.'), findsOneWidget);
    expect(find.text('Mini Thali'), findsNothing);

    // Select all → Bites moves what is left.
    await tester.tap(find.byKey(const ValueKey('move-items-select-all')));
    await tester.tap(
      find.byKey(const ValueKey('move-target-mec-canteen-bites')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move-items-submit')));
    await tester.pumpAndSettle();
    final (_, lastIds, lastTarget) = repository.moves.last;
    expect([...lastIds, lastTarget], ['puffs', 'mec-canteen-bites']);
    expect(find.byKey(const ValueKey('move-items-empty')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('move-items-done')));
    await tester.pumpAndSettle();
    // The register refreshed: nothing is left outside a category.
    await tester.tap(find.byKey(const ValueKey('vendor-shop-mec-canteen')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('uncategorized-items-banner')),
      findsNothing,
    );
  });

  testWidgets(
    "renaming Let's eat! keeps staff out of it and its punctuation intact",
    (tester) async {
      final repository = _CategoryVendorRepository();
      await _openVendors(tester, repository);
      await tester.tap(find.byKey(const ValueKey('vendor-shop-mec-canteen')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit details'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('form-staff-per-category')),
        findsOneWidget,
      );
      expect(find.text('Counter staff'), findsNothing);
      expect(find.text('Add staff'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Shop name'),
        "Let's eat! ",
      );
      await tester.tap(find.byKey(const ValueKey('shop-form-submit')));
      await tester.pumpAndSettle();
      final draft = repository.updated.single;
      expect(draft.name, _letsEat);
      expect(draft.shopKey, 'mec-canteen');
      expect(draft.operators, isNull);
      expect(draft.toJson().containsKey('operators'), isFalse);
    },
  );

  testWidgets('a new category gets its own staff; the admin is told who left '
      'the canteen', (tester) async {
    final repository = _CategoryVendorRepository(retireOnCreate: 3);
    await _openVendors(tester, repository);
    await tester.tap(find.byKey(const ValueKey('vendor-shop-mec-canteen')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-counter')));
    await tester.pumpAndSettle();

    expect(find.text('Add category to $_letsEat'), findsOneWidget);
    // A category does have owners and captains.
    expect(find.text('Counter staff'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Category name'),
      'Juice Bar',
    );
    await tester.pump();
    await tester.tap(find.text('Add staff'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bites Owner'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shop-form-submit')));
    await tester.pump();

    final draft = repository.created.single;
    expect(draft.parentShopKey, 'mec-canteen');
    expect(draft.shopKey, 'mec-canteen-juice-bar');
    expect(draft.operators?.single.role, 'owner');
    expect(
      find.textContaining(
        "3 staff no longer work $_letsEat itself — assign them to its "
        'categories.',
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
  });

  testWidgets("students see Let's eat! as All · Bites · Mess", (tester) async {
    tester.view.physicalSize = const Size(1600, 2800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final store = CanteenStore(
      user: const CanteenUser(
        id: 'student-1',
        name: 'Student One',
        email: 'student001@mec.local',
        rollNumber: 'MEC001',
        department: 'CSE',
      ),
      walletBalances: const {'mec-canteen': 50, 'mec-canteen-bites': 30},
      menu: [
        _item('puffs', 'Veg Puffs', 'mec-canteen-bites'),
        _item('thali', 'Mini Thali', 'mec-canteen-mess'),
        // Still on the canteen itself: no one would make it.
        _item('stray', 'Unsorted Vada', 'mec-canteen'),
      ],
      orders: const [],
      walletTransactions: const [],
      shops: const [_shopLetsEat, _shopBites, _shopMess],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: StudentCanteenHome(
            store: store,
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

    expect(find.text(_letsEat), findsOneWidget);
    for (final key in ['all', 'mec-canteen-bites', 'mec-canteen-mess']) {
      expect(find.byKey(ValueKey('counter-filter-$key')), findsOneWidget);
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('counter-filter-all')),
        matching: find.text('All'),
      ),
      findsOneWidget,
    );
    expect(find.text('Veg Puffs'), findsOneWidget);
    expect(find.text('Mini Thali'), findsOneWidget);
    expect(find.text('Unsorted Vada'), findsNothing);
    // General ₹50 + Bites-only ₹30.
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('shop-wallet-balance-pill')))
          .data,
      '₹80',
    );

    await tester.tap(
      find.byKey(const ValueKey('counter-filter-mec-canteen-mess')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mini Thali'), findsOneWidget);
    expect(find.text('Veg Puffs'), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('shop-wallet-balance-pill')))
          .data,
      '₹50',
    );
  });

  testWidgets("the user editor never offers Let's eat! itself", (tester) async {
    final repository = AdminStudentRepository(
      baseUrl: 'https://api.supercampus.ai',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'data': {
              'userId': 'user-9',
              'shops': [
                {
                  'shopKey': 'mec-canteen',
                  'name': _letsEat,
                  'category': 'canteen',
                  'hasCategories': true,
                  // Stale: still never offered or re-sent.
                  'assignmentRole': 'owner',
                },
                {
                  'shopKey': 'mec-canteen-bites',
                  'name': 'Bites',
                  'category': 'canteen',
                  'parentShopKey': 'mec-canteen',
                  'assignmentRole': 'captain',
                },
                {
                  'shopKey': 'mec-laundry',
                  'name': 'Campus Laundry',
                  'category': 'laundry',
                },
              ],
            },
          }),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ShopCounterSheet(
            repository: repository,
            userId: 'user-9',
            userName: 'Old Owner',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(_letsEat), findsNothing);
    expect(find.text('Bites'), findsOneWidget);
    expect(find.text('Category of $_letsEat'), findsOneWidget);
    expect(find.text('Campus Laundry'), findsOneWidget);
  });

  test('the move tool talks to the canteen menu endpoints', () async {
    final requests = <http.Request>[];
    final repository = BackendVendorRepository(
      baseUrl: 'https://api.supercampus.ai',
      accessToken: 'token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'data': {
                'shopKey': 'mec-canteen',
                'hasCategories': true,
                'items': [
                  {
                    'id': 'puffs',
                    'name': 'Veg Puffs',
                    'category': 'Snacks',
                    'price': 20,
                    'isAvailable': true,
                  },
                ],
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'data': {'moved': 1, 'remaining': 0},
          }),
          200,
        );
      }),
    );
    final items = await repository.listShopItems('mec-canteen');
    expect(items.single.name, 'Veg Puffs');
    final remaining = await repository.moveItemsToCategory(
      parentShopKey: 'mec-canteen',
      itemIds: ['puffs'],
      targetShopKey: 'mec-canteen-bites',
    );
    expect(remaining, 0);
    expect(
      requests.first.url.path,
      '/api/v1/operations/canteen/shops/mec-canteen/menu',
    );
    expect(
      requests.last.url.path,
      '/api/v1/operations/canteen/shops/mec-canteen/menu/move',
    );
    expect(jsonDecode(requests.last.body), {
      'itemIds': ['puffs'],
      'targetShopKey': 'mec-canteen-bites',
    });
  });

  test('a split canteen is known from the server flag or its categories', () {
    final parent = _vendor('mec-canteen', _letsEat, 'canteen');
    final bites = _vendor(
      'mec-canteen-bites',
      'Bites',
      'canteen',
      parent: 'mec-canteen',
    );
    expect(isSplitIntoCategories(parent, [parent]), isFalse);
    expect(isSplitIntoCategories(parent, [parent, bites]), isTrue);
    expect(isSplitIntoCategories(bites, [parent, bites]), isFalse);
    final flagged = VendorShop.fromJson({
      'id': 'x',
      'shopKey': 'mec-canteen',
      'name': _letsEat,
      'hasCategories': true,
      'uncategorizedItemCount': 4,
      'parentStaffRemoved': [
        {'userId': 'u-1', 'assignmentRole': 'owner', 'name': 'Old Owner'},
      ],
    });
    expect(flagged.name, _letsEat);
    expect(isSplitIntoCategories(flagged, [flagged]), isTrue);
    expect(flagged.uncategorizedItemCount, 4);
    expect(flagged.parentStaffRemoved.single.isOwner, isTrue);
  });
}
