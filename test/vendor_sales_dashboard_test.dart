import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/vendor_management/data/vendor_models.dart';
import 'package:supercampus_mobile/src/features/vendor_management/data/vendor_repository.dart';
import 'package:supercampus_mobile/src/features/vendor_management/presentation/vendor_management_shell.dart';

const _admin = UserSession(
  email: 'admin@mec.local',
  displayName: 'MEC Admin',
  role: UserRole.admin,
  roleId: 'tenant_admin',
  roleIds: ['tenant_admin'],
);

Map<String, dynamic> _store(
  String key,
  String name,
  String category, {
  int orders = 0,
  double revenue = 0,
  int share = 0,
  int today = 0,
  double todayRevenue = 0,
  int queue = 0,
  bool open = true,
}) => {
  'id': 'id-$key',
  'shopKey': key,
  'name': name,
  'category': category,
  'isActive': true,
  'isOpen': open,
  'operators': [
    {'name': 'Arun Subramanian', 'role': 'owner'},
    {'name': 'Janani Pillai', 'role': 'captain'},
  ],
  'orders': orders,
  'revenue': revenue,
  'revenueShare': share,
  'ordersToday': today,
  'revenueToday': todayRevenue,
  'activeNow': queue,
};

/// Different, real-looking figures per period so a test can tell which one
/// is on screen.
final _byPeriod = <SalesPeriod, Map<String, dynamic>>{
  SalesPeriod.today: {
    'period': 'today',
    'generatedAt': '2026-09-28T12:07:42',
    'summary': {
      'orders': 5,
      'completedOrders': 3,
      'activeOrders': 1,
      'cancelledOrders': 1,
      'revenue': 450,
      'averageOrderValue': 150,
      'pendingNow': 4,
    },
    'stores': [
      _store('mec-canteen', 'Canteen', 'Canteen',
          orders: 4, revenue: 400, share: 89, today: 4, todayRevenue: 400, queue: 3),
      _store('mec-laundry', 'Campus Laundry', 'Laundry',
          orders: 1, revenue: 50, share: 11, today: 1, todayRevenue: 50, queue: 1,
          open: false),
    ],
    'trend': {
      'unit': 'hour',
      'points': [
        for (var h = 0; h < 24; h++)
          {
            'start': '2026-09-28T${h.toString().padLeft(2, '0')}:00:00',
            'orders': h == 9 ? 3 : 0,
            'completedOrders': h == 9 ? 3 : 0,
            'revenue': h == 9 ? 450 : 0,
            'isFuture': h > 12,
          },
      ],
    },
    'topItems': [
      {'name': 'Masala Dosa', 'shopKey': 'mec-canteen', 'quantity': 6, 'revenue': 360},
    ],
  },
  SalesPeriod.week: {
    'period': 'week',
    'summary': {
      'orders': 62,
      'completedOrders': 45,
      'activeOrders': 6,
      'cancelledOrders': 11,
      'revenue': 1613,
      'averageOrderValue': 35.84,
      'pendingNow': 4,
    },
    'stores': [
      _store('mec-canteen', 'Canteen', 'Canteen', orders: 58, revenue: 1557, share: 97),
      _store('mec-stationery', 'Campus Stationery', 'Stationery',
          orders: 4, revenue: 56, share: 3),
    ],
    'trend': {'unit': 'day', 'points': []},
  },
};

class _FakeRepository implements VendorRepository {
  _FakeRepository({this.empty = false});

  final bool empty;
  final periods = <SalesPeriod>[];
  final orderQueries = <(SalesPeriod, String?, OrderStatusFilter)>[];

  @override
  Future<SalesDashboardData> getSalesDashboard({
    SalesPeriod period = SalesPeriod.today,
  }) async {
    periods.add(period);
    if (empty) return SalesDashboardData(period: period);
    return SalesDashboardData.fromJson(
      _byPeriod[period] ?? {'period': period.key},
    );
  }

  @override
  Future<SalesOrderPage> listSalesOrders({
    SalesPeriod period = SalesPeriod.all,
    String? shopKey,
    OrderStatusFilter status = OrderStatusFilter.all,
    int limit = 100,
  }) async {
    orderQueries.add((period, shopKey, status));
    if (empty) return const SalesOrderPage();
    return SalesOrderPage.fromJson({
      'total': 1,
      'orders': [
        {
          'id': 'o1',
          'kind': 'order',
          'orderNumber': 41,
          'customerName': 'Sneha Raman',
          'shopKey': 'mec-canteen',
          'storeName': 'Canteen',
          'category': 'Canteen',
          'total': 130,
          'status': 'preparing',
          'statusBucket': 'active',
          'fulfilmentMode': 'pickup',
          'tokenNumber': 12,
          'lines': [
            {'name': 'Masala Dosa', 'price': 65, 'quantity': 2},
          ],
          'createdAt': '2026-09-28T06:30:00Z',
        },
      ],
    });
  }

  @override
  Future<List<VendorShop>> listVendors() async => empty
      ? const []
      : const [
          VendorShop(
            id: 'id-mec-canteen',
            shopKey: 'mec-canteen',
            name: 'Canteen',
            category: 'canteen',
            description: 'Main block',
            isActive: true,
            isOpen: true,
          ),
        ];

  @override
  Future<VendorShop> createVendor(VendorShopDraft draft) =>
      throw UnimplementedError();

  @override
  Future<VendorShop> updateVendor(String shopId, VendorShopDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> toggleVendorStatus(VendorShop shop, bool active) =>
      throw UnimplementedError();
}

Future<void> _pump(
  WidgetTester tester,
  VendorRepository repository, {
  EffectivePermissions? permissions,
}) async {
  // A phone: every KPI must fit without sideways scrolling.
  tester.view.physicalSize = const Size(390, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: VendorManagementShell(
        session: _admin,
        onExitModule: () {},
        repository: repository,
        permissions: permissions ?? EffectivePermissions(grants: {'*'}),
        institutionName: 'Madras Engineering College',
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the figures the repository measured', (tester) async {
    final repository = _FakeRepository();
    await _pump(tester, repository);

    expect(repository.periods, [SalesPeriod.today]);
    expect(find.text('Sales Dashboard'), findsOneWidget);
    expect(find.text('Madras Engineering College'), findsOneWidget);
    expect(find.text('5'), findsOneWidget); // orders
    expect(find.text('₹450'), findsWidgets); // revenue
    expect(find.text('₹150'), findsOneWidget); // average order
    expect(find.text('4'), findsWidgets); // pending now
    expect(find.text('Revenue over time'), findsOneWidget);
    expect(find.text('Sales by store'), findsOneWidget);
    expect(find.text('Campus Laundry'), findsWidgets);
    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('Masala Dosa'), findsOneWidget);
    expect(find.text('3 · 60%'), findsOneWidget); // completed of 5
    expect(find.text('1 · 20%'), findsNWidgets(2)); // in progress, cancelled
    expect(find.textContaining('QR Payments'), findsNothing);
    expect(find.textContaining('Exception'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the period control refetches and every figure follows', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pump(tester, repository);

    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();

    expect(repository.periods, [SalesPeriod.today, SalesPeriod.week]);
    expect(find.text('62'), findsOneWidget);
    expect(find.text('₹1,613'), findsOneWidget);
    expect(find.text('₹35.84'), findsOneWidget);
    expect(find.text('45 · 73%'), findsOneWidget);
    expect(find.text('Campus Stationery'), findsWidgets);
    expect(find.textContaining('97% of revenue'), findsOneWidget);
    expect(find.text('₹450'), findsNothing);
  });

  testWidgets('an empty campus reads as zeros and empty states', (
    tester,
  ) async {
    await _pump(tester, _FakeRepository(empty: true));

    expect(find.text('₹0'), findsNWidgets(2));
    expect(find.textContaining('No completed sales today'), findsOneWidget);
    expect(find.text('No shops are set up yet.'), findsNWidgets(2));
    expect(find.text('Top sellers'), findsNothing);

    await tester.tap(find.text('Orders').last);
    await tester.pumpAndSettle();
    expect(find.text('No orders'), findsOneWidget);
  });

  testWidgets('orders list filters and opens the order detail', (
    tester,
  ) async {
    final repository = _FakeRepository();
    await _pump(tester, repository);

    await tester.tap(find.text('Orders').last);
    await tester.pumpAndSettle();
    expect(repository.orderQueries.last, (
      SalesPeriod.week,
      null,
      OrderStatusFilter.all,
    ));
    expect(find.text('Sneha Raman'), findsOneWidget);
    expect(find.text('Preparing'), findsOneWidget);

    await tester.tap(find.text('Completed').last);
    await tester.pumpAndSettle();
    expect(repository.orderQueries.last.$3, OrderStatusFilter.completed);

    await tester.tap(find.text('Sneha Raman'));
    await tester.pumpAndSettle();
    expect(find.text('Order #41'), findsOneWidget);
    expect(find.text('Masala Dosa'), findsOneWidget);
    expect(find.text('₹130'), findsWidgets);
    expect(find.text('Pickup'), findsOneWidget);
  });

  testWidgets('vendors tab lists shops with staff and today\'s sales', (
    tester,
  ) async {
    await _pump(tester, _FakeRepository());

    await tester.tap(find.text('Vendors'));
    await tester.pumpAndSettle();
    expect(find.text('Canteen'), findsWidgets);
    expect(find.textContaining('Arun Subramanian'), findsOneWidget);
    expect(find.textContaining('Today: 4 orders · ₹400'), findsOneWidget);
    expect(find.byTooltip('Add shop'), findsOneWidget);
  });

  testWidgets('a sales reader without the register sees no Vendors tab', (
    tester,
  ) async {
    await _pump(
      tester,
      _FakeRepository(),
      permissions: EffectivePermissions(grants: {'canteen.analytics.read'}),
    );
    expect(find.text('Vendors'), findsNothing);
    expect(
      find.widgetWithText(NavigationDestination, 'Orders'),
      findsOneWidget,
    );
    expect(find.byTooltip('Add shop'), findsNothing);
  });

  testWidgets('no grant at all is a calm no-access page', (tester) async {
    await _pump(
      tester,
      _FakeRepository(),
      permissions: EffectivePermissions(grants: {'fees.records.read'}),
    );
    expect(find.textContaining("don't have access"), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
