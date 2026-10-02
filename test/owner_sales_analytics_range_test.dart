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

/// What the server sends for the range it was asked about: Anu hands over
/// two ₹50 items a day, the owner one ₹20 item, Bala does nothing, and one
/// ₹30 order a day predates the per-item record.
Map<String, dynamic> _payload(
  AnalyticsDateRange range, {
  bool costRecorded = true,
}) {
  final days = range.days;
  final anu = 100.0 * days;
  final owner = 20.0 * days;
  final before = 30.0 * days;
  final total = anu + owner + before;
  double share(double part) => (part / total * 1000).round() / 10;
  return {
    'shop': {'shopKey': 'mec-canteen', 'name': 'Campus Canteen'},
    'range': {
      'from': AnalyticsDateRange.wire(range.from),
      'to': AnalyticsDateRange.wire(range.to),
      'days': days,
    },
    'summary': {
      'orders': days * 3 + 1,
      'completedOrders': days * 3,
      'activeOrders': 1,
      'revenue': total,
      'cost': costRecorded ? total * 0.6 : null,
      'profit': costRecorded ? total * 0.4 : null,
      'marginPercent': costRecorded ? 40.0 : null,
      'uncostedItems': costRecorded ? 0 : 1,
      'averageOrderValue': total / (days * 3),
      'itemsSold': days * 4,
      'activeValue': 50.0,
      'refunded': 0.0,
      'averageHandlingMinutes': 12.0,
      'timedOrders': days * 2,
      'waitingOrders': 1,
    },
    'staffSummary': {
      'trackedRevenue': anu + owner,
      'trackedItems': days * 3,
      'totalRevenue': total,
      'totalItems': days * 4,
      'unattributed': {
        'orders': days,
        'items': days,
        'revenue': before,
        'revenueShare': share(before),
      },
    },
    'captains': [
      {
        'userId': 'cap-anu',
        'name': 'Anu Captain',
        'role': 'captain',
        'assigned': true,
        'itemsDelivered': days * 2,
        'ordersDelivered': days,
        'ordersTouched': days,
        'revenue': anu,
        'cost': costRecorded ? anu * 0.6 : null,
        'profit': costRecorded ? anu * 0.4 : null,
        'uncostedItems': costRecorded ? 0 : 1,
        'revenueShare': share(anu),
        'itemsPrepared': days * 2,
        'rejectedOrders': 0,
        'refunded': 0.0,
        'averagePrepSeconds': 480.0,
        'prepTimedItems': days,
        'averageHandoverSeconds': 250.0,
        'handoverTimedItems': days * 2,
        'firstActivityAt': '2026-09-28T04:00:00Z',
        'lastActivityAt': '2026-09-28T05:30:00Z',
        'activeDays': days,
        'actions': days * 4,
      },
      {
        'userId': 'cap-bala',
        'name': 'Bala Captain',
        'role': 'captain',
        'assigned': true,
        'itemsDelivered': 0,
        'revenue': 0.0,
        'cost': 0.0,
        'profit': 0.0,
        'revenueShare': 0.0,
        'averagePrepSeconds': null,
        'averageHandoverSeconds': null,
        'actions': 0,
      },
      {
        'userId': 'own',
        'name': 'Shop Owner',
        'role': 'owner',
        'assigned': true,
        'itemsDelivered': days,
        'ordersDelivered': days,
        'ordersTouched': days,
        'revenue': owner,
        'cost': owner * 0.6,
        'profit': owner * 0.4,
        'revenueShare': share(owner),
        'averageHandoverSeconds': 60.0,
        'handoverTimedItems': days,
        'actions': days,
        'activeDays': days,
      },
    ],
  };
}

Map<String, dynamic> _activity(int i) => {
  'id': 100 + i,
  'occurredAt': '2026-09-28T0${5 - i}:30:00Z',
  'action': ['delivered', 'ready', 'rejected'][i],
  'source': ['scan', 'item', 'order'][i],
  'orderId': 'anu-order-$i',
  'orderNumber': 50 + i,
  'lineIndex': i == 2 ? null : 0,
  'itemName': i == 2 ? null : 'Masala Dosa $i',
  'quantity': 2,
  'amount': 100.0,
  'countsAsSale': i == 0,
  'order': {
    'id': 'anu-order-$i',
    'orderNumber': 50 + i,
    'customerName': 'Customer $i',
    'status': i == 2 ? 'rejected' : 'completed',
    'total': 100.0,
    'itemCount': 2,
    'createdAt': '2026-09-28T0${5 - i}:00:00Z',
    'fulfilmentMode': 'pickup',
    'captainName': 'Anu Captain, Shop Owner',
    'shopKey': 'mec-canteen',
    'lines': [
      {'itemId': 'dosa', 'name': 'Masala Dosa $i', 'price': 50, 'quantity': 2},
    ],
  },
};

/// What `shop-analytics?captain=cap-anu&page=…` sends: Anu's figures, one
/// point per day of the range and three actions, two to a page.
Map<String, dynamic> _detailPayload(
  AnalyticsDateRange range,
  int page, {
  bool costRecorded = true,
}) {
  final report = _payload(range, costRecorded: costRecorded);
  final anu = Map<String, dynamic>.from(
    (report['captains'] as List).first as Map,
  );
  return {
    ...report,
    'captainDetail': {
      ...anu,
      'email': 'anu@mec.local',
      'daily': [
        for (var i = 0; i < range.days; i++)
          {
            'date': AnalyticsDateRange.wire(range.from.add(Duration(days: i))),
            // Only the last day has activity; the others are real zeros.
            'itemsDelivered': i == range.days - 1 ? 2 : 0,
            'ordersDelivered': i == range.days - 1 ? 1 : 0,
            'revenue': i == range.days - 1 ? 100.0 : 0.0,
            'itemsPrepared': 0,
            'actions': i == range.days - 1 ? 3 : 0,
          },
      ],
      'activity': [
        for (var i = 0; i < 3; i++) _activity(i),
      ].skip((page - 1) * 2).take(2).toList(),
      'page': page,
      'pageSize': 2,
      'totalActivity': 3,
      'totalPages': 2,
    },
  };
}

Future<List<AnalyticsDateRange>> _pump(
  WidgetTester tester, {
  List<(String, AnalyticsDateRange, int)>? detailRequests,
  bool noCaptains = false,
  bool costRecorded = true,
}) async {
  final requests = <AnalyticsDateRange>[];
  // Tall enough that the lazy list builds every captain card.
  tester.view.physicalSize = const Size(900, 2800);
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
            final payload = _payload(range, costRecorded: costRecorded);
            if (noCaptains) payload['captains'] = <Object>[];
            return ShopAnalyticsReport.fromJson(payload, requested: range);
          },
          loadCaptainDetail: (shopKey, captainId, range, page) async {
            expect(shopKey, 'mec-canteen');
            detailRequests?.add((captainId, range, page));
            return CaptainPerformanceDetail.fromJson(
              _detailPayload(range, page, costRecorded: costRecorded),
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

Finder _inPage(Finder finder) => find.descendant(
  of: find.byKey(const ValueKey('captain-page-list')),
  matching: finder,
);

Finder _kpi(String key, String text) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: find.text(text));

Future<void> _scrollTo(WidgetTester tester, Finder target, double delta) =>
    tester.scrollUntilVisible(
      target,
      delta,
      scrollable: _inPage(find.byType(Scrollable)).first,
    );

void main() {
  testWidgets('loads today, then reloads every figure for a new range', (
    tester,
  ) async {
    final requests = await _pump(tester);

    expect(requests.single, AnalyticsDateRange.single(_today));
    expect(find.text('Sales & Profit Analytics'), findsOneWidget);
    expect(find.text('₹150'), findsWidgets);

    // Every assigned captain is listed, idle ones too, and the owner who
    // handed items over has a row of their own.
    expect(find.text('Anu Captain'), findsOneWidget);
    expect(find.text('Bala Captain'), findsOneWidget);
    expect(find.text('Captain · no activity in this range'), findsOneWidget);
    expect(
      find.text('Captain · 2 items handed over · 2 prepared'),
      findsOneWidget,
    );
    expect(find.text('Owner · 1 item handed over'), findsOneWidget);
    expect(
      find.text('Handed over in this range: ₹150 · 4 items'),
      findsOneWidget,
    );

    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    expect(requests.last, AnalyticsDateRange(DateTime(2026, 9, 22), _today));
    expect(find.text('₹1050'), findsWidgets);
    expect(
      find.text('Captain · 14 items handed over · 14 prepared'),
      findsOneWidget,
    );
    expect(find.text('22 Sep 2026 – 28 Sep 2026 · 7 days'), findsOneWidget);

    await tester.tap(find.text('This month'));
    await tester.pumpAndSettle();
    expect(requests.last, AnalyticsDateRange(DateTime(2026, 9), _today));
    expect(find.text('₹4200'), findsWidgets);

    await tester.tap(find.text('30 days'));
    await tester.pumpAndSettle();
    expect(requests.last.days, 30);
  });

  testWidgets('a captain card shows their recorded figures', (tester) async {
    await _pump(tester);
    final card = find.byKey(const ValueKey('captain-cap-anu'));
    Finder inCard(String text) =>
        find.descendant(of: card, matching: find.text(text));
    expect(inCard('AC'), findsOneWidget);
    expect(inCard('₹100'), findsOneWidget);
    // ₹100 of the ₹150 handed over today.
    expect(inCard('66.7%'), findsOneWidget);
    expect(inCard('4 min 10 s'), findsOneWidget);
    expect(inCard('₹40'), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.byType(LinearProgressIndicator)),
      findsOneWidget,
    );
    // The idle captain has nothing timed rather than a made-up time.
    final idle = find.byKey(const ValueKey('captain-cap-bala'));
    expect(find.descendant(of: idle, matching: find.text('—')), findsOneWidget);
  });

  testWidgets('deliveries from before tracking are shown, credited to no one', (
    tester,
  ) async {
    await _pump(tester);
    final card = find.byKey(const ValueKey('unattributed-history'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('Unattributed')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('1 order · 1 item · 20%')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('₹30')),
      findsOneWidget,
    );
  });

  testWidgets('a cost that was never recorded is not guessed', (tester) async {
    final detailRequests = <(String, AnalyticsDateRange, int)>[];
    await _pump(tester, costRecorded: false, detailRequests: detailRequests);

    expect(_kpi('summary-cost', 'Not recorded'), findsOneWidget);
    expect(_kpi('summary-profit', 'Not recorded'), findsOneWidget);
    expect(
      _kpi('summary-profit', '1 item without a cost price'),
      findsOneWidget,
    );
    // Sales are still exact.
    expect(_kpi('summary-sales', '₹150'), findsOneWidget);
    final card = find.byKey(const ValueKey('captain-cap-anu'));
    expect(find.descendant(of: card, matching: find.text('—')), findsOneWidget);

    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(_kpi('kpi-cost', 'Not recorded'), findsOneWidget);
    expect(_kpi('kpi-profit', 'Not recorded'), findsOneWidget);
    expect(_kpi('kpi-revenue', '₹100'), findsOneWidget);
  });

  testWidgets('each captain is a card that opens their own page for the same '
      'range', (tester) async {
    final detailRequests = <(String, AnalyticsDateRange, int)>[];
    final requests = await _pump(tester, detailRequests: detailRequests);
    await tester.tap(find.text('7 days'));
    await tester.pumpAndSettle();
    final week = AnalyticsDateRange(DateTime(2026, 9, 22), _today);

    // Tapping opens a page, not an inline list.
    await tester.tap(find.byKey(const ValueKey('captain-cap-anu')));
    await tester.pumpAndSettle();

    expect(find.byType(CaptainPerformancePage), findsOneWidget);
    expect(detailRequests.single, ('cap-anu', week, 1));
    expect(find.text('anu@mec.local'), findsOneWidget);
    expect(find.text('Captain'), findsWidgets);
    expect(find.text('Campus Canteen'), findsOneWidget);
    expect(find.text('22 Sep 2026 – 28 Sep 2026 · 7 days'), findsOneWidget);

    // Their recorded figures.
    expect(_kpi('kpi-items', '14'), findsOneWidget);
    expect(_kpi('kpi-items', '7 orders'), findsOneWidget);
    expect(_kpi('kpi-revenue', '₹700'), findsOneWidget);
    expect(_kpi('kpi-revenue', '66.7% of the shop'), findsOneWidget);
    expect(_kpi('kpi-prepared', '14'), findsOneWidget);
    expect(_kpi('kpi-touched', '28 actions'), findsOneWidget);
    expect(_kpi('kpi-cost', '₹420'), findsOneWidget);
    expect(_kpi('kpi-profit', '₹280'), findsOneWidget);
    expect(_kpi('kpi-prep-time', '8 min'), findsOneWidget);
    expect(_kpi('kpi-prep-time', '7 items timed'), findsOneWidget);
    expect(_kpi('kpi-handover-time', '4 min 10 s'), findsOneWidget);
    expect(_kpi('kpi-rejected', '0'), findsOneWidget);
    expect(_kpi('kpi-active-days', '7'), findsOneWidget);
    expect(_kpi('kpi-share', '66.7%'), findsOneWidget);

    // The trend is the plain daily sums, idle days included.
    expect(find.text('Daily trend'), findsOneWidget);
    expect(find.text('Per day · total 2'), findsOneWidget);
    await tester.tap(find.text('Revenue').last);
    await tester.pumpAndSettle();
    expect(find.text('Per day · total ₹100'), findsOneWidget);

    // Their actions, a page at a time.
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('captain-activity-more')),
      200,
    );
    expect(find.byKey(const ValueKey('captain-activity-100')), findsOneWidget);
    expect(find.text('Handed over 2 × Masala Dosa 0'), findsOneWidget);
    expect(find.text('Marked 2 × Masala Dosa 1 ready'), findsOneWidget);
    expect(find.byKey(const ValueKey('captain-activity-102')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('captain-activity-more')));
    await tester.pumpAndSettle();
    expect(detailRequests.last, ('cap-anu', week, 2));
    expect(find.byKey(const ValueKey('captain-activity-102')), findsOneWidget);
    expect(find.text('Rejected the order'), findsOneWidget);
    expect(find.text('−₹100'), findsOneWidget);
    expect(find.byKey(const ValueKey('captain-activity-more')), findsNothing);

    // An action opens its order's detail page.
    await tester.tap(find.byKey(const ValueKey('captain-activity-100')));
    await tester.pumpAndSettle();
    expect(find.byType(CanteenOrderDetailPage), findsOneWidget);
    expect(find.text('Order #0050'), findsOneWidget);
    expect(find.text('Masala Dosa 0'), findsOneWidget);
    expect(find.text('Anu Captain, Shop Owner'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // A range picked here is the list's range too.
    await _scrollTo(tester, find.text('Today'), -200);
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
    expect(
      find.text('Captain · 2 items handed over · 2 prepared'),
      findsOneWidget,
    );
  });

  testWidgets('an idle captain\'s page says nothing was recorded', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CaptainPerformancePage(
          captain: const CaptainPerformance(
            userId: 'cap-bala',
            name: 'Bala Captain',
            role: 'captain',
            figures: StaffFigures(),
          ),
          preset: SalesRangePreset.today,
          range: AnalyticsDateRange.single(_today),
          today: _today,
          load: (range, page) async => CaptainPerformanceDetail(
            captain: const CaptainPerformance(
              userId: 'cap-bala',
              name: 'Bala Captain',
              role: 'captain',
              figures: StaffFigures(),
            ),
            range: range,
            daily: [CaptainDailyPoint(date: _today)],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_kpi('kpi-prep-time', 'Not recorded'), findsOneWidget);
    expect(_kpi('kpi-handover-time', 'Not recorded'), findsOneWidget);
    expect(_kpi('kpi-last-active', 'None in range'), findsOneWidget);
    expect(_kpi('kpi-items', '0'), findsOneWidget);
    await _scrollTo(tester, find.text('Nothing recorded in this range.'), 200);
    expect(find.text('Nothing recorded in this range.'), findsOneWidget);
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
  });

  testWidgets(
    'connected without a shop, nothing is rolled up from the device',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OwnerCaptainSalesAnalytics(
              store: _store(
                orders: [
                  CanteenOrder(
                    id: 'x',
                    lines: const [],
                    total: 100,
                    status: CanteenOrderStatus.completed,
                    fulfilmentMode: FulfilmentMode.pickup,
                    createdAt: _today,
                  ),
                ],
              ),
              busy: false,
              onRefresh: () {},
              today: _today,
              loadAnalytics: (shopKey, range) async {
                calls++;
                throw StateError('not called');
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.byKey(const ValueKey('sales-no-shop')), findsOneWidget);
      expect(find.text('₹100'), findsNothing);
    },
  );

  test('a captain\'s detail parses the endpoint payload', () {
    final range = AnalyticsDateRange.lastDays(7, _today);
    final detail = CaptainPerformanceDetail.fromJson(
      _detailPayload(range, 1),
      requested: range,
    );
    expect(detail.captain.name, 'Anu Captain');
    expect(detail.captain.email, 'anu@mec.local');
    expect(detail.captain.figures.itemsDelivered, 14);
    expect(detail.captain.figures.averagePrepSeconds, 480);
    expect(detail.daily, hasLength(7));
    expect(detail.daily.first.date, DateTime(2026, 9, 22));
    expect(detail.daily.first.itemsDelivered, 0);
    expect(detail.daily.last.revenue, 100);
    expect(detail.activity, hasLength(2));
    expect(detail.totalActivity, 3);
    expect(detail.hasMore, isTrue);
    final first = detail.activity.first;
    expect(first.action, CaptainAction.delivered);
    expect(first.source, 'scan');
    expect(first.countsAsSale, isTrue);
    expect(activityTitle(first), 'Handed over 2 × Masala Dosa 0');
    final order = first.order!.toCanteenOrder();
    expect(order.displayId, '0050');
    expect(order.lines.single.item.name, 'Masala Dosa 0');
    expect(order.lines.single.quantity, 2);
    expect(order.captainName, 'Anu Captain, Shop Owner');
    expect(order.status, CanteenOrderStatus.completed);
  });

  test('the report parses the endpoint payload', () {
    final range = AnalyticsDateRange.lastDays(7, _today);
    final report = ShopAnalyticsReport.fromJson(
      _payload(range, costRecorded: false),
      requested: range,
    );
    expect(report.range, range);
    expect(report.staffRecorded, isTrue);
    expect(report.summary.revenue, 1050);
    expect(report.summary.cost, isNull);
    expect(report.summary.profit, isNull);
    expect(report.summary.marginPercent, isNull);
    expect(report.summary.uncostedItems, 1);
    expect(report.summary.averageHandlingMinutes, 12);
    expect(report.summary.waitingOrders, 1);
    expect(report.staff.totalRevenue, 1050);
    expect(report.staff.unattributed.orders, 7);
    expect(report.staff.unattributed.revenueShare, 20);
    expect(report.captains.map((c) => c.name), [
      'Anu Captain',
      'Bala Captain',
      'Shop Owner',
    ]);
    expect(report.captains.first.figures.cost, isNull);
    expect(report.captains[1].figures.idle, isTrue);
    expect(report.captains[1].figures.averageHandoverSeconds, isNull);
    expect(report.captains.last.role, 'owner');
    expect(AnalyticsDateRange.wire(DateTime(2026, 9, 1)), '2026-09-01');
  });

  test('durations read in seconds, minutes or hours', () {
    expect(formatDurationSeconds(null), '—');
    expect(formatDurationSeconds(null, missing: notRecorded), 'Not recorded');
    expect(formatDurationSeconds(42.4), '42 s');
    expect(formatDurationSeconds(250), '4 min 10 s');
    expect(formatDurationSeconds(480), '8 min');
    expect(formatDurationSeconds(3900), '1 h 5 min');
    expect(formatHandlingMinutes(12), '12 min');
  });

  test('offline, the summary uses recorded costs and credits no one', () {
    const dosa = CanteenMenuItem(
      id: 'dosa',
      name: 'Dosa',
      description: '',
      category: 'meals',
      price: 50,
      actualPrice: 30,
      isVegetarian: true,
    );
    const tea = CanteenMenuItem(
      id: 'tea',
      name: 'Tea',
      description: '',
      category: 'drinks',
      price: 10,
      isVegetarian: true,
    );
    CanteenOrder order(
      String id,
      DateTime at,
      CanteenOrderStatus status, {
      List<CartLine> lines = const [CartLine(item: dosa, quantity: 2)],
    }) => CanteenOrder(
      id: id,
      lines: lines,
      total: lines.fold(0, (sum, line) => sum + line.total),
      status: status,
      fulfilmentMode: FulfilmentMode.pickup,
      createdAt: at,
      captainName: 'Anu',
    );
    final costed = localShopAnalytics(
      orders: [
        order('a', DateTime(2026, 9, 28, 9), CanteenOrderStatus.completed),
        order('b', DateTime(2026, 9, 27, 23), CanteenOrderStatus.completed),
        order('c', DateTime(2026, 9, 28, 10), CanteenOrderStatus.rejected),
        order('d', DateTime(2026, 9, 1, 10), CanteenOrderStatus.completed),
      ],
      range: AnalyticsDateRange.lastDays(2, _today),
    );
    expect(costed.staffRecorded, isFalse);
    expect(costed.captains, isEmpty);
    expect(costed.summary.orders, 3);
    expect(costed.summary.revenue, 200);
    expect(costed.summary.cost, 120);
    expect(costed.summary.profit, 80);
    expect(costed.summary.rejectedOrders, 1);
    expect(costed.summary.refunded, 100);
    expect(costed.summary.averageHandlingMinutes, isNull);
    expect(costed.staff.unattributed.orders, 2);

    // Tea has no cost price: the cost is not recorded, not 70% of the price.
    final uncosted = localShopAnalytics(
      orders: [
        order(
          'e',
          DateTime(2026, 9, 28, 9),
          CanteenOrderStatus.completed,
          lines: const [
            CartLine(item: dosa, quantity: 1),
            CartLine(item: tea, quantity: 1),
          ],
        ),
      ],
      range: AnalyticsDateRange.single(_today),
    );
    expect(uncosted.summary.revenue, 60);
    expect(uncosted.summary.cost, isNull);
    expect(uncosted.summary.profit, isNull);
    expect(uncosted.summary.uncostedItems, 1);
  });

  testWidgets('offline, the page says who handled what is not on the device', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OwnerCaptainSalesAnalytics(
            store: _store(),
            busy: false,
            onRefresh: () {},
            today: _today,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Who handled each item is recorded by the campus server; this '
        'device has no such record.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('captains-empty')), findsNothing);
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
}
