import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/stationery_operator_home.dart';

void main() {
  test('UserSession identifies stationary@mec.local and stationery roles', () {
    const session1 = UserSession(
      email: 'stationary@mec.local',
      displayName: 'Stationery Operator',
      role: UserRole.staff,
      activePortalFamily: PortalFamily.staff,
    );
    expect(session1.isStationeryOwner, isTrue);

    const session2 = UserSession(
      email: 'stationery@mec.local',
      displayName: 'Stationery Manager',
      role: UserRole.staff,
      activePortalFamily: PortalFamily.staff,
    );
    expect(session2.isStationeryOwner, isTrue);

    const session3 = UserSession(
      email: 'custom@mec.local',
      displayName: 'Stationery Person',
      role: UserRole.staff,
      roleIds: ['stationery_operator'],
      activePortalFamily: PortalFamily.staff,
    );
    expect(session3.isStationeryOwner, isTrue);
  });

  testWidgets('StationeryOperatorHome displays Orders tab by default without Profile segment', (
    tester,
  ) async {
    final store = _createSampleStore();

    await tester.pumpWidget(
      MaterialApp(
        home: StationeryOperatorHome(
          store: store,
          onExitModule: () {},
          onSignOut: () {},
          onRefresh: () async {},
          onCounterStateChanged: (_) async {},
          onShopOpenChanged: (_) async {},
          onOrderStatusChanged: (_, _) async {},
          onSaveItem: (_, _) async {},
          onUploadMedia: (_, _) async => '',
          isMainHome: true,
          displayName: 'MEC Stationery',
          email: 'stationary@mec.local',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Orders tab is active by default (matching Image 1)
    expect(find.text('Stationery orders'), findsOneWidget);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);

    // Verify switcher only has Inventory and Orders (Profile segment removed)
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Profile'), findsNothing);

    // Verify top profile button exists on AppBar
    expect(find.byKey(const ValueKey('stationery-top-profile-btn')), findsOneWidget);
  });

  testWidgets('Tapping top profile icon opens settings sheet with Shop Status and Workspace Mode', (
    tester,
  ) async {
    final store = _createSampleStore();
    bool? shopOpenChangedTo;
    CanteenStaffMode? modeChangedTo;

    await tester.pumpWidget(
      MaterialApp(
        home: StationeryOperatorHome(
          store: store,
          onExitModule: () {},
          onSignOut: () {},
          onRefresh: () async {},
          onCounterStateChanged: (mode) async {
            modeChangedTo = mode;
          },
          onShopOpenChanged: (open) async {
            shopOpenChangedTo = open;
          },
          onOrderStatusChanged: (_, _) async {},
          onSaveItem: (_, _) async {},
          onUploadMedia: (_, _) async => '',
          isMainHome: true,
          displayName: 'MEC Stationery',
          email: 'stationary@mec.local',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the top profile icon
    await tester.tap(find.byKey(const ValueKey('stationery-top-profile-btn')));
    await tester.pumpAndSettle();

    // Verify settings sheet content
    expect(find.text('Stationery Shop Operator'), findsOneWidget);
    expect(find.text('Shop Status'), findsOneWidget);
    expect(find.text('Workspace Mode'), findsOneWidget);
    expect(find.text('Work mode'), findsOneWidget);
    expect(find.text('Eat mode'), findsOneWidget);

    // Toggle shop status switch
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(shopOpenChangedTo, isFalse);

    // Tap Eat mode in segmented button
    await tester.tap(find.text('Eat mode'));
    await tester.pumpAndSettle();
    expect(modeChangedTo, equals(CanteenStaffMode.eat));
  });

  testWidgets('Inventory tab shows Add item button in header, FAB, and saves new item', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final store = _createSampleStore();
    CanteenMenuItem? savedItem;
    bool? wasCreated;

    await tester.pumpWidget(
      MaterialApp(
        home: StationeryOperatorHome(
          store: store,
          onExitModule: () {},
          onSignOut: () {},
          onRefresh: () async {},
          onCounterStateChanged: (_) async {},
          onShopOpenChanged: (_) async {},
          onOrderStatusChanged: (_, _) async {},
          onSaveItem: (item, create) async {
            savedItem = item;
            wasCreated = create;
          },
          onUploadMedia: (_, _) async => '',
          isMainHome: true,
          displayName: 'MEC Stationery',
          email: 'stationary@mec.local',
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Switch to Inventory tab
    await tester.tap(find.text('Inventory'));
    await tester.pumpAndSettle();

    // Verify Inventory header and buttons
    expect(find.text('Stationery inventory'), findsOneWidget);
    expect(find.byKey(const ValueKey('stationery-header-add-btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('stationery-add-item-fab')), findsOneWidget);

    // Tap the header "Add item" button
    await tester.tap(find.byKey(const ValueKey('stationery-header-add-btn')));
    await tester.pumpAndSettle();

    // Verify the Add item editor opened
    expect(find.text('Add stationery item'), findsOneWidget);
    // Fill in item details
    await tester.enterText(
      find.byKey(const ValueKey('stationery-edit-name')),
      'Camel Geometry Box',
    );
    await tester.enterText(
      find.byKey(const ValueKey('stationery-edit-selling-price')),
      '120.00',
    );

    // Save item
    await tester.tap(find.byKey(const ValueKey('stationery-edit-save')));
    await tester.pumpAndSettle();

    expect(savedItem, isNotNull);
    expect(savedItem!.name, 'Camel Geometry Box');
    expect(savedItem!.price, 120.00);
    expect(savedItem!.store, MenuStore.stationery);
    expect(wasCreated, isTrue);
  });
}

CanteenStore _createSampleStore() {
  return CanteenStore(
    user: const CanteenUser(
      name: 'Stationery Operator',
      email: 'stationary@mec.local',
      rollNumber: 'STA-01',
      department: 'Stationery',
    ),
    menu: const [
      CanteenMenuItem(
        id: 'stat_1',
        name: 'Classmate 200-page Notebook',
        description: 'Single ruled A4 notebook',
        category: 'Notebooks',
        price: 65.0,
        isVegetarian: true,
        store: MenuStore.stationery,
        shopKey: 'stationery',
      ),
    ],
    orders: [
      CanteenOrder(
        id: 'ord_1',
        total: 65.0,
        createdAt: DateTime.parse('2026-09-26T10:00:00Z'),
        status: CanteenOrderStatus.pending,
        fulfilmentMode: FulfilmentMode.pickup,
        lines: const [
          CartLine(
            item: CanteenMenuItem(
              id: 'stat_1',
              name: 'Classmate 200-page Notebook',
              description: 'Single ruled A4 notebook',
              category: 'Notebooks',
              price: 65.0,
              isVegetarian: true,
              store: MenuStore.stationery,
              shopKey: 'stationery',
            ),
            quantity: 1,
          ),
        ],
      ),
    ],
    walletTransactions: const [],
    canManage: true,
    canManageMenu: true,
    staffState: const CanteenStaffState(
      mode: CanteenStaffMode.work,
      shopOpen: true,
    ),
  );
}
