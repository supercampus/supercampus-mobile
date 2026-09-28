enum VendorStatus { active, pending, suspended }

class Vendor {
  const Vendor({
    required this.id,
    required this.name,
    required this.category,
    required this.contact,
    required this.status,
  });
  final String id;
  final String name;
  final String category;
  final String contact;
  final VendorStatus status;
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.vendor,
    required this.amount,
    required this.status,
  });
  final String id;
  final String vendor;
  final double amount;
  final String status;
}

class VendorPayment {
  const VendorPayment({
    required this.id,
    required this.vendor,
    required this.amount,
    required this.date,
    required this.status,
  });
  final String id;
  final String vendor;
  final double amount;
  final String date;
  final String status;
}

class SalesKpiMetrics {
  const SalesKpiMetrics({
    required this.platformOrders,
    required this.ordersToday,
    required this.ordersTodayTrend,
    required this.revenue,
    required this.revenueToday,
    required this.revenueTodayTrend,
    required this.monthlyRevenue,
    required this.weeklyRevenue,
    required this.weeklyRevenueTrend,
    required this.todayOnlinePayments,
    required this.monthlyOnlinePayments,
    required this.onlinePaymentsTrend,
    required this.pendingActions,
    required this.pendingApprovals,
    required this.pendingRequests,
    required this.pendingActionsTrend,
  });

  final int platformOrders;
  final int ordersToday;
  final String ordersTodayTrend;
  final double revenue;
  final double revenueToday;
  final String revenueTodayTrend;
  final double monthlyRevenue;
  final double weeklyRevenue;
  final String weeklyRevenueTrend;
  final double todayOnlinePayments;
  final double monthlyOnlinePayments;
  final String onlinePaymentsTrend;
  final int pendingActions;
  final int pendingApprovals;
  final int pendingRequests;
  final String pendingActionsTrend;

  factory SalesKpiMetrics.fromJson(Map<String, dynamic> json) {
    return SalesKpiMetrics(
      platformOrders: (json['platformOrders'] as num?)?.toInt() ?? 0,
      ordersToday: (json['ordersToday'] as num?)?.toInt() ?? 0,
      ordersTodayTrend: json['ordersTodayTrend']?.toString() ?? '0 new today',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      revenueToday: (json['revenueToday'] as num?)?.toDouble() ?? 0.0,
      revenueTodayTrend: json['revenueTodayTrend']?.toString() ?? '₹0 today',
      monthlyRevenue: (json['monthlyRevenue'] as num?)?.toDouble() ?? 0.0,
      weeklyRevenue: (json['weeklyRevenue'] as num?)?.toDouble() ?? 0.0,
      weeklyRevenueTrend: json['weeklyRevenueTrend']?.toString() ?? '₹0 this week',
      todayOnlinePayments: (json['todayOnlinePayments'] as num?)?.toDouble() ?? 0.0,
      monthlyOnlinePayments: (json['monthlyOnlinePayments'] as num?)?.toDouble() ?? 0.0,
      onlinePaymentsTrend: json['onlinePaymentsTrend']?.toString() ?? '₹0 this month',
      pendingActions: (json['pendingActions'] as num?)?.toInt() ?? 0,
      pendingApprovals: (json['pendingApprovals'] as num?)?.toInt() ?? 0,
      pendingRequests: (json['pendingRequests'] as num?)?.toInt() ?? 0,
      pendingActionsTrend: json['pendingActionsTrend']?.toString() ?? '0 pending actions',
    );
  }

  static const defaults = SalesKpiMetrics(
    platformOrders: 0,
    ordersToday: 0,
    ordersTodayTrend: '0 new today',
    revenue: 0.0,
    revenueToday: 0.0,
    revenueTodayTrend: '₹0 today',
    monthlyRevenue: 0.0,
    weeklyRevenue: 0.0,
    weeklyRevenueTrend: '₹0 this week',
    todayOnlinePayments: 0.0,
    monthlyOnlinePayments: 0.0,
    onlinePaymentsTrend: '₹0 this month',
    pendingActions: 0,
    pendingApprovals: 0,
    pendingRequests: 0,
    pendingActionsTrend: '0 pending actions',
  );
}

class ShopSalesSummary {
  const ShopSalesSummary({
    required this.shopKey,
    required this.name,
    required this.category,
    required this.isActive,
    required this.isOpen,
    required this.ordersToday,
    required this.revenueToday,
    required this.totalOrders,
    required this.totalRevenue,
    required this.activeOrders,
  });

  final String shopKey;
  final String name;
  final String category;
  final bool isActive;
  final bool isOpen;
  final int ordersToday;
  final double revenueToday;
  final int totalOrders;
  final double totalRevenue;
  final int activeOrders;

  factory ShopSalesSummary.fromJson(Map<String, dynamic> json) {
    return ShopSalesSummary(
      shopKey: json['shopKey']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Shop',
      category: json['category']?.toString() ?? 'General',
      isActive: json['isActive'] != false,
      isOpen: json['isOpen'] != false,
      ordersToday: (json['ordersToday'] as num?)?.toInt() ?? 0,
      revenueToday: (json['revenueToday'] as num?)?.toDouble() ?? 0.0,
      totalOrders: (json['totalOrders'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      activeOrders: (json['activeOrders'] as num?)?.toInt() ?? 0,
    );
  }
}

class RecentSalesOrder {
  const RecentSalesOrder({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.store,
    required this.total,
    required this.status,
    required this.fulfilmentMode,
    this.createdAt,
  });

  final String id;
  final String orderNumber;
  final String customerName;
  final String store;
  final double total;
  final String status;
  final String fulfilmentMode;
  final DateTime? createdAt;

  factory RecentSalesOrder.fromJson(Map<String, dynamic> json) {
    return RecentSalesOrder(
      id: json['id']?.toString() ?? '',
      orderNumber: json['orderNumber']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? 'Student',
      store: json['store']?.toString() ?? '',
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      status: json['status']?.toString() ?? 'completed',
      fulfilmentMode: json['fulfilmentMode']?.toString() ?? 'takeaway',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

class SalesDashboardData {
  const SalesDashboardData({
    required this.kpi,
    required this.orderStatusDistribution,
    required this.paymentSplit,
    required this.shops,
    required this.recentOrders,
  });

  final SalesKpiMetrics kpi;
  final Map<String, double> orderStatusDistribution;
  final Map<String, double> paymentSplit;
  final List<ShopSalesSummary> shops;
  final List<RecentSalesOrder> recentOrders;

  factory SalesDashboardData.fromJson(Map<String, dynamic> json) {
    final shopsJson = json['shops'];
    final ordersJson = json['recentOrders'];
    final distJson = json['orderStatusDistribution'];
    final splitJson = json['paymentSplit'];

    return SalesDashboardData(
      kpi: json['platformOrders'] != null
          ? SalesKpiMetrics.fromJson(json)
          : SalesKpiMetrics.defaults,
      // Missing figures read as zero. Inventing a split here would put numbers
      // on screen that nothing measured.
      orderStatusDistribution: _numberMap(distJson),
      paymentSplit: _numberMap(splitJson),
      shops: shopsJson is List
          ? shopsJson
              .whereType<Map>()
              .map((e) => ShopSalesSummary.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
      recentOrders: ordersJson is List
          ? ordersJson
              .whereType<Map>()
              .map((e) => RecentSalesOrder.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : const [],
    );
  }

  static Map<String, double> _numberMap(Object? json) => {
    if (json is Map)
      for (final entry in json.entries)
        if (entry.value is num)
          entry.key.toString(): (entry.value as num).toDouble(),
  };

  static const defaults = SalesDashboardData(
    kpi: SalesKpiMetrics.defaults,
    orderStatusDistribution: {'completed': 0.0, 'cancelled': 0.0, 'pending': 0.0},
    paymentSplit: {'ordersPercentage': 0.0, 'adhocPercentage': 0.0},
    shops: [],
    recentOrders: [],
  );
}

/// Orders bucketed by outcome: completed, still in the queue, or ended without
/// a sale (cancelled or rejected).
///
/// Current servers send the counts; older ones sent only percentages of all
/// orders, so each bucket is then estimated from its own percentage, never by
/// subtracting one bucket from the total (which files every open order under
/// "cancelled").
class OrderStatusBreakdown {
  const OrderStatusBreakdown({
    required this.completed,
    required this.active,
    required this.cancelled,
  });

  factory OrderStatusBreakdown.of(SalesDashboardData data) {
    final dist = data.orderStatusDistribution;
    final hasCounts =
        dist.containsKey('completedCount') ||
        dist.containsKey('pendingCount') ||
        dist.containsKey('cancelledCount');
    if (hasCounts) {
      return OrderStatusBreakdown(
        completed: (dist['completedCount'] ?? 0).round(),
        active: (dist['pendingCount'] ?? 0).round(),
        cancelled: (dist['cancelledCount'] ?? 0).round(),
      );
    }
    final total = data.kpi.platformOrders;
    int estimate(String key) =>
        (total * ((dist[key] ?? 0) / 100.0)).round().clamp(0, total);
    return OrderStatusBreakdown(
      completed: estimate('completed'),
      active: estimate('pending'),
      cancelled: estimate('cancelled'),
    );
  }

  final int completed;
  final int active;
  final int cancelled;

  int get total => completed + active + cancelled;

  /// Whole-number share of [count]; 0 when there are no orders at all.
  int percentOf(int count) => total <= 0 ? 0 : ((count / total) * 100).round();
}

/// Completed sales split between food counters and the QR-paid stores.
class RevenueSplit {
  const RevenueSplit({required this.food, required this.other});

  factory RevenueSplit.of(SalesDashboardData data) {
    final split = data.paymentSplit;
    if (split.containsKey('ordersRevenue') ||
        split.containsKey('adhocRevenue')) {
      return RevenueSplit(
        food: split['ordersRevenue'] ?? 0,
        other: split['adhocRevenue'] ?? 0,
      );
    }
    final revenue = data.kpi.revenue;
    return RevenueSplit(
      food: revenue * ((split['ordersPercentage'] ?? 0) / 100.0),
      other: revenue * ((split['adhocPercentage'] ?? 0) / 100.0),
    );
  }

  final double food;
  final double other;

  double get total => food + other;
  bool get isEmpty => total <= 0;

  int get foodPercent => isEmpty ? 0 : ((food / total) * 100).round();
  int get otherPercent => isEmpty ? 0 : 100 - foodPercent;
}
