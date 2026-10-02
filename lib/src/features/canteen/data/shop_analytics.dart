/// One shop's sales, cost, profit and counter-staff performance over a date
/// range, as `GET /api/v1/operations/canteen/shop-analytics` reports them.
///
/// Every figure is derived from what was recorded; a figure that cannot be
/// derived is null and shown as "not recorded" — never estimated.
///
/// * The shop summary covers orders placed in the range. Revenue is completed
///   orders only; rejected orders are refunded and cancelled ones never
///   charged. Cost is each item's recorded cost price; when an item has none,
///   cost and profit are not recorded.
/// * Staff figures come from the counter's per-item record: each item is
///   credited to whoever prepared it or handed it over, when they did it.
///   Every captain assigned to the shop is listed, idle ones included.
///   Orders completed before that record existed are reported separately as
///   unattributed rather than credited to anyone.
library;

import 'canteen_models.dart';

/// An inclusive range of calendar days (times are ignored).
class AnalyticsDateRange {
  AnalyticsDateRange(DateTime from, DateTime to)
    : from = _day(from.isAfter(to) ? to : from),
      to = _day(from.isAfter(to) ? from : to);

  /// Just [day].
  factory AnalyticsDateRange.single(DateTime day) =>
      AnalyticsDateRange(day, day);

  /// The [days] days ending with [today], today included.
  factory AnalyticsDateRange.lastDays(int days, DateTime today) =>
      AnalyticsDateRange(today.subtract(Duration(days: days - 1)), today);

  /// The first of [today]'s month through [today].
  factory AnalyticsDateRange.monthToDate(DateTime today) =>
      AnalyticsDateRange(DateTime(today.year, today.month), today);

  final DateTime from;
  final DateTime to;

  int get days => to.difference(from).inDays + 1;

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// `yyyy-mm-dd`, as the API takes it.
  static String wire(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is AnalyticsDateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

/// The shop's orders placed in the range.
class ShopSalesFigures {
  const ShopSalesFigures({
    this.orders = 0,
    this.completedOrders = 0,
    this.activeOrders = 0,
    this.rejectedOrders = 0,
    this.cancelledOrders = 0,
    this.itemsSold = 0,
    this.revenue = 0,
    this.cost,
    this.profit,
    this.marginPercent,
    this.uncostedItems = 0,
    this.averageOrderValue = 0,
    this.activeValue = 0,
    this.refunded = 0,
    this.averageHandlingMinutes,
    this.timedOrders = 0,
    this.waitingOrders = 0,
  });

  factory ShopSalesFigures.fromJson(Map<String, dynamic> json) =>
      ShopSalesFigures(
        orders: _int(json['orders']),
        completedOrders: _int(json['completedOrders']),
        activeOrders: _int(json['activeOrders']),
        rejectedOrders: _int(json['rejectedOrders']),
        cancelledOrders: _int(json['cancelledOrders']),
        itemsSold: _int(json['itemsSold']),
        revenue: _double(json['revenue']),
        cost: _maybeDouble(json['cost']),
        profit: _maybeDouble(json['profit']),
        marginPercent: _maybeDouble(json['marginPercent']),
        uncostedItems: _int(json['uncostedItems']),
        averageOrderValue: _double(json['averageOrderValue']),
        activeValue: _double(json['activeValue']),
        refunded: _double(json['refunded']),
        averageHandlingMinutes: _maybeDouble(json['averageHandlingMinutes']),
        timedOrders: _int(json['timedOrders']),
        waitingOrders: _int(
          json['waitingOrders'] ?? json['unattributedOrders'],
        ),
      );

  final int orders;
  final int completedOrders;
  final int activeOrders;
  final int rejectedOrders;
  final int cancelledOrders;
  final int itemsSold;

  /// Completed sales only.
  final double revenue;

  /// What the sold items cost; null when an item has no recorded cost price.
  final double? cost;
  final double? profit;
  final double? marginPercent;

  /// Sold items without a recorded cost price.
  final int uncostedItems;
  final double averageOrderValue;

  /// Value of orders still in the queue.
  final double activeValue;

  /// Value of rejected (refunded) orders.
  final double refunded;

  /// Placement to the last item's recorded hand-over, over [timedOrders]
  /// completed orders; null without any.
  final double? averageHandlingMinutes;
  final int timedOrders;

  /// Orders in the queue nobody has picked up yet.
  final int waitingOrders;
}

/// What one person did at the counter in the range.
class StaffFigures {
  const StaffFigures({
    this.itemsDelivered = 0,
    this.ordersDelivered = 0,
    this.ordersTouched = 0,
    this.revenue = 0,
    this.cost = 0,
    this.profit = 0,
    this.uncostedItems = 0,
    this.revenueShare = 0,
    this.itemsPrepared = 0,
    this.rejectedOrders = 0,
    this.refunded = 0,
    this.averagePrepSeconds,
    this.prepTimedItems = 0,
    this.averageHandoverSeconds,
    this.handoverTimedItems = 0,
    this.firstActivityAt,
    this.lastActivityAt,
    this.activeDays = 0,
    this.actions = 0,
  });

  factory StaffFigures.fromJson(Map<String, dynamic> json) => StaffFigures(
    itemsDelivered: _int(json['itemsDelivered']),
    ordersDelivered: _int(json['ordersDelivered']),
    ordersTouched: _int(json['ordersTouched']),
    revenue: _double(json['revenue']),
    cost: _maybeDouble(json['cost']),
    profit: _maybeDouble(json['profit']),
    uncostedItems: _int(json['uncostedItems']),
    revenueShare: _double(json['revenueShare']),
    itemsPrepared: _int(json['itemsPrepared']),
    rejectedOrders: _int(json['rejectedOrders']),
    refunded: _double(json['refunded']),
    averagePrepSeconds: _maybeDouble(json['averagePrepSeconds']),
    prepTimedItems: _int(json['prepTimedItems']),
    averageHandoverSeconds: _maybeDouble(json['averageHandoverSeconds']),
    handoverTimedItems: _int(json['handoverTimedItems']),
    firstActivityAt: _time(json['firstActivityAt']),
    lastActivityAt: _time(json['lastActivityAt']),
    activeDays: _int(json['activeDays']),
    actions: _int(json['actions']),
  );

  /// Items they handed over (orders since refunded excluded).
  final int itemsDelivered;

  /// Orders they handed over at least one item of.
  final int ordersDelivered;

  /// Orders they moved at all.
  final int ordersTouched;

  /// The line totals of the items they handed over.
  final double revenue;

  /// What those items cost; null when one has no recorded cost price.
  final double? cost;
  final double? profit;
  final int uncostedItems;

  /// Their share of everything delivered in the range, 0–100.
  final double revenueShare;

  /// Items they moved to preparing or ready.
  final int itemsPrepared;
  final int rejectedOrders;
  final double refunded;

  /// Preparing → ready, over [prepTimedItems] items they marked ready.
  final double? averagePrepSeconds;
  final int prepTimedItems;

  /// Ready (or, for instant items, placed) → handed over, over
  /// [handoverTimedItems] items they handed over.
  final double? averageHandoverSeconds;
  final int handoverTimedItems;
  final DateTime? firstActivityAt;
  final DateTime? lastActivityAt;
  final int activeDays;

  /// Every recorded action of theirs in the range.
  final int actions;

  bool get idle => actions == 0;
}

/// An order as the analytics endpoint sends it with an action, in the shape
/// the order detail page takes.
class ShopAnalyticsOrder {
  const ShopAnalyticsOrder({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.status,
    required this.total,
    required this.itemCount,
    required this.createdAt,
    this.lines = const [],
    this.fulfilmentMode = FulfilmentMode.pickup,
    this.tokenNumber,
    this.captainName,
    this.shopKey,
  });

  factory ShopAnalyticsOrder.fromJson(Map<String, dynamic> json) =>
      ShopAnalyticsOrder(
        id: '${json['id'] ?? ''}',
        orderNumber: '${json['orderNumber'] ?? ''}',
        customerName: '${json['customerName'] ?? ''}',
        status: '${json['status'] ?? ''}',
        total: _double(json['total']),
        itemCount: _int(json['itemCount']),
        createdAt:
            _time(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
        lines: _list(json['lines'])
            .map((value) => _line(_map(value), '${json['shopKey'] ?? ''}'))
            .toList(growable: false),
        fulfilmentMode: json['fulfilmentMode'] == 'dine_in'
            ? FulfilmentMode.dineIn
            : FulfilmentMode.pickup,
        tokenNumber: json['tokenNumber'] == null
            ? null
            : _int(json['tokenNumber']),
        captainName: json['captainName'] is String
            ? json['captainName'] as String
            : null,
        shopKey: json['shopKey'] is String ? json['shopKey'] as String : null,
      );

  final String id;
  final String orderNumber;
  final String customerName;

  /// The API's status value (`completed`, `rejected`, `preparing`, …).
  final String status;
  final double total;
  final int itemCount;
  final DateTime createdAt;
  final List<CartLine> lines;
  final FulfilmentMode fulfilmentMode;
  final int? tokenNumber;

  /// Everyone recorded acting on the order.
  final String? captainName;
  final String? shopKey;

  CanteenOrderStatus get orderStatus => CanteenOrderStatus.values.firstWhere(
    (value) => value.apiValue == status,
    orElse: () => CanteenOrderStatus.pending,
  );

  /// The order as the order detail page shows it.
  CanteenOrder toCanteenOrder() => CanteenOrder(
    id: id,
    lines: lines,
    total: total,
    status: orderStatus,
    fulfilmentMode: fulfilmentMode,
    createdAt: createdAt,
    tokenNumber: tokenNumber,
    orderNumber: orderNumber,
    customerName: customerName.isEmpty ? null : customerName,
    captainName: captainName,
    shopKey: shopKey,
  );
}

/// One line of an order as the analytics endpoint echoes it from the order.
CartLine _line(Map<String, dynamic> json, String shopKey) {
  final status = '${json['status'] ?? ''}';
  return CartLine(
    item: CanteenMenuItem(
      id: '${json['itemId'] ?? ''}',
      name: '${json['name'] ?? 'Menu item'}',
      description: '',
      category: '${json['category'] ?? 'meals'}',
      price: _double(json['price']),
      isVegetarian: json['isVegetarian'] != false,
      isInstant: json['isInstant'] == true,
      shopKey: shopKey.isEmpty ? null : shopKey,
    ),
    quantity: json['quantity'] == null ? 1 : _int(json['quantity']),
    status: status.isEmpty
        ? null
        : CanteenOrderStatus.values
              .where((value) => value.apiValue == status)
              .firstOrNull,
  );
}

/// A captain (or anyone else who acted at the counter) and their figures.
class CaptainPerformance {
  const CaptainPerformance({
    required this.userId,
    required this.name,
    required this.figures,
    this.email,
    this.role,
    this.assigned = true,
    this.lastSeenAt,
  });

  factory CaptainPerformance.fromJson(Map<String, dynamic> json) =>
      CaptainPerformance(
        userId: '${json['userId'] ?? ''}',
        name: '${json['name'] ?? 'Staff member'}',
        email: json['email'] is String ? json['email'] as String : null,
        role: json['role'] is String ? json['role'] as String : null,
        assigned: json['assigned'] != false,
        lastSeenAt: _time(json['lastSeenAt']),
        figures: StaffFigures.fromJson(json),
      );

  final String userId;
  final String name;
  final String? email;

  /// The shop assignment (`captain`, `owner`); null when not assigned.
  final String? role;
  final bool assigned;

  /// When they last signed in, when the server knows.
  final DateTime? lastSeenAt;
  final StaffFigures figures;
}

/// Completed orders whose items nobody is recorded handing over: they
/// predate the counter's per-item record, so they are credited to no one.
class UnattributedHistory {
  const UnattributedHistory({
    this.orders = 0,
    this.items = 0,
    this.revenue = 0,
    this.revenueShare = 0,
  });

  factory UnattributedHistory.fromJson(Map<String, dynamic> json) =>
      UnattributedHistory(
        orders: _int(json['orders']),
        items: _int(json['items']),
        revenue: _double(json['revenue']),
        revenueShare: _double(json['revenueShare']),
      );

  final int orders;
  final int items;
  final double revenue;
  final double revenueShare;
}

/// Everything delivered in the range, as the staff figures divide it.
class StaffSummary {
  const StaffSummary({
    this.trackedRevenue = 0,
    this.trackedItems = 0,
    this.totalRevenue = 0,
    this.totalItems = 0,
    this.unattributed = const UnattributedHistory(),
  });

  factory StaffSummary.fromJson(Map<String, dynamic> json) => StaffSummary(
    trackedRevenue: _double(json['trackedRevenue']),
    trackedItems: _int(json['trackedItems']),
    totalRevenue: _double(json['totalRevenue']),
    totalItems: _int(json['totalItems']),
    unattributed: UnattributedHistory.fromJson(_map(json['unattributed'])),
  );

  /// Delivered by someone on record.
  final double trackedRevenue;
  final int trackedItems;

  /// Including [unattributed]; the base of every share.
  final double totalRevenue;
  final int totalItems;
  final UnattributedHistory unattributed;
}

class ShopAnalyticsReport {
  const ShopAnalyticsReport({
    required this.shopKey,
    required this.shopName,
    required this.range,
    required this.summary,
    this.staff = const StaffSummary(),
    this.captains = const [],
    this.staffRecorded = true,
  });

  factory ShopAnalyticsReport.fromJson(
    Map<String, dynamic> json, {
    required AnalyticsDateRange requested,
  }) {
    final shop = _map(json['shop']);
    final range = _map(json['range']);
    final from = DateTime.tryParse('${range['from'] ?? ''}');
    final to = DateTime.tryParse('${range['to'] ?? ''}');
    return ShopAnalyticsReport(
      shopKey: '${shop['shopKey'] ?? ''}',
      shopName: '${shop['name'] ?? ''}',
      range: from != null && to != null
          ? AnalyticsDateRange(from, to)
          : requested,
      summary: ShopSalesFigures.fromJson(_map(json['summary'])),
      staff: StaffSummary.fromJson(_map(json['staffSummary'])),
      captains: _list(json['captains'])
          .map((value) => CaptainPerformance.fromJson(_map(value)))
          .toList(growable: false),
    );
  }

  final String shopKey;
  final String shopName;
  final AnalyticsDateRange range;
  final ShopSalesFigures summary;
  final StaffSummary staff;
  final List<CaptainPerformance> captains;

  /// False when the figures come from orders on the device, which carry no
  /// record of who handled which item.
  final bool staffRecorded;
}

/// One day of a staff member's range: exactly what they recorded that day.
class CaptainDailyPoint {
  const CaptainDailyPoint({
    required this.date,
    this.itemsDelivered = 0,
    this.ordersDelivered = 0,
    this.revenue = 0,
    this.itemsPrepared = 0,
    this.actions = 0,
  });

  factory CaptainDailyPoint.fromJson(Map<String, dynamic> json) {
    final date = DateTime.tryParse('${json['date'] ?? ''}');
    return CaptainDailyPoint(
      date: date == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime(date.year, date.month, date.day),
      itemsDelivered: _int(json['itemsDelivered']),
      ordersDelivered: _int(json['ordersDelivered']),
      revenue: _double(json['revenue']),
      itemsPrepared: _int(json['itemsPrepared']),
      actions: _int(json['actions']),
    );
  }

  final DateTime date;
  final int itemsDelivered;
  final int ordersDelivered;
  final double revenue;
  final int itemsPrepared;
  final int actions;
}

/// What a recorded action did.
enum CaptainAction {
  accepted,
  preparing,
  ready,
  delivered,
  rejected,
  cancelled;

  static CaptainAction? parse(Object? value) =>
      CaptainAction.values.where((action) => action.name == value).firstOrNull;
}

/// One recorded action of a staff member: an item moved, or a whole order
/// accepted or rejected.
class CaptainActivity {
  const CaptainActivity({
    required this.id,
    required this.occurredAt,
    required this.action,
    required this.orderId,
    this.source = 'item',
    this.orderNumber,
    this.lineIndex,
    this.itemName,
    this.quantity = 0,
    this.amount = 0,
    this.countsAsSale = false,
    this.order,
  });

  factory CaptainActivity.fromJson(Map<String, dynamic> json) {
    final order = json['order'];
    return CaptainActivity(
      id: '${json['id'] ?? ''}',
      occurredAt:
          _time(json['occurredAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      action: CaptainAction.parse(json['action']) ?? CaptainAction.accepted,
      source: '${json['source'] ?? 'item'}',
      orderId: '${json['orderId'] ?? ''}',
      orderNumber: json['orderNumber'] == null
          ? null
          : '${json['orderNumber']}',
      lineIndex: json['lineIndex'] == null ? null : _int(json['lineIndex']),
      itemName: json['itemName'] is String ? json['itemName'] as String : null,
      quantity: _int(json['quantity']),
      amount: _double(json['amount']),
      countsAsSale: json['countsAsSale'] == true,
      order: order is Map
          ? ShopAnalyticsOrder.fromJson(Map<String, dynamic>.from(order))
          : null,
    );
  }

  final String id;
  final DateTime occurredAt;
  final CaptainAction action;

  /// `item` (one item swiped), `order` (the whole order) or `scan`.
  final String source;
  final String orderId;
  final String? orderNumber;

  /// The item's position in the order; null for whole-order actions.
  final int? lineIndex;
  final String? itemName;
  final int quantity;

  /// The item's line total, or the refunded total of a rejection.
  final double amount;

  /// A hand-over that is still a sale (its order was not refunded since).
  final bool countsAsSale;
  final ShopAnalyticsOrder? order;
}

/// One staff member over a range: their figures, a day-by-day series and a
/// page of their actions, newest first.
class CaptainPerformanceDetail {
  const CaptainPerformanceDetail({
    required this.captain,
    required this.range,
    this.daily = const [],
    this.activity = const [],
    this.page = 1,
    this.pageSize = 20,
    this.totalActivity = 0,
    this.totalPages = 1,
  });

  /// Reads `captainDetail` from a `shop-analytics?captain=…` response.
  factory CaptainPerformanceDetail.fromJson(
    Map<String, dynamic> json, {
    required AnalyticsDateRange requested,
  }) {
    final detail = _map(json['captainDetail']);
    final range = _map(json['range']);
    final from = DateTime.tryParse('${range['from'] ?? ''}');
    final to = DateTime.tryParse('${range['to'] ?? ''}');
    return CaptainPerformanceDetail(
      captain: CaptainPerformance.fromJson(detail),
      range: from != null && to != null
          ? AnalyticsDateRange(from, to)
          : requested,
      daily: _list(detail['daily'])
          .map((value) => CaptainDailyPoint.fromJson(_map(value)))
          .toList(growable: false),
      activity: _list(detail['activity'])
          .map((value) => CaptainActivity.fromJson(_map(value)))
          .toList(growable: false),
      page: detail['page'] == null ? 1 : _int(detail['page']),
      pageSize: detail['pageSize'] == null ? 20 : _int(detail['pageSize']),
      totalActivity: _int(detail['totalActivity']),
      totalPages: detail['totalPages'] == null ? 1 : _int(detail['totalPages']),
    );
  }

  final CaptainPerformance captain;
  final AnalyticsDateRange range;
  final List<CaptainDailyPoint> daily;
  final List<CaptainActivity> activity;
  final int page;
  final int pageSize;
  final int totalActivity;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

/// The shop summary rolled up from orders already on the device, for
/// repositories without the analytics endpoint (the offline demo). Orders on
/// the device carry no record of who handled which item, so no one is
/// credited with anything: [ShopAnalyticsReport.staffRecorded] is false and
/// every delivered order counts as unattributed.
ShopAnalyticsReport localShopAnalytics({
  required List<CanteenOrder> orders,
  required AnalyticsDateRange range,
  String shopKey = '',
  String shopName = '',
}) {
  bool inRange(DateTime at) {
    final day = DateTime(at.year, at.month, at.day);
    return !day.isBefore(range.from) && !day.isAfter(range.to);
  }

  var revenue = 0.0, cost = 0.0, activeValue = 0.0, refunded = 0.0;
  var completed = 0, active = 0, rejected = 0, cancelled = 0, items = 0;
  var uncosted = 0, total = 0;
  for (final order in orders.where((o) => inRange(o.createdAt.toLocal()))) {
    total++;
    switch (order.status) {
      case CanteenOrderStatus.completed:
        completed++;
        revenue += order.total;
        items += order.itemCount;
        if (order.lines.isEmpty) uncosted++;
        for (final line in order.lines) {
          final lineCost = line.recordedCostTotal;
          if (lineCost == null) {
            uncosted += line.quantity;
          } else {
            cost += lineCost;
          }
        }
      case CanteenOrderStatus.rejected:
        rejected++;
        refunded += order.total;
      case CanteenOrderStatus.cancelled:
        cancelled++;
      default:
        active++;
        activeValue += order.total;
    }
  }
  final costed = uncosted == 0;
  final profit = revenue - cost;
  return ShopAnalyticsReport(
    shopKey: shopKey,
    shopName: shopName,
    range: range,
    staffRecorded: false,
    summary: ShopSalesFigures(
      orders: total,
      completedOrders: completed,
      activeOrders: active,
      rejectedOrders: rejected,
      cancelledOrders: cancelled,
      itemsSold: items,
      revenue: revenue,
      cost: costed ? cost : null,
      profit: costed ? profit : null,
      marginPercent: costed && revenue > 0 ? profit / revenue * 100 : null,
      uncostedItems: uncosted,
      averageOrderValue: completed > 0 ? revenue / completed : 0,
      activeValue: activeValue,
      refunded: refunded,
    ),
    staff: StaffSummary(
      totalRevenue: revenue,
      totalItems: items,
      unattributed: UnattributedHistory(
        orders: completed,
        items: items,
        revenue: revenue,
        revenueShare: revenue > 0 ? 100 : 0,
      ),
    ),
  );
}

/// Loads [ShopAnalyticsReport]s. Failures throw a `CanteenException`.
abstract interface class ShopAnalyticsRepository {
  Future<ShopAnalyticsReport> loadShopAnalytics({
    required String shopKey,
    required AnalyticsDateRange range,
  });

  /// One staff member's figures, daily series and a page of their actions.
  Future<CaptainPerformanceDetail> loadCaptainPerformance({
    required String shopKey,
    required String captainId,
    required AnalyticsDateRange range,
    int page = 1,
    int pageSize = 20,
  });
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<dynamic> _list(Object? value) => value is List ? value : const [];

DateTime? _time(Object? value) =>
    value == null ? null : DateTime.tryParse('$value')?.toLocal();

double _double(Object? value) => _maybeDouble(value) ?? 0;

double? _maybeDouble(Object? value) => switch (value) {
  final num number => number.toDouble(),
  final String text => double.tryParse(text),
  _ => null,
};

int _int(Object? value) => switch (value) {
  final num number => number.round(),
  final String text => int.tryParse(text) ?? 0,
  _ => 0,
};
