/// Campus shop sales, as `/canteen/sales-dashboard` reports them.
///
/// Every figure is measured on the server from real sale rows (canteen and
/// stationery orders plus laundry charges). Revenue is completed sales only.
/// Missing figures parse as zero; nothing here invents a number.
library;

/// The window the dashboard and order list are cut to, in campus local time.
enum SalesPeriod {
  today('today', 'Today'),
  week('week', 'This week'),
  month('month', 'This month'),
  all('all', 'All time');

  const SalesPeriod(this.key, this.label);

  /// Query value the API accepts.
  final String key;
  final String label;

  static SalesPeriod parse(Object? raw) => SalesPeriod.values.firstWhere(
    (p) => p.key == raw?.toString(),
    orElse: () => SalesPeriod.today,
  );
}

/// Where an order ended up.
enum OrderStatusFilter {
  all('all', 'All'),
  active('active', 'In progress'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled');

  const OrderStatusFilter(this.key, this.label);

  final String key;
  final String label;

  static OrderStatusFilter parse(Object? raw) =>
      OrderStatusFilter.values.firstWhere(
        (s) => s.key == raw?.toString(),
        orElse: () => OrderStatusFilter.active,
      );
}

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
double _double(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
String _string(Object? v, [String fallback = '']) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty || s == 'null' ? fallback : s;
}

List<Map<String, dynamic>> _maps(Object? json) => json is List
    ? json
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false)
    : const [];

DateTime? _date(Object? raw) =>
    raw == null ? null : DateTime.tryParse(raw.toString());

class SalesSummary {
  const SalesSummary({
    this.orders = 0,
    this.completedOrders = 0,
    this.activeOrders = 0,
    this.cancelledOrders = 0,
    this.revenue = 0,
    this.averageOrderValue = 0,
    this.pendingNow = 0,
  });

  factory SalesSummary.fromJson(Map<String, dynamic> json) => SalesSummary(
    orders: _int(json['orders']),
    completedOrders: _int(json['completedOrders']),
    activeOrders: _int(json['activeOrders']),
    cancelledOrders: _int(json['cancelledOrders']),
    revenue: _double(json['revenue']),
    averageOrderValue: _double(json['averageOrderValue']),
    pendingNow: _int(json['pendingNow']),
  );

  /// Every sale placed in the period, whatever became of it.
  final int orders;
  final int completedOrders;
  final int activeOrders;
  final int cancelledOrders;

  /// Completed sales in the period.
  final double revenue;

  /// Revenue per completed sale.
  final double averageOrderValue;

  /// Orders waiting at a counter right now, whatever the period.
  final int pendingNow;

  /// Whole-number share of [count] among the period's orders.
  int percentOf(int count) =>
      orders <= 0 ? 0 : ((count / orders) * 100).round();
}

class ShopOperator {
  const ShopOperator({required this.name, required this.role});

  factory ShopOperator.fromJson(Map<String, dynamic> json) => ShopOperator(
    name: _string(json['name'], 'Staff member'),
    role: _string(json['role'], 'captain'),
  );

  final String name;

  /// `owner` or `captain`.
  final String role;

  bool get isOwner => role == 'owner';
}

/// One shop's sales in the selected period, plus its live state today.
class StoreSales {
  const StoreSales({
    required this.shopKey,
    required this.name,
    required this.category,
    this.id,
    this.isActive = true,
    this.isOpen = true,
    this.operators = const [],
    this.orders = 0,
    this.completedOrders = 0,
    this.cancelledOrders = 0,
    this.revenue = 0,
    this.revenueShare = 0,
    this.averageOrderValue = 0,
    this.ordersToday = 0,
    this.revenueToday = 0,
    this.activeNow = 0,
    this.position,
  });

  factory StoreSales.fromJson(Map<String, dynamic> json) => StoreSales(
    id: json['id']?.toString(),
    shopKey: _string(json['shopKey']),
    name: _string(json['name'], 'Shop'),
    category: _string(json['category'], 'Other'),
    isActive: json['isActive'] != false,
    isOpen: json['isOpen'] != false,
    operators: _maps(json['operators']).map(ShopOperator.fromJson).toList(),
    orders: _int(json['orders']),
    completedOrders: _int(json['completedOrders']),
    cancelledOrders: _int(json['cancelledOrders']),
    revenue: _double(json['revenue']),
    revenueShare: _int(json['revenueShare']),
    averageOrderValue: _double(json['averageOrderValue']),
    ordersToday: _int(json['ordersToday']),
    revenueToday: _double(json['revenueToday']),
    activeNow: _int(json['activeNow']),
    position: json['position'] is num ? (json['position'] as num).toInt() : null,
  );

  final String? id;
  final String shopKey;
  final String name;
  final String category;
  final bool isActive;
  final bool isOpen;
  final List<ShopOperator> operators;
  final int orders;
  final int completedOrders;
  final int cancelledOrders;
  final double revenue;

  /// Whole-number percent of the period's revenue.
  final int revenueShare;
  final double averageOrderValue;
  final int ordersToday;
  final double revenueToday;
  final int activeNow;

  /// Where the administrator placed this shop in their sequence; null for a
  /// key the register no longer holds (or a server that predates ordering).
  final int? position;

  /// Taking orders right now: enabled by the admin and opened by staff.
  bool get isTrading => isActive && isOpen;
}

/// Orders shops the way the administrator arranged them; shops never placed
/// follow by name.
int compareStoresByPosition(StoreSales a, StoreSales b) {
  final pa = a.position, pb = b.position;
  if (pa != null && pb != null && pa != pb) return pa.compareTo(pb);
  if (pa != null && pb == null) return -1;
  if (pa == null && pb != null) return 1;
  return a.name.compareTo(b.name);
}

class TrendPoint {
  const TrendPoint({
    required this.start,
    this.orders = 0,
    this.completedOrders = 0,
    this.revenue = 0,
    this.isFuture = false,
  });

  factory TrendPoint.fromJson(Map<String, dynamic> json) => TrendPoint(
    start: _date(json['start']) ?? DateTime(1970),
    orders: _int(json['orders']),
    completedOrders: _int(json['completedOrders']),
    revenue: _double(json['revenue']),
    isFuture: json['isFuture'] == true,
  );

  /// Campus local time at which this bar begins.
  final DateTime start;
  final int orders;
  final int completedOrders;
  final double revenue;

  /// Later today / this week / this month: nothing could have sold yet.
  final bool isFuture;
}

/// Width of one bar in the revenue chart.
enum TrendUnit { hour, day, month }

class SalesTrend {
  const SalesTrend({this.unit = TrendUnit.day, this.points = const []});

  factory SalesTrend.fromJson(Object? json) {
    if (json is! Map) return const SalesTrend();
    final map = Map<String, dynamic>.from(json);
    return SalesTrend(
      unit: TrendUnit.values.firstWhere(
        (u) => u.name == map['unit'],
        orElse: () => TrendUnit.day,
      ),
      points: _maps(map['points']).map(TrendPoint.fromJson).toList(),
    );
  }

  final TrendUnit unit;
  final List<TrendPoint> points;

  double get peakRevenue =>
      points.fold(0.0, (peak, p) => p.revenue > peak ? p.revenue : peak);

  bool get hasSales => points.any((p) => p.revenue > 0);
}

class TopItem {
  const TopItem({
    required this.name,
    required this.shopKey,
    required this.quantity,
    required this.revenue,
  });

  factory TopItem.fromJson(Map<String, dynamic> json) => TopItem(
    name: _string(json['name'], 'Item'),
    shopKey: _string(json['shopKey']),
    quantity: _double(json['quantity']),
    revenue: _double(json['revenue']),
  );

  final String name;
  final String shopKey;
  final double quantity;
  final double revenue;
}

class SalesDashboardData {
  const SalesDashboardData({
    this.period = SalesPeriod.today,
    this.summary = const SalesSummary(),
    this.stores = const [],
    this.trend = const SalesTrend(),
    this.topItems = const [],
    this.generatedAt,
  });

  factory SalesDashboardData.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'];
    return SalesDashboardData(
      period: SalesPeriod.parse(json['period']),
      summary: summary is Map
          ? SalesSummary.fromJson(Map<String, dynamic>.from(summary))
          : const SalesSummary(),
      stores: _maps(json['stores']).map(StoreSales.fromJson).toList(),
      trend: SalesTrend.fromJson(json['trend']),
      topItems: _maps(json['topItems']).map(TopItem.fromJson).toList(),
      generatedAt: _date(json['generatedAt']),
    );
  }

  final SalesPeriod period;
  final SalesSummary summary;
  final List<StoreSales> stores;
  final SalesTrend trend;
  final List<TopItem> topItems;

  /// Campus local time the figures were measured.
  final DateTime? generatedAt;

  StoreSales? storeFor(String shopKey) {
    for (final store in stores) {
      if (store.shopKey == shopKey) return store;
    }
    return null;
  }

  String storeName(String shopKey) => storeFor(shopKey)?.name ?? shopKey;
}

class SalesOrderLine {
  const SalesOrderLine({
    required this.name,
    required this.quantity,
    this.price,
    this.unitLabel,
    this.lineTotal,
  });

  factory SalesOrderLine.fromJson(Map<String, dynamic> json) {
    final quantity = _double(json['quantity']);
    final price = json['price'] is num ? _double(json['price']) : null;
    return SalesOrderLine(
      name: _string(json['name'], 'Item'),
      quantity: quantity,
      price: price,
      unitLabel: json['unitLabel']?.toString(),
      lineTotal: json['lineTotal'] is num
          ? _double(json['lineTotal'])
          : (price == null ? null : price * quantity),
    );
  }

  final String name;
  final double quantity;
  final double? price;

  /// `kg` or `clothes` for laundry; null for counted items.
  final String? unitLabel;
  final double? lineTotal;
}

/// One sale: a canteen/stationery order or a laundry charge.
class SalesOrder {
  const SalesOrder({
    required this.id,
    required this.kind,
    required this.customerName,
    required this.shopKey,
    required this.storeName,
    required this.total,
    required this.status,
    required this.statusBucket,
    this.orderNumber,
    this.category = '',
    this.fulfilmentMode,
    this.tokenNumber,
    this.rejectionReason,
    this.lines = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory SalesOrder.fromJson(Map<String, dynamic> json) => SalesOrder(
    id: _string(json['id']),
    kind: _string(json['kind'], 'order'),
    orderNumber: json['orderNumber'] is num ? _int(json['orderNumber']) : null,
    customerName: _string(json['customerName'], 'Customer'),
    shopKey: _string(json['shopKey'] ?? json['store']),
    storeName: _string(json['storeName'] ?? json['store'], 'Shop'),
    category: _string(json['category']),
    total: _double(json['total']),
    status: _string(json['status'], 'pending'),
    statusBucket: OrderStatusFilter.parse(json['statusBucket']),
    fulfilmentMode: json['fulfilmentMode']?.toString(),
    tokenNumber: json['tokenNumber'] is num ? _int(json['tokenNumber']) : null,
    rejectionReason: json['rejectionReason']?.toString(),
    lines: _maps(json['lines']).map(SalesOrderLine.fromJson).toList(),
    createdAt: _date(json['createdAt']),
    updatedAt: _date(json['updatedAt']),
  );

  final String id;

  /// `order` or `laundry`.
  final String kind;
  final int? orderNumber;
  final String customerName;
  final String shopKey;
  final String storeName;
  final String category;
  final double total;

  /// The raw status (pending, preparing, paid, rejected…).
  final String status;
  final OrderStatusFilter statusBucket;
  final String? fulfilmentMode;
  final int? tokenNumber;
  final String? rejectionReason;
  final List<SalesOrderLine> lines;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isLaundry => kind == 'laundry';

  String get reference => orderNumber != null
      ? '#$orderNumber'
      : (isLaundry ? 'Laundry charge' : 'Order');

  /// "Preparing", "Ready for pickup", "Paid"…
  String get statusLabel => switch (status) {
    'pending' => isLaundry ? 'Awaiting scan' : 'New',
    'accepted' => 'Accepted',
    'preparing' => 'Preparing',
    'ready' => 'Ready',
    'completed' => 'Completed',
    'claimed' => 'Awaiting payment',
    'paid' => 'Paid',
    'rejected' => 'Rejected',
    'cancelled' => 'Cancelled',
    _ => status.isEmpty ? 'Unknown' : status[0].toUpperCase() + status.substring(1),
  };

  String? get fulfilmentLabel => switch (fulfilmentMode) {
    'dine_in' => 'Dine in',
    'pickup' => 'Pickup',
    _ => null,
  };
}

class SalesOrderPage {
  const SalesOrderPage({this.total = 0, this.orders = const []});

  factory SalesOrderPage.fromJson(Map<String, dynamic> json) {
    final orders = _maps(json['orders']).map(SalesOrder.fromJson).toList();
    return SalesOrderPage(
      total: json['total'] is num ? _int(json['total']) : orders.length,
      orders: orders,
    );
  }

  /// Every matching sale, of which [orders] holds the newest.
  final int total;
  final List<SalesOrder> orders;
}
