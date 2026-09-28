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
  });

  factory ShopAnalyticsOrder.fromJson(Map<String, dynamic> json) =>
      ShopAnalyticsOrder(
        id: '${json['id'] ?? ''}',
        orderNumber: '${json['orderNumber'] ?? ''}',
        customerName: '${json['customerName'] ?? ''}',
        status: '${json['status'] ?? ''}',
        total: _double(json['total']),
        profit: _double(json['profit']),
        itemCount: _int(json['itemCount']),
        createdAt:
            DateTime.tryParse('${json['createdAt'] ?? ''}')?.toLocal() ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  final String id;
  final String orderNumber;
  final String customerName;

  /// The API's status value (`completed`, `rejected`, `preparing`, …).
  final String status;
  final double total;
  final double profit;
  final int itemCount;
  final DateTime createdAt;
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
  final DateTime? lastHandledAt;
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
                  .map(
                    (order) => ShopAnalyticsOrder(
                      id: order.id,
                      orderNumber: order.displayId,
                      customerName: order.customerName ?? '',
                      status: order.status.apiValue,
                      total: order.total,
                      profit: order.totalProfit,
                      itemCount: order.itemCount,
                      createdAt: order.createdAt,
                    ),
                  )
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
