/// One shop's sales, cost, profit and counter-staff performance over a date
/// range, as `GET /api/v1/operations/canteen/shop-analytics` reports them.
///
/// Revenue is completed orders only; rejected orders are refunded and
/// cancelled ones never charged. Staff figures credit whoever last moved an
/// order at the counter, and every captain assigned to the shop is listed,
/// idle ones included.
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

/// Figures shared by the shop summary and each staff member.
class ShopSalesFigures {
  const ShopSalesFigures({
    this.orders = 0,
    this.completedOrders = 0,
    this.activeOrders = 0,
    this.rejectedOrders = 0,
    this.cancelledOrders = 0,
    this.itemsSold = 0,
    this.revenue = 0,
    this.cost = 0,
    this.profit = 0,
    this.marginPercent = 0,
    this.averageOrderValue = 0,
    this.activeValue = 0,
    this.refunded = 0,
    this.revenueShare = 0,
    this.averageHandlingMinutes,
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
        cost: _double(json['cost']),
        profit: _double(json['profit']),
        marginPercent: _double(json['marginPercent']),
        averageOrderValue: _double(json['averageOrderValue']),
        activeValue: _double(json['activeValue']),
        refunded: _double(json['refunded']),
        revenueShare: _double(json['revenueShare']),
        averageHandlingMinutes: json['averageHandlingMinutes'] == null
            ? null
            : _double(json['averageHandlingMinutes']),
      );

  final int orders;
  final int completedOrders;
  final int activeOrders;
  final int rejectedOrders;
  final int cancelledOrders;
  final int itemsSold;

  /// Completed sales only.
  final double revenue;
  final double cost;
  final double profit;
  final double marginPercent;
  final double averageOrderValue;

  /// Value of orders still in the queue.
  final double activeValue;

  /// Value of rejected (refunded) orders.
  final double refunded;

  /// Share of the shop's revenue, 0–100.
  final double revenueShare;

  /// Placement to hand-over, averaged over completed orders; null without any.
  final double? averageHandlingMinutes;
}

class ShopAnalyticsOrder {
  const ShopAnalyticsOrder({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.status,
    required this.total,
    required this.profit,
    required this.itemCount,
    required this.createdAt,
    this.cost,
    this.updatedAt,
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
        profit: _double(json['profit']),
        cost: json['cost'] == null ? null : _double(json['cost']),
        itemCount: _int(json['itemCount']),
        createdAt:
            DateTime.tryParse('${json['createdAt'] ?? ''}')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}')?.toLocal(),
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

  /// [order] as a staff member's detail lists it.
  factory ShopAnalyticsOrder.fromOrder(CanteenOrder order) =>
      ShopAnalyticsOrder(
        id: order.id,
        orderNumber: order.orderNumber ?? order.displayId,
        customerName: order.customerName ?? '',
        status: order.status.apiValue,
        total: order.total,
        profit: order.totalProfit,
        cost: order.totalCost,
        itemCount: order.itemCount,
        createdAt: order.createdAt,
        lines: order.lines,
        fulfilmentMode: order.fulfilmentMode,
        tokenNumber: order.tokenNumber,
        captainName: order.captainName,
        shopKey: order.shopKey,
      );

  final String id;
  final String orderNumber;
  final String customerName;

  /// The API's status value (`completed`, `rejected`, `preparing`, …).
  final String status;
  final double total;
  final double profit;

  /// What the order's items cost the shop; null when the source leaves it out.
  final double? cost;
  final int itemCount;
  final DateTime createdAt;

  /// When it last moved; for a delivered order, when it was handed over.
  final DateTime? updatedAt;

  /// The items, when the source sends them (a staff member's detail does).
  final List<CartLine> lines;
  final FulfilmentMode fulfilmentMode;
  final int? tokenNumber;
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
      cost: json['cost'] == null ? null : _double(json['cost']),
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

/// A captain (or anyone else who handled orders) and their range figures.
class CaptainPerformance {
  const CaptainPerformance({
    required this.userId,
    required this.name,
    required this.figures,
    this.email,
    this.role,
    this.assigned = true,
    this.lastHandledAt,
    this.lastSeenAt,
    this.recentOrders = const [],
  });

  factory CaptainPerformance.fromJson(Map<String, dynamic> json) =>
      CaptainPerformance(
        userId: '${json['userId'] ?? ''}',
        name: '${json['name'] ?? 'Staff member'}',
        email: json['email'] is String ? json['email'] as String : null,
        role: json['role'] is String ? json['role'] as String : null,
        assigned: json['assigned'] != false,
        lastHandledAt: DateTime.tryParse(
          '${json['lastHandledAt'] ?? ''}',
        )?.toLocal(),
        lastSeenAt: DateTime.tryParse('${json['lastSeenAt'] ?? ''}')?.toLocal(),
        figures: ShopSalesFigures.fromJson(json),
        recentOrders: _list(json['recentOrders'])
            .map((value) => ShopAnalyticsOrder.fromJson(_map(value)))
            .toList(growable: false),
      );

  final String userId;
  final String name;
  final String? email;

  /// The shop assignment (`captain`, `owner`); null when no longer assigned.
  final String? role;
  final bool assigned;

  /// When they last moved an order in the range.
  final DateTime? lastHandledAt;

  /// When they last signed in, when the server knows.
  final DateTime? lastSeenAt;
  final ShopSalesFigures figures;
  final List<ShopAnalyticsOrder> recentOrders;
}

class ShopAnalyticsReport {
  const ShopAnalyticsReport({
    required this.shopKey,
    required this.shopName,
    required this.range,
    required this.summary,
    this.unattributedOrders = 0,
    this.captains = const [],
  });

  factory ShopAnalyticsReport.fromJson(
    Map<String, dynamic> json, {
    required AnalyticsDateRange requested,
  }) {
    final shop = _map(json['shop']);
    final range = _map(json['range']);
    final from = DateTime.tryParse('${range['from'] ?? ''}');
    final to = DateTime.tryParse('${range['to'] ?? ''}');
    final summary = _map(json['summary']);
    return ShopAnalyticsReport(
      shopKey: '${shop['shopKey'] ?? ''}',
      shopName: '${shop['name'] ?? ''}',
      range: from != null && to != null
          ? AnalyticsDateRange(from, to)
          : requested,
      summary: ShopSalesFigures.fromJson(summary),
      unattributedOrders: _int(summary['unattributedOrders']),
      captains: _list(json['captains'])
          .map((value) => CaptainPerformance.fromJson(_map(value)))
          .toList(growable: false),
    );
  }

  final String shopKey;
  final String shopName;
  final AnalyticsDateRange range;
  final ShopSalesFigures summary;

  /// Orders nobody has touched yet (still pending).
  final int unattributedOrders;
  final List<CaptainPerformance> captains;
}

/// One day of a staff member's range.
class CaptainDailyPoint {
  const CaptainDailyPoint({
    required this.date,
    this.orders = 0,
    this.completedOrders = 0,
    this.revenue = 0,
    this.profit = 0,
  });

  factory CaptainDailyPoint.fromJson(Map<String, dynamic> json) {
    final date = DateTime.tryParse('${json['date'] ?? ''}');
    return CaptainDailyPoint(
      date: date == null
          ? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime(date.year, date.month, date.day),
      orders: _int(json['orders']),
      completedOrders: _int(json['completedOrders']),
      revenue: _double(json['revenue']),
      profit: _double(json['profit']),
    );
  }

  final DateTime date;
  final int orders;
  final int completedOrders;
  final double revenue;
  final double profit;
}

/// One staff member over a range: their figures, a day-by-day series and a
/// page of the orders they handled, newest first.
class CaptainPerformanceDetail {
  const CaptainPerformanceDetail({
    required this.captain,
    required this.range,
    this.daily = const [],
    this.orders = const [],
    this.page = 1,
    this.pageSize = 20,
    this.totalOrders = 0,
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
      orders: _list(detail['orders'])
          .map((value) => ShopAnalyticsOrder.fromJson(_map(value)))
          .toList(growable: false),
      page: detail['page'] == null ? 1 : _int(detail['page']),
      pageSize: detail['pageSize'] == null ? 20 : _int(detail['pageSize']),
      totalOrders: _int(detail['totalOrders']),
      totalPages: detail['totalPages'] == null ? 1 : _int(detail['totalPages']),
    );
  }

  final CaptainPerformance captain;
  final AnalyticsDateRange range;
  final List<CaptainDailyPoint> daily;
  final List<ShopAnalyticsOrder> orders;
  final int page;
  final int pageSize;
  final int totalOrders;
  final int totalPages;

  bool get hasMore => page < totalPages;
}

/// A staff member's detail rolled up from orders on the device, for
/// repositories without the analytics endpoint. Offline, staff are named by
/// the orders, so [captainId] is the name [localShopAnalytics] used.
CaptainPerformanceDetail localCaptainDetail({
  required List<CanteenOrder> orders,
  required AnalyticsDateRange range,
  required String captainId,
  int page = 1,
  int pageSize = 20,
}) {
  final report = localShopAnalytics(orders: orders, range: range);
  final captain =
      report.captains.where((c) => c.userId == captainId).firstOrNull ??
      CaptainPerformance(
        userId: captainId,
        name: captainId,
        role: 'captain',
        figures: const ShopSalesFigures(),
      );
  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  bool inRange(DateTime at) {
    final day = DateTime(at.year, at.month, at.day);
    return !day.isBefore(range.from) && !day.isAfter(range.to);
  }

  final mine =
      orders
          .where(
            (order) =>
                order.effectiveCaptainName == captainId &&
                inRange(order.createdAt.toLocal()),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final daily = <CaptainDailyPoint>[];
  for (var i = 0; i < range.days; i++) {
    final day = DateTime(range.from.year, range.from.month, range.from.day + i);
    final those = [
      for (final order in mine)
        if (sameDay(order.createdAt.toLocal(), day)) order,
    ];
    final done = those.where(
      (order) => order.status == CanteenOrderStatus.completed,
    );
    daily.add(
      CaptainDailyPoint(
        date: day,
        orders: those.length,
        completedOrders: done.length,
        revenue: done.fold(0, (sum, order) => sum + order.total),
        profit: done.fold(0, (sum, order) => sum + order.totalProfit),
      ),
    );
  }
  final size = pageSize < 1 ? 1 : pageSize;
  final totalPages = mine.isEmpty ? 1 : (mine.length / size).ceil();
  final current = page.clamp(1, totalPages);
  return CaptainPerformanceDetail(
    captain: captain,
    range: range,
    daily: daily,
    orders: mine
        .skip((current - 1) * size)
        .take(size)
        .map(ShopAnalyticsOrder.fromOrder)
        .toList(growable: false),
    page: current,
    pageSize: size,
    totalOrders: mine.length,
    totalPages: totalPages,
  );
}

/// The same report rolled up from orders already on the device, for
/// repositories without the analytics endpoint (the offline demo). Staff are
/// whoever the orders name; there is no assignment list to add idle ones from.
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

  final scoped =
      orders.where((order) => inRange(order.createdAt.toLocal())).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  final summary = _figures(scoped, 0);
  final byStaff = <String, List<CanteenOrder>>{};
  for (final order in scoped) {
    byStaff.putIfAbsent(order.effectiveCaptainName, () => []).add(order);
  }
  final captains =
      byStaff.entries
          .map(
            (entry) => CaptainPerformance(
              userId: entry.key,
              name: entry.key,
              role: 'captain',
              figures: _figures(entry.value, summary.revenue),
              recentOrders: entry.value
                  .take(10)
                  .map(ShopAnalyticsOrder.fromOrder)
                  .toList(growable: false),
            ),
          )
          .toList()
        ..sort((a, b) => b.figures.revenue.compareTo(a.figures.revenue));
  return ShopAnalyticsReport(
    shopKey: shopKey,
    shopName: shopName,
    range: range,
    summary: summary,
    unattributedOrders: 0,
    captains: captains,
  );
}

ShopSalesFigures _figures(List<CanteenOrder> orders, double shopRevenue) {
  var revenue = 0.0, cost = 0.0, activeValue = 0.0, refunded = 0.0;
  var completed = 0, active = 0, rejected = 0, cancelled = 0, items = 0;
  for (final order in orders) {
    switch (order.status) {
      case CanteenOrderStatus.completed:
        completed++;
        items += order.itemCount;
        revenue += order.total;
        cost += order.totalCost;
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
  final profit = revenue - cost;
  final share = shopRevenue > 0 ? revenue / shopRevenue * 100 : 0.0;
  return ShopSalesFigures(
    orders: orders.length,
    completedOrders: completed,
    activeOrders: active,
    rejectedOrders: rejected,
    cancelledOrders: cancelled,
    itemsSold: items,
    revenue: revenue,
    cost: cost,
    profit: profit,
    marginPercent: revenue > 0 ? profit / revenue * 100 : 0,
    averageOrderValue: completed > 0 ? revenue / completed : 0,
    activeValue: activeValue,
    refunded: refunded,
    revenueShare: shopRevenue > 0 ? share : 0,
  );
}

/// Loads [ShopAnalyticsReport]s. Failures throw a `CanteenException`.
abstract interface class ShopAnalyticsRepository {
  Future<ShopAnalyticsReport> loadShopAnalytics({
    required String shopKey,
    required AnalyticsDateRange range,
  });

  /// One staff member's figures, daily series and a page of their orders.
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

double _double(Object? value) => switch (value) {
  final num number => number.toDouble(),
  final String text => double.tryParse(text) ?? 0,
  _ => 0,
};

int _int(Object? value) => switch (value) {
  final num number => number.round(),
  final String text => int.tryParse(text) ?? 0,
  _ => 0,
};
