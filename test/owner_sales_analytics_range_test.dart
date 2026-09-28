import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/data/shop_analytics.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/widgets/owner_captain_sales_analytics.dart';

final _today = DateTime(2026, 9, 28);

CanteenStore _store({List<CanteenOrder> orders = const []}) => CanteenStore(
  user: const CanteenUser(
    id: 'owner',
    name: 'Shop Owner',
    email: 'owner@mec.local',
    rollNumber: 'Not assigned',
    department: 'Not assigned',
  ),
  menu: const [],
  orders: orders,
  walletTransactions: const [],
);

/// What the server sends for the range it was asked about: the busy captain
/// has more orders the wider the range, the idle one never has any.
Map<String, dynamic> _payload(AnalyticsDateRange range) {
  final orders = range.days;
  final revenue = 100.0 * orders;
  return {
    'shop': {'shopKey': 'mec-canteen', 'name': 'Campus Canteen'},
    'range': {
      'from': AnalyticsDateRange.wire(range.from),
      'to': AnalyticsDateRange.wire(range.to),
      'days': range.days,
    },
    'summary': {
      'orders': orders + 1,
      'completedOrders': orders,
      'activeOrders': 1,
      'revenue': revenue,
      'cost': revenue * 0.6,
      'profit': revenue * 0.4,
      'marginPercent': 40.0,
      'averageOrderValue': 100.0,
      'itemsSold': orders * 2,
      'activeValue': 50.0,
      'refunded': 0.0,
      'averageHandlingMinutes': 12.0,
      'unattributedOrders': 1,
    },
    'captains': [
      {
        'userId': 'cap-anu',
        'name': 'Anu Captain',
        'role': 'captain',
        'assigned': true,
        'orders': orders,
        'completedOrders': orders,
        'rejectedOrders': 0,
        'itemsSold': orders * 2,
        'revenue': revenue,
        'profit': revenue * 0.4,
        'revenueShare': 100.0,
        'averageHandlingMinutes': 12.0,
        'recentOrders': [
          {
            'id': 'o1',
            'orderNumber': 42,
            'customerName': 'Student One',
            'status': 'completed',
            'total': 100.0,
            'profit': 40.0,
            'itemCount': 2,
            'createdAt': '2026-09-28T05:00:00Z',
          },
        ],
      },
      {
        'userId': 'cap-bala',
        'name': 'Bala Captain',
        'role': 'captain',
        'assigned': true,
        'orders': 0,
        'revenue': 0.0,
        'profit': 0.0,
        'revenueShare': 0.0,
        'averageHandlingMinutes': null,
        'recentOrders': <Object>[],
      },
    ],
  };
}

Future<List<AnalyticsDateRange>> _pump(WidgetTester tester) async {
  final requests = <AnalyticsDateRange>[];
  // Tall enough that the lazy list builds every captain card.
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: OwnerCaptainSalesAnalytics(
          store: _store(),
          busy: false,
          onRefresh: () {},
          shopKey: 'mec-canteen',
          shopName: 'Campus Canteen',
          today: _today,
          loadAnalytics: (shopKey, range) async {
            expect(shopKey, 'mec-canteen');
            requests.add(range);
            return ShopAnalyticsReport.fromJson(
              _payload(range),
              requested: range,
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return requests;
}

void main() {
  testWidgets('loads today, then reloads every figure for a new range', (
    tester,
  ) async {
    final requests = await _pump(tester);

    expect(requests.single, AnalyticsDateRange.single(_today));
    expect(find.text('Sales & Profit Analytics'), findsOneWidget);
    expect(find.text('₹100'), findsWidgets);

    // Every assigned captain is listed, including one with no orders.
    expect(find.text('Anu Captain'), findsOneWidget);
    expect(find.text('Bala Captain'), findsOneWidget);
    expect(find.text('Captain · no orders in this range'), findsOneWidget);
    expect(find.text('Captain · 1 orders · 1 delivered'), findsOneWidget);

    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    expect(requests.last, AnalyticsDateRange(DateTime(2026, 9, 22), _today));
    expect(find.text('₹700'), findsWidgets);
    expect(find.text('Captain · 7 orders · 7 delivered'), findsOneWidget);
    expect(
      find.text('22 Sep 2026 – 28 Sep 2026 · 7 days'),
      findsOneWidget,
    );

    await tester.tap(find.text('This month'));
    await tester.pumpAndSettle();
    expect(requests.last, AnalyticsDateRange(DateTime(2026, 9), _today));
    expect(find.text('₹2800'), findsWidgets);

    await tester.tap(find.text('30 days'));
    await tester.pumpAndSettle();
    expect(requests.last.days, 30);

    // A busy captain's recent orders open under their card.
    await tester.tap(find.text('Anu Captain'));
    await tester.pumpAndSettle();
    expect(find.text('Student One'), findsOneWidget);
  });

  testWidgets('a custom range comes from the date range picker', (
    tester,
  ) async {
    final requests = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('sales-range-custom')));
    await tester.pumpAndSettle();
    expect(find.text('Sales range'), findsOneWidget);
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(requests, hasLength(2));
    expect(requests.last, AnalyticsDateRange.single(_today));
    // The chip now names the picked range.
    expect(find.text('28 Sep'), findsOneWidget);
  });

  test('the report parses the endpoint payload', () {
    final range = AnalyticsDateRange.lastDays(7, _today);
    final report = ShopAnalyticsReport.fromJson(
      _payload(range),
      requested: range,
    );
    expect(report.range, range);
    expect(report.summary.revenue, 700);
    expect(report.summary.averageHandlingMinutes, 12);
    expect(report.unattributedOrders, 1);
    expect(report.captains.map((c) => c.name), ['Anu Captain', 'Bala Captain']);
    expect(report.captains.last.figures.orders, 0);
    expect(report.captains.last.figures.averageHandlingMinutes, isNull);
    expect(report.captains.first.recentOrders.single.orderNumber, '42');
    expect(AnalyticsDateRange.wire(DateTime(2026, 9, 1)), '2026-09-01');
  });

  test('offline roll-up keeps only orders inside the range', () {
    const dosa = CanteenMenuItem(
      id: 'dosa',
      name: 'Dosa',
      description: '',
      category: 'meals',
      price: 50,
      actualPrice: 30,
      isVegetarian: true,
    );
    CanteenOrder order(String id, DateTime at, CanteenOrderStatus status) =>
        CanteenOrder(
          id: id,
          lines: const [CartLine(item: dosa, quantity: 2)],
          total: 100,
          status: status,
          fulfilmentMode: FulfilmentMode.pickup,
          createdAt: at,
          captainName: 'Anu',
        );
    final report = localShopAnalytics(
      orders: [
        order('a', DateTime(2026, 9, 28, 9), CanteenOrderStatus.completed),
        order('b', DateTime(2026, 9, 27, 23), CanteenOrderStatus.completed),
        order('c', DateTime(2026, 9, 28, 10), CanteenOrderStatus.rejected),
        order('d', DateTime(2026, 9, 1, 10), CanteenOrderStatus.completed),
      ],
      range: AnalyticsDateRange.lastDays(2, _today),
    );
    expect(report.summary.orders, 3);
    expect(report.summary.revenue, 200);
    expect(report.summary.cost, 120);
    expect(report.summary.profit, 80);
    expect(report.summary.rejectedOrders, 1);
    expect(report.summary.refunded, 100);
    expect(report.captains.single.figures.revenueShare, 100);
  });
}
