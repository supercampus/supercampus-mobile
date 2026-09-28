import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_captain_home.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_owner_home.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/owner_workspace_nav.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/widgets/canteen_order_detail_page.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/widgets/settled_orders_page.dart';

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

  testWidgets('owner Orders keeps one settled row that opens its own page, '
      'and each settled order opens its details', (tester) async {
    await _pump(
      tester,
      CanteenOwnerHome(
        store: _store(),
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

    // No dropdown and no counter-controls button.
    expect(find.byIcon(Icons.expand_more), findsNothing);
    expect(find.byTooltip('Counter controls'), findsNothing);
    expect(find.text('Counter open'), findsOneWidget);
    // Settled orders are not listed inline.
    expect(find.byKey(const ValueKey('settled-order-order-delivered')),
        findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('settled-orders-link')),
      200,
    );
    await tester.tap(find.byKey(const ValueKey('settled-orders-link')));
    await tester.pumpAndSettle();

    expect(find.byType(SettledOrdersPage), findsOneWidget);
    expect(find.byKey(const ValueKey('settled-order-order-delivered')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('settled-order-order-rejected')),
        findsOneWidget);
    // The live order is not settled.
    expect(find.byKey(const ValueKey('settled-order-order-pending')),
        findsNothing);

    // Search narrows the list.
    await tester.enterText(find.byType(TextField), 'babu');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settled-order-order-delivered')),
        findsNothing);
    expect(find.byKey(const ValueKey('settled-order-order-rejected')),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('settled-order-order-rejected')));
    await tester.pumpAndSettle();
    expect(find.byType(CanteenOrderDetailPage), findsOneWidget);
    expect(find.text('Order #0047'), findsOneWidget);
    expect(find.text('Babu Student'), findsOneWidget);
    expect(find.text('Dine in'), findsOneWidget);
    expect(find.text('Rejected'), findsWidgets);

    // Back to the list, then back to the workspace.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(SettledOrdersPage), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Live order queue'), findsOneWidget);
  });

  testWidgets('the host bar can open the owner menu', (tester) async {
    final nav = OwnerWorkspaceNav();
    addTearDown(nav.dispose);
    await _pump(
      tester,
      CanteenOwnerHome(
        store: _store(),
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

    expect(nav.menuAvailable, isTrue);
    expect(nav.section, OwnerSection.orders);

    nav.show(OwnerSection.menu);
    await tester.pumpAndSettle();
    expect(nav.section, OwnerSection.menu);
    expect(find.text('Menu management'), findsOneWidget);
    expect(find.byTooltip('Add menu item'), findsOneWidget);

    // Leaving the workspace gives the bar its Modules entry back.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pumpAndSettle();
    expect(nav.menuAvailable, isFalse);
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

    await tester.tap(find.byKey(const ValueKey('captain-history-order-delivered')));
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
