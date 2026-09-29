import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_captain_home.dart';

CanteenStore _store({required bool pending}) => CanteenStore(
  user: const CanteenUser(
    name: 'New Captain',
    email: 'newcap@mec.local',
    rollNumber: 'STAFF09',
    department: 'Canteen',
  ),
  menu: const [],
  orders: const [],
  walletTransactions: const [],
  staffState: const CanteenStaffState(mode: CanteenStaffMode.work),
  shopAssignmentPending: pending,
  shopAssignmentMessage: pending
      ? "You're not assigned to a counter yet. Ask the admin to add you to a shop."
      : null,
);

Future<void> _pump(WidgetTester tester, CanteenStore store) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: CanteenCaptainHome(
        store: store,
        onExitModule: () {},
        onSignOut: () {},
        onRefresh: () async {},
        onModeChanged: (_) async {},
        onOrderStatusChanged: (_, _, {lineIndex}) async {},
        onScanOrder: (_) async => null,
        isMainHome: true,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a captain with no counter is told so instead of an empty queue', (
    tester,
  ) async {
    await _pump(tester, _store(pending: true));

    expect(find.text('Not assigned to a counter'), findsOneWidget);
    expect(
      find.textContaining("You're not assigned to a counter yet"),
      findsOneWidget,
    );
    expect(find.text('No active food orders.'), findsNothing);
    expect(find.textContaining('0 waiting'), findsNothing);

    // Scan explains the same thing rather than opening the camera.
    await tester.tap(find.text('Scan'));
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.textContaining('Ask the admin'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('an assigned captain with a quiet counter sees the empty queue', (
    tester,
  ) async {
    await _pump(tester, _store(pending: false));

    expect(find.text('No active food orders.'), findsOneWidget);
    expect(find.text('Not assigned to a counter'), findsNothing);
  });

  test('the store falls back to the standard wording', () {
    final store = CanteenStore(
      user: const CanteenUser(
        name: 'X',
        email: 'x@mec.local',
        rollNumber: '-',
        department: '-',
      ),
      menu: const [],
      orders: const [],
      walletTransactions: const [],
      shopAssignmentPending: true,
    );
    expect(store.unassignedCounterMessage, unassignedCounterFallbackMessage);
    // copyWith keeps the flag through the shell's local updates.
    expect(store.copyWith(orders: const []).shopAssignmentPending, isTrue);
  });
}
