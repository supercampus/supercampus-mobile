import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_cart_screen.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_owner_home.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_shell.dart';

// A campus with two canteens: the original one and a newer one with its own
// owner and captains. The newer canteen is listed first (the administrator
// reordered the shops), which must not hand it the original's legacy data.
final _newCanteen = CanteenShop(
  id: 'shop-2',
  shopKey: 'qa-canteen-2',
  name: 'Second Canteen',
  category: 'canteen',
  createdAt: DateTime.utc(2026, 10, 1),
);
final _oldCanteen = CanteenShop(
  id: 'shop-1',
  shopKey: 'mec-canteen',
  name: 'Campus Canteen',
  category: 'canteen',
  createdAt: DateTime.utc(2026, 9, 27),
);
final _shops = [_newCanteen, _oldCanteen];

CanteenMenuItem _item(String id, String name, String shopKey) =>
    CanteenMenuItem(
      id: id,
      name: name,
      description: '',
      category: 'meals',
      price: 40,
      isVegetarian: true,
      shopKey: shopKey,
    );

final _dosa = _item('dosa', 'Masala Dosa', 'qa-canteen-2');
final _coffee = _item('coffee', 'Filter Coffee', 'mec-canteen');
// Saved before shops existed: the original canteen's.
final _vada = _item('vada', 'Medu Vada', 'classic');

CanteenOrder _order(
  String id,
  String customer,
  CanteenMenuItem item, {
  String? shopKey,
  String? customerUserId,
}) => CanteenOrder(
  id: id,
  lines: [CartLine(item: item, quantity: 1)],
  total: item.price,
  status: CanteenOrderStatus.pending,
  fulfilmentMode: FulfilmentMode.pickup,
  createdAt: DateTime(2026, 10, 1, 12),
  customerName: customer,
  customerUserId: customerUserId ?? 'student-$id',
  shopKey: shopKey,
);

CanteenStore _store({
  List<String> assigned = const [],
  List<ShopAssignment> roles = const [],
  bool canManage = true,
  bool canManageMenu = true,
  bool configuresShops = false,
  List<CanteenOrder>? orders,
}) => CanteenStore(
  user: const CanteenUser(
    id: 'me',
    name: 'Shashi',
    email: 'shashi@mec.local',
    rollNumber: 'Not assigned',
    department: 'Not assigned',
  ),
  walletBalances: const {'mec-canteen': 100, 'qa-canteen-2': 200},
  menu: [_dosa, _coffee, _vada],
  orders:
      orders ??
      [
        _order('o-new', 'Asha New', _dosa, shopKey: 'qa-canteen-2'),
        _order('o-old', 'Ravi Old', _coffee, shopKey: 'mec-canteen'),
        // An older payload with no shop key: the lines say `classic`.
        _order('o-legacy', 'Lakshmi Legacy', _vada),
      ],
  walletTransactions: const [],
  shops: _shops,
  assignedShopKeys: assigned,
  assignedShops: roles,
  canManage: canManage,
  canManageMenu: canManageMenu,
  canConfigureShops: configuresShops,
  staffState: const CanteenStaffState(
    mode: CanteenStaffMode.work,
    shopOpen: true,
  ),
);

class _Repository implements CanteenRepository {
  _Repository(this.store);

  final CanteenStore store;

  @override
  Future<CanteenStore> loadStore() async => store;

  @override
  Future<CanteenStaffState> updateStaffState({
    required CanteenStaffMode mode,
    bool? shopOpen,
  }) async => CanteenStaffState(mode: mode, shopOpen: shopOpen);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required UserSession session,
  required CanteenStore store,
}) async {
  tester.view.physicalSize = const Size(1600, 2800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CanteenShell(
          session: session,
          repository: _Repository(store),
          onExitModule: () {},
          onSignOut: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// shashi@mec.local: a captain of the original canteen whose account still
// carries the captain role, and who now owns the new canteen.
const _shashi = UserSession(
  email: 'shashi@mec.local',
  displayName: 'Shashi',
  role: UserRole.staff,
  roleId: 'canteen_captain',
  roleIds: ['canteen_captain', 'owner'],
  activePortalFamily: PortalFamily.staff,
);

const _newCaptain = UserSession(
  email: 'qa.canteen2.captain@mec.local',
  displayName: 'New Captain',
  role: UserRole.staff,
  roleId: 'captain',
  roleIds: ['captain'],
  activePortalFamily: PortalFamily.staff,
);

void main() {
  group('shop keys with two canteens', () {
    test('a shop key always resolves to its own canteen', () {
      expect(resolveShopKey('qa-canteen-2', _shops), 'qa-canteen-2');
      expect(resolveShopKey('mec-canteen', _shops), 'mec-canteen');
    });

    test('legacy keys belong to the oldest canteen, not the first listed', () {
      expect(resolveShopKey('classic', _shops), 'mec-canteen');
      expect(resolveShopKey('bites', _shops), 'mec-canteen');
      expect(resolveShopKey(null, _shops), 'mec-canteen');
    });

    test('a retired canteen keeps its own key; legacy keys skip it', () {
      final retired = CanteenShop(
        id: 'shop-0',
        shopKey: 'old-mess',
        name: 'Old Mess',
        category: 'canteen',
        isActive: false,
        createdAt: DateTime.utc(2025, 1, 1),
      );
      final shops = [..._shops, retired];
      expect(resolveShopKey('old-mess', shops), 'old-mess');
      expect(resolveShopKey('classic', shops), 'mec-canteen');
    });

    test('without creation times the listed order still decides', () {
      const a = CanteenShop(
        id: 'a',
        shopKey: 'a-canteen',
        name: 'A',
        category: 'canteen',
      );
      const b = CanteenShop(
        id: 'b',
        shopKey: 'b-canteen',
        name: 'B',
        category: 'canteen',
      );
      expect(resolveShopKey('classic', const [b, a]), 'b-canteen');
    });

    test("each canteen's wallet lists only its own orders", () {
      // The signed-in person's own purchases from both canteens.
      final store = _store(
        orders: [
          _order(
            'o-new',
            'Me',
            _dosa,
            shopKey: 'qa-canteen-2',
            customerUserId: 'me',
          ),
          _order(
            'o-old',
            'Me',
            _coffee,
            shopKey: 'mec-canteen',
            customerUserId: 'me',
          ),
          _order('o-legacy', 'Me', _vada, customerUserId: 'me'),
        ],
      );
      expect(store.walletOrdersFor('qa-canteen-2').map((o) => o.id), ['o-new']);
      expect(store.walletOrdersFor('mec-canteen').map((o) => o.id), [
        'o-old',
        'o-legacy',
      ]);
    });

    test(
      'the default wallet is the first listed canteen, never a fixed key',
      () {
        expect(_store().defaultWalletShopKey, 'qa-canteen-2');
      },
    );
  });

  group('counter scope', () {
    final dual = _store(
      assigned: const ['qa-canteen-2', 'mec-canteen'],
      roles: const [
        ShopAssignment(shopKey: 'qa-canteen-2', role: 'owner'),
        ShopAssignment(shopKey: 'mec-canteen', role: 'captain'),
      ],
    );

    test('owner grants open only the menu of the canteen they own', () {
      expect(dual.canEditMenuOf('qa-canteen-2'), isTrue);
      expect(dual.canEditMenuOf('mec-canteen'), isFalse);
      expect(dual.hasOwnerWork, isTrue);
    });

    test('a captain of one canteen who owns nothing runs the queue', () {
      final captain = _store(
        assigned: const ['mec-canteen'],
        roles: const [ShopAssignment(shopKey: 'mec-canteen', role: 'captain')],
      );
      expect(captain.hasOwnerWork, isFalse);
      expect(captain.canEditMenuOf('mec-canteen'), isFalse);
    });

    test('older servers without roles keep the grant-based behaviour', () {
      final owner = _store(assigned: const ['mec-canteen']);
      expect(owner.assignmentRoleAt('mec-canteen'), 'owner');
      expect(owner.canEditMenuOf('mec-canteen'), isTrue);
      final captain = _store(
        assigned: const ['mec-canteen'],
        canManageMenu: false,
      );
      expect(captain.assignmentRoleAt('mec-canteen'), 'captain');
      expect(captain.hasOwnerWork, isFalse);
    });

    test('a captained canteen shows its queue and settled orders only', () {
      expect(ownerSectionsFor(dual, _oldCanteen), [
        OwnerSection.orders,
        OwnerSection.settled,
      ]);
      expect(ownerSectionsFor(dual, _newCanteen), OwnerSection.values);
    });
  });

  group('workspaces', () {
    testWidgets(
      'a captain who now owns a canteen lands on that canteen as its owner',
      (tester) async {
        await _pumpShell(
          tester,
          session: _shashi,
          store: _store(
            assigned: const ['qa-canteen-2', 'mec-canteen'],
            roles: const [
              ShopAssignment(shopKey: 'qa-canteen-2', role: 'owner'),
              ShopAssignment(shopKey: 'mec-canteen', role: 'captain'),
            ],
          ),
        );

        expect(find.text('Owner workspace'), findsOneWidget);
        expect(find.text('Canteen captain'), findsNothing);
        // The new canteen's queue, not the original's.
        expect(find.text('Asha New'), findsOneWidget);
        expect(find.text('Ravi Old'), findsNothing);
        expect(find.text('Lakshmi Legacy'), findsNothing);
      },
    );

    testWidgets(
      "the original canteen's owner never sees the new one's orders",
      (tester) async {
        await _pumpShell(
          tester,
          session: const UserSession(
            email: 'canteen.owner@mec.local',
            displayName: 'Canteen Owner',
            role: UserRole.staff,
            roleId: 'owner',
            roleIds: ['owner'],
            activePortalFamily: PortalFamily.staff,
          ),
          store: _store(
            assigned: const ['mec-canteen'],
            roles: const [
              ShopAssignment(shopKey: 'mec-canteen', role: 'owner'),
            ],
          ),
        );

        expect(find.text('Owner workspace'), findsOneWidget);
        expect(find.text('Ravi Old'), findsOneWidget);
        expect(find.text('Lakshmi Legacy'), findsOneWidget);
        expect(find.text('Asha New'), findsNothing);
      },
    );

    testWidgets("the new canteen's captain gets the captain's queue", (
      tester,
    ) async {
      await _pumpShell(
        tester,
        session: _newCaptain,
        store: _store(
          assigned: const ['qa-canteen-2'],
          roles: const [
            ShopAssignment(shopKey: 'qa-canteen-2', role: 'captain'),
          ],
          canManageMenu: false,
          // The server sends a captain only their own counter's queue.
          orders: [_order('o-new', 'Asha New', _dosa, shopKey: 'qa-canteen-2')],
        ),
      );

      expect(find.text('Canteen captain'), findsOneWidget);
      expect(find.text('Owner workspace'), findsNothing);
    });
  });

  testWidgets('a cart across both canteens is two orders, named by shop', (
    tester,
  ) async {
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
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: CanteenCartScreen(
          menu: [_dosa, _coffee],
          shops: _shops,
          cart: const {'dosa': 1, 'coffee': 2},
          walletBalances: const {'mec-canteen': 100, 'qa-canteen-2': 200},
          onAdd: (_) {},
          onRemove: (_) {},
          onPlaceOrder: (_) async => throw UnimplementedError(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2 separate QR codes'), findsOneWidget);
    expect(find.text('Second Canteen'), findsOneWidget);
    expect(find.text('Campus Canteen'), findsOneWidget);
    expect(find.textContaining('Second Canteen wallet'), findsOneWidget);
    expect(find.textContaining('Campus Canteen wallet'), findsOneWidget);
  });
}
