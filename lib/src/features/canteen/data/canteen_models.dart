/// The storefronts the canteen sells through.
///
/// Stationery is not food, so it brings its own sub-categories rather than
/// sharing the food ones. That is why [CanteenMenuItem.category] is a free
/// label owned by the storefront instead of a fixed enum.
enum MenuStore { classic, bites, stationery }

extension MenuStoreLabel on MenuStore {
  String get label => switch (this) {
    MenuStore.classic => 'Classic',
    MenuStore.bites => 'Bites',
    MenuStore.stationery => 'Stationery',
  };

  /// Wire value; matches the `store` column's check constraint.
  String get apiValue => name;

  static MenuStore parse(String? value) => switch (value) {
    'bites' => MenuStore.bites,
    'stationery' => MenuStore.stationery,
    _ => MenuStore.classic,
  };
}

class CanteenMenuItem {
  const CanteenMenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    this.actualPrice,
    required this.isVegetarian,
    this.store = MenuStore.classic,
    this.shopKey,
    this.isPopular = false,
    this.isAvailable = true,
    this.isInstant = false,
    this.prepMinutes = 10,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String description;
  final MenuStore store;
  final String? shopKey;

  String get effectiveShopKey =>
      shopKey == null || shopKey!.trim().isEmpty ? store.apiValue : shopKey!;

  /// A label within [store], named by whoever runs the counter — 'meals' for
  /// food, 'Hair Care & Shampoo' for stationery.
  final String category;
  final double price;
  final double? actualPrice;
  double get effectiveActualPrice => actualPrice ?? price;
  final bool isVegetarian;
  final bool isPopular;
  final bool isAvailable;

  /// Served straight from the counter; the menu badges these.
  final bool isInstant;
  final int prepMinutes;
  final String? imageUrl;

  CanteenMenuItem copyWith({
    String? id,
    String? name,
    String? description,
    MenuStore? store,
    String? shopKey,
    String? category,
    double? price,
    double? actualPrice,
    bool? isVegetarian,
    bool? isPopular,
    bool? isAvailable,
    bool? isInstant,
    int? prepMinutes,
    String? imageUrl,
  }) => CanteenMenuItem(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    store: store ?? this.store,
    shopKey: shopKey ?? this.shopKey,
    category: category ?? this.category,
    price: price ?? this.price,
    actualPrice: actualPrice ?? this.actualPrice,
    isVegetarian: isVegetarian ?? this.isVegetarian,
    isPopular: isPopular ?? this.isPopular,
    isAvailable: isAvailable ?? this.isAvailable,
    isInstant: isInstant ?? this.isInstant,
    prepMinutes: prepMinutes ?? this.prepMinutes,
    imageUrl: imageUrl ?? this.imageUrl,
  );
}

class CanteenShop {
  const CanteenShop({
    required this.id,
    required this.shopKey,
    required this.name,
    required this.category,
    this.description = '',
    this.isActive = true,
    this.isOpen = true,
  });

  final String id;
  final String shopKey;
  final String name;
  final String category;
  final String description;
  final bool isActive;
  final bool isOpen;
}

class CartLine {
  const CartLine({required this.item, required this.quantity});

  final CanteenMenuItem item;
  final int quantity;

  double get total => item.price * quantity;
}

enum CanteenOrderStatus {
  pending,
  accepted,
  preparing,
  ready,
  completed,
  rejected,
  cancelled,
}

/// How an order moves through the counter.
///
/// The queue advances one step at a time in one direction, so the card only
/// ever offers the next step rather than a menu of states. `completed` is the
/// terminal success state the API understands; the counter calls it delivered.
extension CanteenOrderServiceFlow on CanteenOrderStatus {
  CanteenOrderStatus? get nextServiceStep => switch (this) {
    // A pending order goes straight to preparing: accepting it and starting it
    // are the same action at a counter.
    CanteenOrderStatus.pending => CanteenOrderStatus.preparing,
    CanteenOrderStatus.accepted => CanteenOrderStatus.preparing,
    CanteenOrderStatus.preparing => CanteenOrderStatus.ready,
    CanteenOrderStatus.ready => CanteenOrderStatus.completed,
    _ => null,
  };

  /// Settled orders cannot be rejected — the money has already moved.
  bool get canReject => switch (this) {
    CanteenOrderStatus.completed ||
    CanteenOrderStatus.rejected ||
    CanteenOrderStatus.cancelled => false,
    _ => true,
  };
}

extension CanteenOrderStatusLabel on CanteenOrderStatus {
  String get label => switch (this) {
    CanteenOrderStatus.pending => 'Pending',
    CanteenOrderStatus.accepted => 'Accepted',
    CanteenOrderStatus.preparing => 'Preparing',
    CanteenOrderStatus.ready => 'Ready for pickup',
    CanteenOrderStatus.completed => 'Completed',
    CanteenOrderStatus.rejected => 'Rejected',
    CanteenOrderStatus.cancelled => 'Cancelled',
  };

  bool get isActive => switch (this) {
    CanteenOrderStatus.pending ||
    CanteenOrderStatus.accepted ||
    CanteenOrderStatus.preparing ||
    CanteenOrderStatus.ready => true,
    _ => false,
  };

  String get apiValue => name;
}

enum FulfilmentMode { dineIn, pickup }

extension FulfilmentModeLabel on FulfilmentMode {
  String get label => switch (this) {
    FulfilmentMode.dineIn => 'Dine in',
    FulfilmentMode.pickup => 'Pickup',
  };
}

class CanteenOrder {
  const CanteenOrder({
    required this.id,
    required this.lines,
    required this.total,
    required this.status,
    required this.fulfilmentMode,
    required this.createdAt,
    this.tokenNumber,
    this.orderNumber,
    this.customerName,
    this.qrPayload,
  });

  final String id;
  final List<CartLine> lines;
  final double total;
  final CanteenOrderStatus status;
  final FulfilmentMode fulfilmentMode;
  final DateTime createdAt;
  final int? tokenNumber;
  final String? orderNumber;
  final String? customerName;
  final String? qrPayload;

  String get displayId => orderNumber ?? id;

  CanteenOrder copyWith({CanteenOrderStatus? status, int? tokenNumber}) =>
      CanteenOrder(
        id: id,
        lines: lines,
        total: total,
        status: status ?? this.status,
        fulfilmentMode: fulfilmentMode,
        createdAt: createdAt,
        tokenNumber: tokenNumber ?? this.tokenNumber,
        orderNumber: orderNumber,
        customerName: customerName,
        qrPayload: qrPayload,
      );

  int get itemCount => lines.fold(0, (total, line) => total + line.quantity);
}

enum WalletTransactionType { credit, debit }

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final WalletTransactionType type;
  final double amount;
  final String description;
  final DateTime createdAt;

  double get signedAmount =>
      type == WalletTransactionType.credit ? amount : -amount;
}

class CanteenUser {
  const CanteenUser({
    required this.name,
    required this.email,
    required this.rollNumber,
    required this.department,
  });

  final String name;
  final String email;
  final String rollNumber;
  final String department;

  String get initials {
    final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'S';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }
}

class CanteenStore {
  const CanteenStore({
    required this.user,
    required this.walletBalance,
    required this.menu,
    required this.orders,
    required this.walletTransactions,
    this.shops = const [],
    this.assignedShopKeys = const [],
    this.canManage = false,
    // Existing custom/test repositories that expose management predate the
    // capability split and represent owners. The backend always sends the
    // explicit value, so order-only captains still receive `false`.
    this.canManageMenu = true,
    this.staffState = const CanteenStaffState(),
    this.analytics = const CanteenAnalytics(),
    this.laundryPricePerKg = 0,
    this.laundryCharges = const [],
  });

  final CanteenUser user;
  final double walletBalance;
  final List<CanteenMenuItem> menu;
  final List<CanteenOrder> orders;
  final List<WalletTransaction> walletTransactions;
  final List<CanteenShop> shops;
  final List<String> assignedShopKeys;
  final bool canManage;

  /// Owners can edit the catalogue. Order-only operators are canteen captains.
  final bool canManageMenu;
  final CanteenStaffState staffState;
  final CanteenAnalytics analytics;
  final double laundryPricePerKg;
  final List<LaundryCharge> laundryCharges;

  CanteenStore copyWith({
    double? walletBalance,
    List<CanteenOrder>? orders,
    List<WalletTransaction>? walletTransactions,
    List<CanteenMenuItem>? menu,
    List<CanteenShop>? shops,
    List<String>? assignedShopKeys,
    CanteenStaffState? staffState,
    CanteenAnalytics? analytics,
    double? laundryPricePerKg,
    List<LaundryCharge>? laundryCharges,
  }) {
    return CanteenStore(
      user: user,
      walletBalance: walletBalance ?? this.walletBalance,
      menu: menu ?? this.menu,
      orders: orders ?? this.orders,
      walletTransactions: walletTransactions ?? this.walletTransactions,
      shops: shops ?? this.shops,
      assignedShopKeys: assignedShopKeys ?? this.assignedShopKeys,
      canManage: canManage,
      canManageMenu: canManageMenu,
      staffState: staffState ?? this.staffState,
      analytics: analytics ?? this.analytics,
      laundryPricePerKg: laundryPricePerKg ?? this.laundryPricePerKg,
      laundryCharges: laundryCharges ?? this.laundryCharges,
    );
  }
}

enum LaundryServiceType { wash, ironing }

enum LaundryChargeStatus { pending, claimed, paid, cancelled }

class LaundryCharge {
  const LaundryCharge({
    required this.id,
    required this.serviceType,
    required this.name,
    required this.description,
    required this.quantity,
    required this.unitLabel,
    required this.unitPrice,
    required this.total,
    required this.status,
    required this.createdAt,
    this.qrPayload,
    this.claimedAt,
    this.paidAt,
  });

  final String id;
  final LaundryServiceType serviceType;
  final String name;
  final String description;
  final double quantity;
  final String unitLabel;
  final double unitPrice;
  final double total;
  final LaundryChargeStatus status;
  final DateTime createdAt;
  final String? qrPayload;
  final DateTime? claimedAt;
  final DateTime? paidAt;

  LaundryCharge copyWith({LaundryChargeStatus? status, DateTime? paidAt}) =>
      LaundryCharge(
        id: id,
        serviceType: serviceType,
        name: name,
        description: description,
        quantity: quantity,
        unitLabel: unitLabel,
        unitPrice: unitPrice,
        total: total,
        status: status ?? this.status,
        createdAt: createdAt,
        qrPayload: qrPayload,
        claimedAt: claimedAt,
        paidAt: paidAt ?? this.paidAt,
      );
}

class LaundryPaymentResult {
  const LaundryPaymentResult({
    required this.balance,
    required this.charge,
    required this.transaction,
  });

  final double balance;
  final LaundryCharge charge;
  final WalletTransaction transaction;
}

enum CanteenStaffMode { eat, work }

class CanteenStaffState {
  const CanteenStaffState({this.mode = CanteenStaffMode.eat, this.shopOpen});

  final CanteenStaffMode mode;
  final bool? shopOpen;
}

class CanteenAnalytics {
  const CanteenAnalytics({
    this.ordersToday = 0,
    this.revenueToday = 0,
    this.pending = 0,
  });

  final int ordersToday;
  final double revenueToday;
  final int pending;
}

class WalletTopUpResult {
  const WalletTopUpResult({required this.balance, required this.transaction});

  final double balance;
  final WalletTransaction transaction;
}

class WalletTopUpOrder {
  const WalletTopUpOrder({
    required this.id,
    required this.amount,
    required this.currency,
    required this.keyId,
  });

  final String id;
  final int amount;
  final String currency;
  final String keyId;
}

class WalletTopUpSettings {
  const WalletTopUpSettings({
    required this.minimumAmount,
    required this.maximumAmount,
  });

  final double minimumAmount;
  final double maximumAmount;

  static const defaults = WalletTopUpSettings(
    minimumAmount: 50,
    maximumAmount: 5000,
  );
}

/// What came back from paying for a cart.
///
/// A cart spanning several shops becomes one order per shop, each with its own
/// QR, because each counter hands over its own food. The wallet is shared, so
/// the balance is a single figure.
class OrderPlacementResult {
  const OrderPlacementResult({
    required this.balance,
    required this.orders,
    required this.transactions,
  });

  final double balance;
  final List<CanteenOrder> orders;
  final List<WalletTransaction> transactions;

  /// The order to show first — a single-shop cart has only this one.
  CanteenOrder get order => orders.first;

  bool get spansMultipleShops => orders.length > 1;
}
