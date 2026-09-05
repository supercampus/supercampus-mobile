import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_shell.dart';

void main() {
  testWidgets('student portal never exposes canteen work mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CanteenShell(
          session: const UserSession(
            email: 'student@example.com',
            displayName: 'Student',
            role: UserRole.student,
            activePortalFamily: PortalFamily.student,
          ),
          repository: _ManagerStoreRepository(),
          onExitModule: () {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shop operations'), findsNothing);
    expect(find.text('Work'), findsNothing);
    expect(find.byTooltip('Switch to owner workspace'), findsNothing);
  });

  testWidgets('staff manager keeps the canteen owner workspace', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CanteenShell(
          session: const UserSession(
            email: 'owner@example.com',
            displayName: 'Owner',
            role: UserRole.staff,
            activePortalFamily: PortalFamily.staff,
          ),
          repository: _ManagerStoreRepository(),
          onExitModule: () {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Shop operations'), findsOneWidget);

    // Work/Eat and the open toggle are occasional decisions, so they no longer
    // take a strip off the top of the page — they open from the app bar.
    expect(find.text('Work'), findsNothing);
    expect(find.byTooltip('Counter controls'), findsOneWidget);

    await tester.tap(find.byTooltip('Counter controls'));
    await tester.pumpAndSettle();
    expect(find.text('Counter controls'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Eat'), findsOneWidget);
  });

  testWidgets('order-only staff opens the canteen captain workspace', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CanteenShell(
          session: const UserSession(
            email: 'shashi@mec.local',
            displayName: 'Shashi',
            role: UserRole.staff,
            activePortalFamily: PortalFamily.staff,
          ),
          repository: _CaptainStoreRepository(),
          onExitModule: () {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Canteen captain'), findsOneWidget);
    expect(find.text('Live orders'), findsOneWidget);
    expect(find.text('Menu'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Captain profile'), findsOneWidget);
    expect(find.text('Eat / work mode'), findsOneWidget);
  });

  testWidgets(
    'stationery operator opens inventory instead of canteen captain',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CanteenShell(
            session: const UserSession(
              email: 'stationary@mec.local',
              displayName: 'MEC Stationery',
              role: UserRole.staff,
              roleId: 'stationery_operator',
              roleIds: ['stationery_operator'],
              activePortalFamily: PortalFamily.staff,
            ),
            repository: _StationeryStoreRepository(),
            onExitModule: () {},
            onSignOut: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Stationery shop'), findsOneWidget);
      expect(find.text('Stationery inventory'), findsOneWidget);
      expect(find.text('2 items · 2 categories'), findsOneWidget);
      expect(find.text('A4 Notebook'), findsOneWidget);
      expect(find.text('Blue Ball Pen'), findsOneWidget);
      expect(find.text('Canteen captain'), findsNothing);
      expect(find.text('No active food orders.'), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);
      expect(find.byType(BottomNavigationBar), findsNothing);
    },
  );

  testWidgets('stationery operator edits and saves inventory details', (
    tester,
  ) async {
    final repository = _StationeryStoreRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: CanteenShell(
          session: const UserSession(
            email: 'stationary@mec.local',
            displayName: 'MEC Stationery',
            role: UserRole.staff,
            roleId: 'stationery_operator',
            roleIds: ['stationery_operator'],
            activePortalFamily: PortalFamily.staff,
          ),
          repository: repository,
          onExitModule: () {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Edit A4 Notebook'));
    await tester.pumpAndSettle();
    expect(find.text('Edit inventory item'), findsOneWidget);
    expect(find.text('Actual price'), findsOneWidget);
    expect(find.text('Selling price'), findsOneWidget);
    expect(find.text('Available for purchase'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('stationery-edit-name')),
      'A4 Premium Notebook',
    );
    await tester.enterText(
      find.byKey(const ValueKey('stationery-edit-description')),
      '200 ruled pages',
    );
    await tester.enterText(
      find.byKey(const ValueKey('stationery-edit-actual-price')),
      '45',
    );
    await tester.enterText(
      find.byKey(const ValueKey('stationery-edit-selling-price')),
      '75',
    );
    await tester.tap(find.byKey(const ValueKey('stationery-edit-available')));
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('stationery-edit-save')));
    await tester.pumpAndSettle();

    expect(repository.savedItem, isNotNull);
    expect(repository.savedItem!.name, 'A4 Premium Notebook');
    expect(repository.savedItem!.description, '200 ruled pages');
    expect(repository.savedItem!.actualPrice, 45);
    expect(repository.savedItem!.price, 75);
    expect(repository.savedItem!.isAvailable, isFalse);
  });

  testWidgets('laundry account opens the QR charge workspace', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CanteenShell(
          session: const UserSession(
            email: 'laundry@mec.local',
            displayName: 'MEC Laundry',
            role: UserRole.staff,
            activePortalFamily: PortalFamily.staff,
          ),
          repository: _LaundryStoreRepository(operator: true),
          onExitModule: () {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Create student payment QR'), findsOneWidget);
    expect(find.text('Wash by kg'), findsOneWidget);
    expect(find.text('Ironing'), findsOneWidget);
    expect(find.text('Generate QR'), findsOneWidget);
  });

  testWidgets('claimed laundry charge appears as a student wallet payment', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CanteenShell(
          session: const UserSession(
            email: 'student@example.com',
            displayName: 'Student',
            role: UserRole.student,
            activePortalFamily: PortalFamily.student,
          ),
          repository: _LaundryStoreRepository(operator: false),
          initialAction: 'laundry',
          onExitModule: () {},
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Laundry bag 14'), findsOneWidget);
    expect(find.text('Pay from wallet'), findsOneWidget);
  });
}

class _LaundryStoreRepository implements CanteenRepository {
  _LaundryStoreRepository({required this.operator});

  final bool operator;

  @override
  Future<CanteenStore> loadStore() async => CanteenStore(
    user: CanteenUser(
      name: operator ? 'MEC Laundry' : 'Student',
      email: operator ? 'laundry@mec.local' : 'student@example.com',
      rollNumber: operator ? 'MECLAU001' : 'MEC26CS041',
      department: operator ? 'Laundry' : 'CSE',
    ),
    walletBalance: operator ? 0 : 500,
    menu: const [],
    orders: const [],
    walletTransactions: const [],
    shops: const [
      CanteenShop(
        id: 'laundry',
        shopKey: 'mec-laundry',
        name: 'Campus Laundry',
        category: 'laundry',
      ),
    ],
    assignedShopKeys: operator ? const ['mec-laundry'] : const [],
    canManage: operator,
    laundryPricePerKg: 50,
    laundryCharges: operator
        ? const []
        : [
            LaundryCharge(
              id: 'charge-1',
              serviceType: LaundryServiceType.wash,
              name: 'Laundry bag 14',
              description: 'Blue bag',
              quantity: 2,
              unitLabel: 'kg',
              unitPrice: 50,
              total: 100,
              status: LaundryChargeStatus.claimed,
              createdAt: DateTime(2026, 9, 5),
            ),
          ],
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StationeryStoreRepository implements CanteenRepository {
  CanteenMenuItem? savedItem;

  @override
  Future<CanteenStore> loadStore() async => const CanteenStore(
    user: CanteenUser(
      name: 'MEC Stationery',
      email: 'stationary@mec.local',
      rollNumber: 'MECSTA001',
      department: 'Stationery',
    ),
    walletBalance: 0,
    menu: [
      CanteenMenuItem(
        id: 'notebook',
        name: 'A4 Notebook',
        description: '',
        category: 'Notebooks',
        price: 60,
        actualPrice: 45,
        isVegetarian: true,
        store: MenuStore.stationery,
        shopKey: 'stationery',
      ),
      CanteenMenuItem(
        id: 'pen',
        name: 'Blue Ball Pen',
        description: '',
        category: 'Writing',
        price: 10,
        isVegetarian: true,
        store: MenuStore.stationery,
        shopKey: 'stationery',
      ),
    ],
    orders: [],
    walletTransactions: [],
    shops: [
      CanteenShop(
        id: 'stationery',
        shopKey: 'stationery',
        name: 'MEC Stationery',
        category: 'Stationery',
      ),
    ],
    assignedShopKeys: ['stationery'],
    canManage: true,
    canManageMenu: false,
    staffState: CanteenStaffState(mode: CanteenStaffMode.work),
  );

  @override
  Future<CanteenMenuItem> saveMenuItem(
    CanteenMenuItem item, {
    required bool create,
  }) async {
    savedItem = item;
    return item;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CaptainStoreRepository implements CanteenRepository {
  @override
  Future<CanteenStore> loadStore() async => const CanteenStore(
    user: CanteenUser(
      name: 'Shashi',
      email: 'shashi@mec.local',
      rollNumber: 'MECCAP001',
      department: 'Canteen',
    ),
    walletBalance: 0,
    menu: [],
    orders: [],
    walletTransactions: [],
    shops: [
      CanteenShop(
        id: 'canteen-main',
        shopKey: 'canteen-main',
        name: 'Canteen',
        category: 'Canteen',
      ),
    ],
    assignedShopKeys: ['canteen-main'],
    canManage: true,
    canManageMenu: false,
    staffState: CanteenStaffState(mode: CanteenStaffMode.work),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ManagerStoreRepository implements CanteenRepository {
  @override
  Future<CanteenStore> loadStore() async => const CanteenStore(
    user: CanteenUser(
      name: 'Student',
      email: 'student@example.com',
      rollNumber: 'SC-1',
      department: 'CSE',
    ),
    walletBalance: 0,
    menu: [],
    orders: [],
    walletTransactions: [],
    shops: [
      CanteenShop(
        id: 'canteen-main',
        shopKey: 'canteen-main',
        name: 'Main Canteen',
        category: 'Canteen',
      ),
    ],
    assignedShopKeys: ['canteen-main'],
    canManage: true,
    staffState: CanteenStaffState(mode: CanteenStaffMode.work),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
