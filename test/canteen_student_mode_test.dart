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
