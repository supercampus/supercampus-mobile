import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/widgets/campus_nav_bar.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/data/mock_canteen_repository.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/module_dashboard_screen.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/laundry_operator_home.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/laundry_workspace_nav.dart';

LaundryCharge _charge(
  LaundryChargeStatus status, {
  String id = 'charge-1',
  String name = 'Room 204 bundle',
}) => LaundryCharge(
  id: id,
  serviceType: LaundryServiceType.wash,
  name: name,
  description: '',
  quantity: 2,
  unitLabel: 'kg',
  unitPrice: 40,
  total: 80,
  status: status,
  createdAt: DateTime(2026, 9, 29, 10),
  qrPayload: status == LaundryChargeStatus.pending ||
          status == LaundryChargeStatus.claimed
      ? 'supercampus://laundry/test-token'
      : null,
  paidAt: status == LaundryChargeStatus.paid ? DateTime(2026, 9, 29, 11) : null,
);

Future<void> _pumpSheet(
  WidgetTester tester,
  ValueNotifier<List<LaundryCharge>> charges, {
  Future<void> Function(LaundryCharge charge)? onCancel,
  Future<void> Function()? onRefresh,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: LaundryChargeSheet(
          charge: charges.value.first,
          charges: charges,
          onRefresh: onRefresh ?? () async {},
          onCancel: onCancel ?? (_) async {},
          pollInterval: const Duration(seconds: 5),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an unscanned charge shows its QR with Cancel and Done', (
    tester,
  ) async {
    final charges = ValueNotifier([_charge(LaundryChargeStatus.pending)]);
    await _pumpSheet(tester, charges);

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
    expect(find.text('Pending payment'), findsNothing);
    expect(find.text('Payment successful'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a scanned charge shows Pending payment, not the QR actions', (
    tester,
  ) async {
    final charges = ValueNotifier([_charge(LaundryChargeStatus.pending)]);
    await _pumpSheet(tester, charges);

    // The student claims it; the store reload reaches the open sheet.
    charges.value = [_charge(LaundryChargeStatus.claimed)];
    await tester.pumpAndSettle();

    expect(find.text('Pending payment'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Done'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Cancel'), findsNothing);
    expect(find.text('Payment successful'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Payment successful appears only once the student paid', (
    tester,
  ) async {
    final charges = ValueNotifier([_charge(LaundryChargeStatus.claimed)]);
    await _pumpSheet(tester, charges);
    expect(find.text('Payment successful'), findsNothing);

    charges.value = [_charge(LaundryChargeStatus.paid)];
    await tester.pumpAndSettle();

    expect(find.text('Payment successful'), findsOneWidget);
    expect(find.text('Pending payment'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Cancel voids the charge after confirmation', (tester) async {
    final charges = ValueNotifier([_charge(LaundryChargeStatus.pending)]);
    LaundryCharge? cancelled;
    await _pumpSheet(
      tester,
      charges,
      onCancel: (charge) async => cancelled = charge,
    );

    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel this charge?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel charge'));
    await tester.pumpAndSettle();

    expect(cancelled?.id, 'charge-1');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an open QR sheet keeps refreshing until the charge settles', (
    tester,
  ) async {
    final charges = ValueNotifier([_charge(LaundryChargeStatus.pending)]);
    var refreshes = 0;
    await _pumpSheet(tester, charges, onRefresh: () async => refreshes++);

    await tester.pump(const Duration(seconds: 11));
    expect(refreshes, 2);

    charges.value = [_charge(LaundryChargeStatus.paid)];
    await tester.pump();
    await tester.pump(const Duration(seconds: 11));
    expect(refreshes, 2);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('History groups charges into Pending, Paid and Cancelled', (
    tester,
  ) async {
    // A tall phone, so the whole Home page is laid out.
    tester.view.physicalSize = const Size(1170, 4000);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final nav = LaundryWorkspaceNav();
    addTearDown(nav.dispose);
    final store = CanteenStore(
      user: const CanteenUser(
        id: 'laundry',
        name: 'MEC Laundry',
        email: 'laundry@example.com',
        rollNumber: '',
        department: '',
      ),
      menu: const [],
      orders: const [],
      walletTransactions: const [],
      staffState: const CanteenStaffState(
        mode: CanteenStaffMode.work,
        shopOpen: true,
      ),
      laundryPricePerKg: 40,
      laundryCharges: [
        _charge(LaundryChargeStatus.pending, id: 'a', name: 'Unscanned'),
        _charge(LaundryChargeStatus.claimed, id: 'b', name: 'Scanned'),
        _charge(LaundryChargeStatus.paid, id: 'c', name: 'Settled'),
        _charge(LaundryChargeStatus.cancelled, id: 'd', name: 'Voided'),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: LaundryOperatorHome(
          store: store,
          onExitModule: () {},
          onRefresh: () async {},
          onUpdatePrice: (price) async => price,
          onCreateCharge:
              ({
                required serviceType,
                required name,
                required description,
                required quantity,
                price,
              }) async => throw UnimplementedError(),
          onCancelCharge: (_) async {},
          isMainHome: true,
          nav: nav,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Home lists what is still waiting on a student.
    expect(nav.available, isTrue);
    expect(find.text('Unscanned'), findsOneWidget);
    expect(find.text('Scanned'), findsOneWidget);
    expect(find.text('Settled'), findsNothing);

    nav.show(LaundrySection.history);
    await tester.pumpAndSettle();
    expect(nav.section, LaundrySection.history);
    expect(find.text('Pending'), findsOneWidget);
    // Paid and Cancelled each head a group and label the row inside it.
    expect(find.text('Paid'), findsNWidgets(2));
    expect(find.text('Cancelled'), findsNWidgets(2));
    expect(find.text('Settled'), findsOneWidget);
    expect(find.text('Voided'), findsOneWidget);
  });

  testWidgets('the laundry counter lands on its workspace with History in '
      'place of Modules', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    const session = UserSession(
      email: 'counter@example.com',
      displayName: 'Laundry Counter',
      role: UserRole.staff,
      roleId: 'laundry_operator',
      roleIds: ['laundry_operator'],
      activePortalFamily: PortalFamily.staff,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ModuleDashboardScreen(
          session: session,
          permissions: const EffectivePermissions(
            grants: {'canteen.menu.read', 'canteen.menu.create'},
          ),
          onOpenModule: (id, [action]) {},
          onSignOut: () {},
          onThemeModeChanged: (_) {},
          canteenRepository: MockCanteenRepository(
            studentName: 'Laundry Counter',
            email: 'counter@example.com',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LaundryOperatorHome), findsOneWidget);
    expect(find.text('Create student payment QR'), findsOneWidget);
    expect(find.byType(CampusNavBar), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Modules'), findsNothing);

    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Charge history'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });
}
