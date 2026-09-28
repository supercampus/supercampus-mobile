import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_owner_home.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_shell.dart';

const _canteen = CanteenShop(
  id: 'mec-canteen',
  shopKey: 'mec-canteen',
  name: 'Campus Canteen',
  category: 'canteen',
);
const _stationery = CanteenShop(
  id: 'mec-stationery',
  shopKey: 'mec-stationery',
  name: 'Stationery Store',
  category: 'stationery',
);
const _laundry = CanteenShop(
  id: 'mec-laundry',
  shopKey: 'mec-laundry',
  name: 'Campus Laundry',
  category: 'laundry',
);

CanteenStore _store({
  required bool configuresShops,
  List<String> assigned = const [],
  List<CanteenOrder> orders = const [],
  CanteenStaffMode mode = CanteenStaffMode.work,
}) => CanteenStore(
  user: const CanteenUser(
    id: 'me',
    name: 'Signed In Person',
    email: 'person@mec.local',
    rollNumber: 'Not assigned',
    department: 'Not assigned',
  ),
  walletBalances: const {'mec-canteen': 120, 'mec-stationery': 40},
  menu: const [
    CanteenMenuItem(
      id: 'dosa',
      name: 'Masala Dosa',
      description: '',
      category: 'meals',
      price: 50,
      isVegetarian: true,
      shopKey: 'mec-canteen',
    ),
    CanteenMenuItem(
      id: 'pen',
      name: 'Blue Ball Pen',
      description: '',
      category: 'Writing',
      price: 10,
      isVegetarian: true,
      store: MenuStore.stationery,
      shopKey: 'mec-stationery',
    ),
  ],
  orders: orders,
  walletTransactions: const [],
  shops: const [_canteen, _laundry, _stationery],
  assignedShopKeys: assigned,
  canManage: true,
  canConfigureShops: configuresShops,
  staffState: CanteenStaffState(mode: mode, shopOpen: true),
);

class _Repository implements CanteenRepository {
  _Repository(this.store);

  final CanteenStore store;
  final modes = <CanteenStaffMode>[];

  @override
  Future<CanteenStore> loadStore() async => store;

  @override
  Future<CanteenStaffState> updateStaffState({
    required CanteenStaffMode mode,
    bool? shopOpen,
  }) async {
    modes.add(mode);
    return CanteenStaffState(mode: mode, shopOpen: shopOpen);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required UserSession session,
  required CanteenRepository repository,
  String? initialAction,
  VoidCallback? onExitModule,
}) async {
  // Wide enough that all three store pills are laid out at once (the test
  // font is much wider than the app's).
  tester.view.physicalSize = const Size(2400, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CanteenShell(
          session: session,
          repository: repository,
          initialAction: initialAction,
          onExitModule: onExitModule ?? () {},
          onSignOut: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _admin = UserSession(
  email: 'admin@mec.local',
  displayName: 'Campus Admin',
  role: UserRole.admin,
  roleId: 'tenant_admin',
  activePortalFamily: PortalFamily.admin,
);

const _canteenOwner = UserSession(
  email: 'canteen.owner@mec.local',
  displayName: 'Canteen Owner',
  role: UserRole.staff,
  roleId: 'owner',
  roleIds: ['owner'],
  activePortalFamily: PortalFamily.staff,
);

const _accountant = UserSession(
  email: 'accounts@mec.local',
  displayName: 'Campus Accountant',
  role: UserRole.staff,
  roleId: 'accountant',
  roleIds: ['accountant'],
  activePortalFamily: PortalFamily.staff,
);

Finder _sectionTab(String label) => find.descendant(
  of: find.byType(SegmentedButton<OwnerSection>),
  matching: find.text(label),
);

void main() {
  group('A. an admin overseeing the shops', () {
    test('sees the menu and figures for food, figures only elsewhere', () {
      final store = _store(configuresShops: true);
      expect(ownerSectionsFor(store, _canteen), [
        OwnerSection.menu,
        OwnerSection.sales,
      ]);
      expect(ownerSectionsFor(store, _laundry), [OwnerSection.sales]);
      expect(ownerSectionsFor(store, _stationery), [OwnerSection.sales]);
    });

    test('the counter of an assigned shop keeps orders, menu and figures', () {
      expect(
        ownerSectionsFor(
          _store(configuresShops: false, assigned: ['mec-laundry']),
          _laundry,
        ),
        OwnerSection.values,
      );
      // Even with the configuration grant, your own counter is a counter.
      expect(
        ownerSectionsFor(
          _store(configuresShops: true, assigned: ['mec-canteen']),
          _canteen,
        ),
        OwnerSection.values,
      );
    });

    testWidgets('store tabs show only the sections that shop needs', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        session: _admin,
        repository: _Repository(_store(configuresShops: true)),
        initialAction: 'dashboard',
      );

      expect(find.text('Shop operations'), findsOneWidget);
      expect(find.text('Campus shops'), findsOneWidget);

      // Campus Canteen: Menu and Sales & Profit, no Orders.
      expect(_sectionTab('Menu'), findsOneWidget);
      expect(_sectionTab('Sales & Profit'), findsOneWidget);
      expect(_sectionTab('Orders'), findsNothing);

      // Campus Laundry: Sales & Profit only, so no one-item tab bar.
      await tester.tap(find.text('Campus Laundry'));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<OwnerSection>), findsNothing);
      expect(find.text('Sales & Profit Analytics'), findsOneWidget);

      // Stationery Store: the same.
      await tester.tap(find.text('Stationery Store'));
      await tester.pumpAndSettle();
      expect(find.byType(SegmentedButton<OwnerSection>), findsNothing);
      expect(find.text('Sales & Profit Analytics'), findsOneWidget);
    });

    testWidgets('the avatar shows the signed-in admin, not a student card', (
      tester,
    ) async {
      await _pumpShell(
        tester,
        session: _admin,
        repository: _Repository(_store(configuresShops: true)),
        initialAction: 'dashboard',
      );

      await tester.tap(find.byType(CircleAvatar).last);
      await tester.pumpAndSettle();

      expect(find.text('Campus Admin'), findsOneWidget);
      expect(find.text('admin@mec.local'), findsOneWidget);
      expect(find.text('Profile & settings'), findsNothing);
      expect(find.text('MEC Student'), findsNothing);
      expect(find.text('Roll number'), findsNothing);
      expect(find.text('Work'), findsOneWidget);
      expect(find.text('Shop'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });
  });

  group('D. Work / Shop', () {
    testWidgets('a shop owner switches to Shop and can buy from all three '
        'stores', (tester) async {
      final repository = _Repository(
        _store(
          configuresShops: false,
          assigned: ['mec-canteen'],
          orders: [
            CanteenOrder(
              id: 'queue-order',
              customerUserId: 'a-student',
              customerName: 'A Student',
              total: 50,
              status: CanteenOrderStatus.pending,
              fulfilmentMode: FulfilmentMode.pickup,
              createdAt: DateTime(2026, 9, 28, 9),
              lines: const [],
            ),
          ],
        ),
      );
      await _pumpShell(tester, session: _canteenOwner, repository: repository);

      // Work: the owner workspace with the counter's queue.
      expect(find.text('Owner workspace'), findsOneWidget);
      // Work / Shop lives in the profile.
      await tester.tap(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byType(CircleAvatar),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shop'));
      await tester.pumpAndSettle();

      expect(repository.modes, [CanteenStaffMode.eat]);
      expect(find.text('Owner workspace'), findsNothing);
      // Every campus store, as a customer.
      expect(find.text('Campus Canteen'), findsOneWidget);
      expect(find.text('Stationery Store'), findsOneWidget);
      expect(find.text('Campus Laundry'), findsOneWidget);
      expect(find.text('Masala Dosa'), findsOneWidget);

      await tester.ensureVisible(find.text('Stationery Store'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stationery Store'));
      await tester.pumpAndSettle();
      expect(find.text('Blue Ball Pen'), findsOneWidget);

      // And straight back to the counter.
      await tester.tap(find.byTooltip('Switch to Work'));
      await tester.pumpAndSettle();
      expect(find.text('Owner workspace'), findsOneWidget);
      expect(repository.modes, [CanteenStaffMode.eat, CanteenStaffMode.work]);
    });

    testWidgets('an accountant shops, and Work returns to the recharge desk', (
      tester,
    ) async {
      var exited = false;
      await _pumpShell(
        tester,
        session: _accountant,
        repository: _Repository(
          CanteenStore(
            user: const CanteenUser(
              id: 'acc',
              name: 'Campus Accountant',
              email: 'accounts@mec.local',
              rollNumber: 'Not assigned',
              department: 'Not assigned',
            ),
            menu: _store(configuresShops: false).menu,
            orders: const [],
            walletTransactions: const [],
            shops: const [_canteen, _laundry, _stationery],
          ),
        ),
        initialAction: 'shop',
        onExitModule: () => exited = true,
      );

      expect(find.text('Campus Canteen'), findsOneWidget);
      expect(find.text('Stationery Store'), findsOneWidget);
      expect(find.text('Campus Laundry'), findsOneWidget);

      await tester.tap(find.byTooltip('Switch to Work'));
      await tester.pumpAndSettle();
      expect(exited, isTrue);
    });

    testWidgets('students get no Work / Shop switch', (tester) async {
      await _pumpShell(
        tester,
        session: const UserSession(
          email: 'student001@mec.local',
          displayName: 'Student',
          role: UserRole.student,
          activePortalFamily: PortalFamily.student,
        ),
        repository: _Repository(
          _store(configuresShops: false, mode: CanteenStaffMode.eat),
        ),
      );
      expect(find.text('Campus Canteen'), findsOneWidget);
      expect(find.byTooltip('Switch to Work'), findsNothing);
    });
  });
}
