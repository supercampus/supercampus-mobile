import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/data/shop_analytics.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/widgets/canteen_order_detail_page.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/widgets/captain_performance_page.dart';
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

/// What `shop-analytics?captain=cap-anu&page=…` sends: Anu's figures, one
/// point per day of the range and three orders, two to a page.
Map<String, dynamic> _detailPayload(AnalyticsDateRange range, int page) {
  final report = _payload(range);
  final anu = Map<String, dynamic>.from(
    (report['captains'] as List).first as Map,
  );
  final orders = [
    for (var i = 0; i < 3; i++)
      {
        'id': 'anu-order-$i',
        'orderNumber': 50 + i,
        'customerName': 'Customer $i',
        'status': i == 2 ? 'rejected' : 'completed',
        'total': 100.0,
        'cost': 60.0,
        'profit': 40.0,
        'itemCount': 2,
        'createdAt': '2026-09-28T0${5 - i}:00:00Z',
        'fulfilmentMode': 'pickup',
        'captainName': 'Anu Captain',
        'shopKey': 'mec-canteen',
        'lines': [
          {
            'itemId': 'dosa',
            'name': 'Masala Dosa $i',
            'price': 50,
            'quantity': 2,
          },
        ],
      },
  ];
  return {
    ...report,
    'captainDetail': {
      ...anu,
      'email': 'anu@mec.local',
      'cost': 60.0 * range.days,
      'cancelledOrders': 0,
      'lastHandledAt': '2026-09-28T05:30:00Z',
      'daily': [
        for (var i = 0; i < range.days; i++)
          {
            'date': AnalyticsDateRange.wire(range.from.add(Duration(days: i))),
            'orders': 1,
            'completedOrders': 1,
            'revenue': 100.0,
            'profit': 40.0,
          },
      ],
      'orders': orders.skip((page - 1) * 2).take(2).toList(),
      'page': page,
      'pageSize': 2,
      'totalOrders': 3,
      'totalPages': 2,
    },
  };
}

Future<List<AnalyticsDateRange>> _pump(
  WidgetTester tester, {
  List<(String, AnalyticsDateRange, int)>? detailRequests,
  bool noCaptains = false,
}) async {
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
            final payload = _payload(range);
            if (noCaptains) payload['captains'] = <Object>[];
            return ShopAnalyticsReport.fromJson(payload, requested: range);
          },
          loadCaptainDetail: (shopKey, captainId, range, page) async {
            expect(shopKey, 'mec-canteen');
            detailRequests?.add((captainId, range, page));
            return CaptainPerformanceDetail.fromJson(
              _detailPayload(range, page),
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
    expect(find.text('22 Sep 2026 – 28 Sep 2026 · 7 days'), findsOneWidget);

    await tester.tap(find.text('This month'));
    await tester.pumpAndSettle();
    expect(requests.last, AnalyticsDateRange(DateTime(2026, 9), _today));
    expect(find.text('₹2800'), findsWidgets);

    await tester.tap(find.text('30 days'));
    await tester.pumpAndSettle();
    expect(requests.last.days, 30);
  });

  testWidgets('each captain is a card that opens their own page for the same '
      'range', (tester) async {
    final detailRequests = <(String, AnalyticsDateRange, int)>[];
    final requests = await _pump(tester, detailRequests: detailRequests);
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    final week = AnalyticsDateRange(DateTime(2026, 9, 22), _today);

    // The card: initials, name, orders, revenue, share bar and time.
    final card = find.byKey(const ValueKey('captain-cap-anu'));
    expect(
      find.descendant(of: card, matching: find.text('AC')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.byType(LinearProgressIndicator)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('12 min')),
      findsOneWidget,
    );
    // Tapping opens a page, not an inline list.
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.byType(CaptainPerformancePage), findsOneWidget);
    expect(detailRequests.single, ('cap-anu', week, 1));
    expect(find.text('anu@mec.local'), findsOneWidget);
    expect(find.text('Captain'), findsWidgets);
    expect(find.text('Campus Canteen'), findsOneWidget);
    expect(find.text('22 Sep 2026 – 28 Sep 2026 · 7 days'), findsOneWidget);
    for (final label in [
      'Orders handled',
      'Completed',
      'Rejected / cancelled',
      'Items',
      'Revenue',
      'Cost',
      'Profit',
      'Share of shop',
      'Avg. time to deliver',
      'Last active',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('Daily trend'), findsOneWidget);
    expect(find.text('Per day'), findsOneWidget);

    // The orders they handled, a page at a time.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('captain-orders-more')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('captain-page-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(
      find.byKey(const ValueKey('captain-order-anu-order-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('captain-order-anu-order-2')),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('captain-orders-more')));
    await tester.pumpAndSettle();
    expect(detailRequests.last, ('cap-anu', week, 2));
    expect(
      find.byKey(const ValueKey('captain-order-anu-order-2')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('captain-orders-more')), findsNothing);

    // An order opens the existing order detail page.
    await tester.tap(find.byKey(const ValueKey('captain-order-anu-order-0')));
    await tester.pumpAndSettle();
    expect(find.byType(CanteenOrderDetailPage), findsOneWidget);
    expect(find.text('Order #0050'), findsOneWidget);
    expect(find.text('Masala Dosa 0'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // A range picked here is the list's range too.
    await tester.scrollUntilVisible(
      find.text('Today'),
      -200,
      scrollable: find
          .descendant(
            of: find.byKey(const ValueKey('captain-page-list')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    expect(detailRequests.last, (
      'cap-anu',
      AnalyticsDateRange.single(_today),
      1,
    ));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(CaptainPerformancePage), findsNothing);
    expect(requests.last, AnalyticsDateRange.single(_today));
    expect(find.text('Captain · 1 orders · 1 delivered'), findsOneWidget);
  });

  testWidgets('with nobody assigned the list says how to add captains', (
    tester,
  ) async {
    await _pump(tester, noCaptains: true);
    expect(find.byKey(const ValueKey('captains-empty')), findsOneWidget);
    expect(
      find.text(
        'No captains are assigned to this shop yet — the admin can add them '
        'in Vendors & shops → Counter staff.',
      ),
      findsOneWidget,
    );
    expect(find.text('No captains yet'), findsNothing);
  });

  test('a captain\'s detail parses the endpoint payload', () {
    final range = AnalyticsDateRange.lastDays(7, _today);
    final detail = CaptainPerformanceDetail.fromJson(
      _detailPayload(range, 1),
      requested: range,
    );
    expect(detail.captain.name, 'Anu Captain');
    expect(detail.captain.email, 'anu@mec.local');
    expect(detail.daily, hasLength(7));
    expect(detail.daily.first.date, DateTime(2026, 9, 22));
    expect(detail.orders, hasLength(2));
    expect(detail.hasMore, isTrue);
    final order = detail.orders.first.toCanteenOrder();
    expect(order.displayId, '0050');
    expect(order.lines.single.item.name, 'Masala Dosa 0');
    expect(order.lines.single.quantity, 2);
    expect(order.captainName, 'Anu Captain');
    expect(order.status, CanteenOrderStatus.completed);
  });

  test('offline, a captain\'s detail is rolled up from the orders', () {
    CanteenOrder order(String id, DateTime at, String captain) => CanteenOrder(
      id: id,
      lines: const [],
      total: 100,
      status: CanteenOrderStatus.completed,
      fulfilmentMode: FulfilmentMode.pickup,
      createdAt: at,
      captainName: captain,
    );
    final detail = localCaptainDetail(
      orders: [
        order('a', DateTime(2026, 9, 28, 9), 'Anu'),
        order('b', DateTime(2026, 9, 26, 9), 'Anu'),
        order('c', DateTime(2026, 9, 28, 9), 'Bala'),
      ],
      range: AnalyticsDateRange.lastDays(3, _today),
      captainId: 'Anu',
      pageSize: 1,
    );
    expect(detail.totalOrders, 2);
    expect(detail.totalPages, 2);
    expect(detail.orders.single.id, 'a');
    expect(detail.daily.map((d) => d.orders), [1, 0, 1]);
    expect(detail.captain.figures.revenueShare, closeTo(66.7, 0.1));
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
