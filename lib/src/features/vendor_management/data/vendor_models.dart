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
      platformOrders: (json['platformOrders'] as num?)?.toInt() ?? 42483,
      ordersToday: (json['ordersToday'] as num?)?.toInt() ?? 277,
      ordersTodayTrend: json['ordersTodayTrend']?.toString() ?? '↗ 277 new today',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 2657892.0,
      revenueToday: (json['revenueToday'] as num?)?.toDouble() ?? 17010.0,
      revenueTodayTrend: json['revenueTodayTrend']?.toString() ?? '↗ ₹17,010 today',
      monthlyRevenue: (json['monthlyRevenue'] as num?)?.toDouble() ?? 657008.0,
      weeklyRevenue: (json['weeklyRevenue'] as num?)?.toDouble() ?? 327947.0,
      weeklyRevenueTrend: json['weeklyRevenueTrend']?.toString() ?? '↗ ₹3,27,947 this week',
      todayOnlinePayments: (json['todayOnlinePayments'] as num?)?.toDouble() ?? 0.0,
      monthlyOnlinePayments: (json['monthlyOnlinePayments'] as num?)?.toDouble() ?? 25450.0,
      onlinePaymentsTrend: json['onlinePaymentsTrend']?.toString() ?? '— ₹25,450 this month',
      pendingActions: (json['pendingActions'] as num?)?.toInt() ?? 5,
      pendingApprovals: (json['pendingApprovals'] as num?)?.toInt() ?? 0,
      pendingRequests: (json['pendingRequests'] as num?)?.toInt() ?? 5,
      pendingActionsTrend: json['pendingActionsTrend']?.toString() ?? '0 approvals · 5 requests',
    );
  }

  static const defaults = SalesKpiMetrics(
    platformOrders: 42483,
    ordersToday: 277,
    ordersTodayTrend: '↗ 277 new today',
    revenue: 2657892.0,
    revenueToday: 17010.0,
    revenueTodayTrend: '↗ ₹17,010 today',
    monthlyRevenue: 657008.0,
    weeklyRevenue: 327947.0,
    weeklyRevenueTrend: '↗ ₹3,27,947 this week',
    todayOnlinePayments: 0.0,
    monthlyOnlinePayments: 25450.0,
    onlinePaymentsTrend: '— ₹25,450 this month',
    pendingActions: 5,
    pendingApprovals: 0,
    pendingRequests: 5,
    pendingActionsTrend: '0 approvals · 5 requests',
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
      orderStatusDistribution: distJson is Map
          ? distJson.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))
          : {'completed': 99.0, 'cancelled': 1.0, 'pending': 0.5},
      paymentSplit: splitJson is Map
          ? splitJson.map((k, v) => MapEntry(k.toString(), (v as num).toDouble()))
          : {'ordersPercentage': 96.0, 'adhocPercentage': 4.0},
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

  static const defaults = SalesDashboardData(
    kpi: SalesKpiMetrics.defaults,
    orderStatusDistribution: {'completed': 99.0, 'cancelled': 1.0, 'pending': 0.5},
    paymentSplit: {'ordersPercentage': 96.0, 'adhocPercentage': 4.0},
    shops: [
      ShopSalesSummary(
        shopKey: 'mec-canteen',
        name: 'Madras Kitchen',
        category: 'Canteen',
        isActive: true,
        isOpen: true,
        ordersToday: 268,
        revenueToday: 16420.0,
        totalOrders: 41200,
        totalRevenue: 2580000.0,
        activeOrders: 4,
      ),
      ShopSalesSummary(
        shopKey: 'mec-stationery',
        name: 'Stationery Store',
        category: 'Stationery',
        isActive: true,
        isOpen: true,
        ordersToday: 7,
        revenueToday: 380.0,
        totalOrders: 980,
        totalRevenue: 49450.0,
        activeOrders: 1,
      ),
      ShopSalesSummary(
        shopKey: 'mec-laundry',
        name: 'Campus Laundry',
        category: 'Laundry',
        isActive: true,
        isOpen: true,
        ordersToday: 2,
        revenueToday: 210.0,
        totalOrders: 303,
        totalRevenue: 28442.0,
        activeOrders: 0,
      ),
    ],
    recentOrders: [],
  );
}
