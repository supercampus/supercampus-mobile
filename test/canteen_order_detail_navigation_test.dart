import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/core/widgets/campus_nav_bar.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_captain_home.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_owner_home.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/owner_workspace_nav.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/widgets/canteen_order_detail_page.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/widgets/settled_orders_page.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/widgets/shop_mode_switch.dart';

const _dosa = CanteenMenuItem(
  id: 'dosa',
  name: 'Masala Dosa',
  description: '',
  category: 'meals',
  price: 60,
  isVegetarian: true,
  shopKey: 'mec-canteen',
);
const _tea = CanteenMenuItem(
  id: 'tea',
  name: 'Masala Tea',
  description: '',
  category: 'drinks',
  price: 15,
  isVegetarian: true,
  shopKey: 'mec-canteen',
);

final _delivered = CanteenOrder(
  id: 'order-delivered',
  orderNumber: '46',
  customerName: 'Anu Student',
  captainName: 'Ravi',
  total: 135,
  status: CanteenOrderStatus.completed,
  fulfilmentMode: FulfilmentMode.pickup,
  createdAt: DateTime(2026, 9, 28, 9, 30),
  tokenNumber: 12,
  lines: const [
    CartLine(item: _dosa, quantity: 2),
    CartLine(item: _tea, quantity: 1),
  ],
);

final _rejected = CanteenOrder(
  id: 'order-rejected',
  orderNumber: '47',
  customerName: 'Babu Student',
  total: 15,
  status: CanteenOrderStatus.rejected,
  fulfilmentMode: FulfilmentMode.dineIn,
  createdAt: DateTime(2026, 9, 27, 13, 5),
  lines: const [CartLine(item: _tea, quantity: 1)],
);

final _pending = CanteenOrder(
  id: 'order-pending',
  orderNumber: '48',
  customerName: 'Chitra Student',
  total: 60,
  status: CanteenOrderStatus.pending,
  fulfilmentMode: FulfilmentMode.pickup,
  createdAt: DateTime(2026, 9, 28, 10),
  lines: const [CartLine(item: _dosa, quantity: 1)],
);

CanteenStore _store() => CanteenStore(
  user: const CanteenUser(
    name: 'Owner',
    email: 'owner@mec.local',
    rollNumber: 'STAFF01',
    department: 'Canteen',
  ),
  menu: const [_dosa, _tea],
  orders: [_pending, _delivered, _rejected],
  walletTransactions: const [],
  shops: const [
    CanteenShop(
      id: 'shop-1',
      shopKey: 'mec-canteen',
      name: 'Campus Canteen',
      category: 'canteen',
    ),
  ],
  assignedShopKeys: const ['mec-canteen'],
  canManage: true,
  staffState: const CanteenStaffState(
    mode: CanteenStaffMode.work,
    shopOpen: true,
  ),
);

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: home));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the detail page shows everything the order carries', (
    tester,
  ) async {
    await _pump(tester, CanteenOrderDetailPage(order: _delivered));

    expect(find.text('Order #0046'), findsOneWidget);
    expect(find.text('Anu Student'), findsOneWidget);
    expect(find.text('Masala Dosa'), findsOneWidget);
    expect(find.text('2 × ₹60'), findsOneWidget);
    expect(find.text('₹120'), findsOneWidget);
    expect(find.text('Masala Tea'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(find.text('₹135'), findsWidgets);
    expect(find.text('Pickup'), findsOneWidget);
    expect(find.text('Ravi'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Placed'), findsWidgets);
    expect(find.text('Delivered'), findsWidgets);
  });

  CanteenOwnerHome ownerHome({
    OwnerWorkspaceNav? nav,
    Future<void> Function(bool open)? onShopOpenChanged,
  }) => CanteenOwnerHome(
    store: _store(),
    nav: nav,
    onExitModule: () {},
    onSignOut: () {},
    onRefresh: () async {},
    onModeChanged: (_) async {},
    onShopOpenChanged: onShopOpenChanged ?? (_) async {},
    onOrderStatusChanged: (_, _, {lineIndex}) async {},
    onSaveMenuItem: (_, _) async {},
    onDeleteMenuItem: (_) async {},
    onUploadMedia: (_, _) async => '',
    isMainHome: true,
  );

  testWidgets('Settled is a destination of its own bar next to Menu, and '
      'each settled order opens its details', (tester) async {
    await _pump(tester, ownerHome());

    // Home is the live queue alone: no section tabs, no counter switch, no
    // settled row.
    expect(find.byType(SegmentedButton<OwnerSection>), findsNothing);
    expect(find.text('Counter open'), findsNothing);
    expect(find.byKey(const ValueKey('settled-orders-link')), findsNothing);
    expect(find.text('Live order queue'), findsOneWidget);

    // Opened on its own, the workspace floats the same bar the host would.
    final bar = find.byType(CampusNavBar);
    expect(bar, findsOneWidget);
    for (final label in ['Home', 'Menu', 'Settled', 'Sales']) {
      expect(
        find.descendant(of: bar, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: bar, matching: find.text('Modules')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('nav-scan')), findsNothing);
    expect(
      tester.getCenter(find.byKey(const ValueKey('nav-settled'))).dx,
      greaterThan(tester.getCenter(find.byKey(const ValueKey('nav-menu'))).dx),
    );

    await tester.tap(find.byKey(const ValueKey('nav-settled')));
    await tester.pumpAndSettle();

    expect(find.byType(SettledOrdersView), findsOneWidget);
    expect(find.text('Settled orders'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('settled-order-order-delivered')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('settled-order-order-rejected')),
      findsOneWidget,
    );
    // The live order is not settled.
    expect(
      find.byKey(const ValueKey('settled-order-order-pending')),
      findsNothing,
    );

    // Search narrows the list.
    await tester.enterText(
      find.descendant(
        of: find.byType(SettledOrdersView),
        matching: find.byType(TextField),
      ),
      'babu',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('settled-order-order-delivered')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('settled-order-order-rejected')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CanteenOrderDetailPage), findsOneWidget);
    expect(find.text('Order #0047'), findsOneWidget);
    expect(find.text('Babu Student'), findsOneWidget);
    expect(find.text('Dine in'), findsOneWidget);
    expect(find.text('Rejected'), findsWidgets);

    // Back to Settled, then Android back returns Home before it leaves.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(SettledOrdersView), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Live order queue'), findsOneWidget);
    final homeLabel = tester.widget<Text>(
      find.descendant(of: bar, matching: find.text('Home')),
    );
    expect(homeLabel.style!.fontWeight, FontWeight.w700);
  });

  testWidgets('the host bar opens every section and the profile opens and '
      'closes the counter', (tester) async {
    final nav = OwnerWorkspaceNav();
    addTearDown(nav.dispose);
    final changes = <bool>[];
    await _pump(
      tester,
      ownerHome(nav: nav, onShopOpenChanged: (open) async => changes.add(open)),
    );

    // Hosted, the page floats no bar of its own; the host draws the nav's.
    expect(find.byType(CampusNavBar), findsNothing);
    expect(nav.menuAvailable, isTrue);
    expect(nav.sections, [
      OwnerSection.orders,
      OwnerSection.menu,
      OwnerSection.settled,
      OwnerSection.sales,
    ]);
    expect(nav.section, OwnerSection.orders);
    expect(ownerNavItems(nav.sections, (_) {}).map((item) => item.label), [
      'Home',
      'Menu',
      'Settled',
      'Sales',
    ]);

    nav.show(OwnerSection.menu);
    await tester.pumpAndSettle();
    expect(nav.section, OwnerSection.menu);
    expect(ownerNavId(nav.section), 'menu');
    expect(find.text('Menu management'), findsOneWidget);
    expect(find.byKey(const ValueKey('owner-menu-add')), findsOneWidget);
    expect(find.byKey(const ValueKey('owner-menu-type')), findsOneWidget);

    nav.show(OwnerSection.settled);
    await tester.pumpAndSettle();
    expect(find.byType(SettledOrdersView), findsOneWidget);

    nav.show(OwnerSection.sales);
    await tester.pumpAndSettle();
    expect(nav.section, OwnerSection.sales);
    expect(find.text('Sales & Profit Analytics'), findsOneWidget);

    // The counter is the account's: its switch lives in the profile sheet.
    expect(nav.counterOpen, isTrue);
    await nav.setCounterOpen(false);
    await tester.pumpAndSettle();
    expect(changes, [false]);

    // Android back from Sales returns Home rather than leaving.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(nav.section, OwnerSection.orders);
    expect(find.text('Live order queue'), findsOneWidget);

    // Leaving the workspace gives the bar its Modules entry back.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(nav.menuAvailable, isFalse);
    expect(nav.sections, isEmpty);
    expect(nav.counterOpen, isNull);
  });

  testWidgets('an account overseeing the shops has no counter to open', (
    tester,
  ) async {
    final nav = OwnerWorkspaceNav();
    addTearDown(nav.dispose);
    await _pump(
      tester,
      CanteenOwnerHome(
        store: _store().copyWith(assignedShopKeys: const []),
        nav: nav,
        onExitModule: () {},
        onSignOut: () {},
        onRefresh: () async {},
        onModeChanged: (_) async {},
        onShopOpenChanged: (_) async {},
        onOrderStatusChanged: (_, _, {lineIndex}) async {},
        onSaveMenuItem: (_, _) async {},
        onDeleteMenuItem: (_) async {},
        onUploadMedia: (_, _) async => '',
        isMainHome: true,
      ),
    );
    expect(nav.counterOpen, isNull);
  });

  testWidgets('the shop account sheet carries Counter open beside Settings', (
    tester,
  ) async {
    var open = true;
    await _pump(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showShopAccountSheet(
              context,
              name: 'Canteen Owner',
              email: 'owner@mec.local',
              counterOpen: () => open,
              onCounterOpenChanged: (value) async => open = value,
              onOpenSettings: () {},
              onSignOut: () {},
            ),
            child: const Text('Account'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();

    expect(find.text('Counter open'), findsOneWidget);
    expect(find.text('Taking new orders'), findsOneWidget);
    // Next to Settings.
    expect(
      tester.getRect(find.text('Counter open')).top,
      lessThan(tester.getRect(find.text('Settings')).top),
    );

    await tester.tap(find.byKey(const ValueKey('counter-open-switch')));
    await tester.pumpAndSettle();
    expect(open, isFalse);
    expect(find.text('Counter closed'), findsOneWidget);
    expect(find.text('Not taking new orders'), findsOneWidget);
  });

  testWidgets('without a counter the shop account sheet has no switch', (
    tester,
  ) async {
    await _pump(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => showShopAccountSheet(
              context,
              name: 'Campus Admin',
              email: 'admin@mec.local',
              onSignOut: () {},
            ),
            child: const Text('Account'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Account'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('counter-open-switch')), findsNothing);
  });

  testWidgets('captain History opens an order\'s details on tap', (
    tester,
  ) async {
    await _pump(
      tester,
      CanteenCaptainHome(
        store: _store(),
        onExitModule: () {},
        onSignOut: () {},
        onRefresh: () async {},
        onModeChanged: (_) async {},
        onOrderStatusChanged: (_, _, {lineIndex}) async {},
        isMainHome: true,
      ),
    );

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Order history'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('captain-history-order-delivered')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(CanteenOrderDetailPage), findsOneWidget);
    expect(find.text('Order #0046'), findsOneWidget);
    expect(find.text('Anu Student'), findsOneWidget);
    expect(find.text('Masala Dosa'), findsOneWidget);
    expect(find.text('Ravi'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Order history'), findsOneWidget);
  });
}
