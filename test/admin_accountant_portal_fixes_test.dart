import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/core/utils/user_facing_error.dart';
import 'package:supercampus_mobile/src/features/admin_portal/presentation/admin_dashboard_screen.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_owner_home.dart';
import 'package:supercampus_mobile/src/features/vendor_management/data/vendor_models.dart';
import 'package:supercampus_mobile/src/features/vendor_management/data/vendor_repository.dart';
import 'package:supercampus_mobile/src/features/vendor_management/presentation/vendor_management_shell.dart';

/// The accountant exactly as /api/v1/bootstrap describes her: the backend
/// places the role in the admin portal family, but her grants hold nothing
/// administrative.
const accountantSession = UserSession(
  email: 'abhinaya@mec.local',
  displayName: 'Abhinaya',
  role: UserRole.admin,
  roleId: 'accountant',
  roleIds: ['accountant'],
  portalFamilies: [PortalFamily.admin],
  activePortalFamily: PortalFamily.admin,
);

final accountantGrants = EffectivePermissions(
  grants: {
    'canteen.analytics.read',
    'canteen.wallet.read',
    'canteen.wallet.top_up',
    'examination.eligibility.read',
    'fees.records.read',
    'students.directory.read',
    'tuition_fee.invoice.read',
    'vendor_management.contracts.read',
    'vendor_management.payments.read',
    'vendor_management.purchase_orders.read',
  },
);

const adminSession = UserSession(
  email: 'admin@mec.local',
  displayName: 'MEC Admin',
  role: UserRole.admin,
  roleId: 'tenant_admin',
  roleIds: ['tenant_admin'],
);

final adminGrants = EffectivePermissions(grants: {'*'});

Future<void> pumpDashboard(
  WidgetTester tester,
  UserSession session,
  EffectivePermissions permissions,
) async {
  tester.view.physicalSize = const Size(1400, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: AdminDashboardScreen(
        session: session,
        permissions: permissions,
        onOpenModule: (_, [_]) {},
        onSignOut: () {},
        onProfileTap: () {},
        onAlertsTap: () {},
      ),
    ),
  );
  await tester.pump();
}

class _SalesOnlyRepository implements VendorRepository {
  int shopCalls = 0;

  @override
  Future<List<VendorShop>> listVendors() async {
    shopCalls++;
    throw Exception(
      'This session cannot access the requested tenant or resource',
    );
  }

  @override
  Future<SalesDashboardData> getSalesDashboard() async =>
      SalesDashboardData.fromJson({
        'platformOrders': 2,
        'orderStatusDistribution': {
          'completed': 0,
          'cancelled': 0,
          'pending': 100,
          'completedCount': 0,
          'cancelledCount': 0,
          'pendingCount': 2,
        },
        'paymentSplit': {
          'ordersPercentage': 0,
          'adhocPercentage': 0,
          'ordersRevenue': 0,
          'adhocRevenue': 0,
        },
      });

  @override
  Future<VendorShop> createVendor(VendorShopDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> toggleVendorStatus(VendorShop shop, bool active) =>
      throw UnimplementedError();

  @override
  Future<VendorShop> updateVendor(String shopId, VendorShopDraft draft) =>
      throw UnimplementedError();
}

CanteenOrder order(
  String id,
  CanteenOrderStatus status,
  DateTime createdAt, {
  double total = 100,
}) => CanteenOrder(
  id: id,
  lines: const [],
  total: total,
  status: status,
  fulfilmentMode: FulfilmentMode.values.first,
  createdAt: createdAt,
);

void main() {
  group('admin UI follows grants, not the portal family', () {
    testWidgets('an accountant sees no Admin Desk and an ACCOUNTANT badge', (
      tester,
    ) async {
      await pumpDashboard(tester, accountantSession, accountantGrants);

      expect(find.text('ACCOUNTANT'), findsOneWidget);
      expect(find.text('ADMIN'), findsNothing);
      expect(find.text('Admin Desk'), findsNothing);
      expect(find.text('Users & Roles'), findsNothing);
    });

    testWidgets('a tenant admin still gets the full Admin Desk', (
      tester,
    ) async {
      await pumpDashboard(tester, adminSession, adminGrants);

      expect(find.text('ADMIN'), findsOneWidget);
      expect(find.text('Users & Roles'), findsWidgets);
      expect(find.text('Admin Desk'), findsWidgets);
    });
  });

  group('vendor workspace for a sales-only reader', () {
    testWidgets('hides the shop register and names the tenant', (
      tester,
    ) async {
      final repository = _SalesOnlyRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: VendorManagementShell(
            session: accountantSession,
            onExitModule: () {},
            repository: repository,
            permissions: accountantGrants,
            institutionName: 'Madras Engineering College',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(repository.shopCalls, 0, reason: 'no request it would refuse');
      expect(find.text('Vendors'), findsNothing);
      expect(find.textContaining('Superadmin'), findsNothing);
      expect(find.textContaining('Platform-wide'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);
      expect(find.text('Madras Engineering College'), findsOneWidget);
      // Two queued orders are in progress, not cancelled.
      expect(find.text('In progress: 2 (100%)'), findsOneWidget);
      expect(find.text('Cancelled: 0 (0%)'), findsOneWidget);
      expect(find.text('Food Orders (0%): ₹0'), findsOneWidget);
    });
  });

  group('order status breakdown', () {
    test('older servers without counts never file open orders as cancelled',
        () {
      final data = SalesDashboardData.fromJson({
        'platformOrders': 2,
        'orderStatusDistribution': {
          'completed': 0,
          'cancelled': 0,
          'pending': 100,
        },
      });
      final breakdown = OrderStatusBreakdown.of(data);
      expect(breakdown.completed, 0);
      expect(breakdown.cancelled, 0);
      expect(breakdown.active, 2);
    });

    test('missing figures are zero, not invented', () {
      final data = SalesDashboardData.fromJson({'platformOrders': 0});
      expect(OrderStatusBreakdown.of(data).total, 0);
      expect(RevenueSplit.of(data).isEmpty, isTrue);
      expect(RevenueSplit.of(data).foodPercent, 0);
    });
  });

  group('owner KPIs follow the selected store', () {
    test('counts only the orders it is given', () {
      final now = DateTime(2026, 9, 28, 12);
      final analytics = analyticsForOrders([
        order('a', CanteenOrderStatus.pending, now),
        order('b', CanteenOrderStatus.completed, now, total: 40),
        order('c', CanteenOrderStatus.completed, DateTime(2026, 9, 27)),
      ], now: now);
      expect(analytics.ordersToday, 2);
      expect(analytics.revenueToday, 40);
      expect(analytics.pending, 1);

      final empty = analyticsForOrders(const [], now: now);
      expect(empty.ordersToday, 0);
      expect(empty.pending, 0);
    });
  });

  group('user-facing errors', () {
    test('strips Dart prefixes', () {
      expect(userFacingError(Exception('Wallet is empty')), 'Wallet is empty');
      expect(userFacingError(StateError('Try again')), 'Try again');
      expect(
        userFacingError('Exception: Exception: Nested'),
        'Nested',
      );
    });

    test('turns a refused permission into a plain sentence', () {
      final refused = Exception(
        'This session cannot access the requested tenant or resource',
      );
      expect(userFacingError(refused), accessDeniedMessage);
      expect(isAccessDenied(refused), isTrue);
      expect(isAccessDenied(Exception('Network down')), isFalse);
    });

    test('falls back when nothing readable is left', () {
      expect(userFacingError(Exception()), isNotEmpty);
      expect(userFacingError(null, fallback: 'x'), 'x');
    });
  });
}
