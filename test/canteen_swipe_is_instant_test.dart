import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_shell.dart';

const _canteen = CanteenShop(
  id: 'mec-canteen',
  shopKey: 'mec-canteen',
  name: 'Campus Canteen',
  category: 'canteen',
);

const _rice = CanteenMenuItem(
  id: 'rice',
  name: 'Chicken Fried Rice',
  description: '',
  category: 'meals',
  price: 90,
  isVegetarian: false,
  shopKey: 'mec-canteen',
);

const _water = CanteenMenuItem(
  id: 'water',
  name: 'Water Bottle',
  description: '',
  category: 'drinks',
  price: 20,
  isVegetarian: true,
  isInstant: true,
  shopKey: 'mec-canteen',
);

final _order = CanteenOrder(
  id: 'o1',
  orderNumber: '71',
  customerName: 'Vishnu S',
  lines: const [
    CartLine(item: _rice, quantity: 1),
    CartLine(item: _water, quantity: 1),
  ],
  total: 110,
  status: CanteenOrderStatus.pending,
  fulfilmentMode: FulfilmentMode.pickup,
  createdAt: DateTime(2026, 9, 28, 13),
);

CanteenStore _store(List<CanteenOrder> orders) => CanteenStore(
  user: const CanteenUser(
    id: 'owner',
    name: 'Canteen Owner',
    email: 'owner@example.com',
    rollNumber: 'Not assigned',
    department: 'Not assigned',
  ),
  walletBalances: const {},
  menu: const [_rice, _water],
  orders: orders,
  walletTransactions: const [],
  shops: const [_canteen],
  assignedShopKeys: const ['mec-canteen'],
  canManage: true,
  canConfigureShops: false,
  staffState: const CanteenStaffState(
    mode: CanteenStaffMode.work,
    shopOpen: true,
  ),
);

/// The server answers only when the test says so, so the test can look at
/// the screen while the request is still in flight.
class _SlowRepository implements CanteenRepository {
  final reply = Completer<void>();
  final calls = <(String, CanteenOrderStatus, int?)>[];
  var loads = 0;

  @override
  Future<CanteenStore> loadStore() async {
    loads++;
    return _store([_order]);
  }

  @override
  Future<void> updateOrderStatus(
    String orderId,
    CanteenOrderStatus status, {
    String? reason,
    int? lineIndex,
  }) async {
    calls.add((orderId, status, lineIndex));
    await reply.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _owner = UserSession(
  email: 'canteen.owner@mec.local',
  displayName: 'Canteen Owner',
  role: UserRole.staff,
  roleId: 'owner',
  roleIds: ['owner'],
  activePortalFamily: PortalFamily.staff,
);

void main() {
  testWidgets('a swiped item moves on screen before the server answers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final repository = _SlowRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CanteenShell(
            session: _owner,
            repository: repository,
            onExitModule: () {},
            onSignOut: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('o1_0_pending')), findsOneWidget);
    expect(find.byKey(const ValueKey('o1_1_pending')), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('o1_0_pending')),
      const Offset(500, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The request is still waiting, yet the rice has already moved to
    // preparing and the water is untouched.
    expect(repository.reply.isCompleted, isFalse);
    expect(repository.calls, [('o1', CanteenOrderStatus.preparing, 0)]);
    expect(find.byKey(const ValueKey('o1_0_preparing')), findsOneWidget);
    expect(find.byKey(const ValueKey('o1_1_pending')), findsOneWidget);

    repository.reply.complete();
    await tester.pumpAndSettle();
  });
}
