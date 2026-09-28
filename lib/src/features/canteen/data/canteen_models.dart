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
    this.cost,
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

  /// Selling price charged to the customer.
  final double price;

  /// Cost price to prepare / procure the item.
  final double? cost;

  /// Effective cost, defaulting to actualPrice or 70% of price if unconfigured.
  double get effectiveCost => cost ?? actualPrice ?? (price * 0.7);

  /// Profit per item = Selling Price - Cost.
  double get profit => price - effectiveCost;

  /// Profit margin ratio (0.0 to 1.0).
  double get profitMargin => price > 0 ? (profit / price) : 0.0;

  final double? actualPrice;
  double get effectiveActualPrice => actualPrice ?? cost ?? price;
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
    double? cost,
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
    cost: cost ?? this.cost,
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
  const CartLine({required this.item, required this.quantity, this.status});

  final CanteenMenuItem item;
  final int quantity;

  /// The item's own place in the counter flow, once the counter has moved
  /// it on its own. Null means it still follows its order.
  final CanteenOrderStatus? status;

  double get total => item.price * quantity;
  double get costTotal => item.effectiveCost * quantity;
  double get profitTotal => total - costTotal;
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
    this.customerUserId,
    this.qrPayload,
    this.captainName,
  });

  final String id;

  /// The account that placed the order, when the source reports it. Staff in
  /// Shop mode see only their own orders; their counter's queue stays in Work.
  final String? customerUserId;
  final List<CartLine> lines;
  final double total;
  final CanteenOrderStatus status;
  final FulfilmentMode fulfilmentMode;
  final DateTime createdAt;
  final int? tokenNumber;
  final String? orderNumber;
  final String? customerName;
  final String? qrPayload;
  final String? captainName;

  String get displayId {
    final raw = (orderNumber != null && orderNumber!.trim().isNotEmpty)
        ? orderNumber!.trim()
        : null;
    if (raw != null) {
      final parsed = int.tryParse(raw);
      if (parsed != null) {
        return parsed.toString().padLeft(4, '0');
      }
      return raw.padLeft(4, '0');
    }
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isNotEmpty) {
      final parsed = int.tryParse(digits);
      if (parsed != null) {
        return (parsed % 10000).toString().padLeft(4, '0');
      }
      return digits.length >= 4
          ? digits.substring(digits.length - 4)
          : digits.padLeft(4, '0');
    }
    return id.length >= 4 ? id.substring(id.length - 4) : id.padLeft(4, '0');
  }

  bool get isInstantOrder =>
      lines.isNotEmpty && lines.every((line) => line.item.isInstant);

  CanteenOrderStatus? get nextServiceStep {
    return switch (status) {
      CanteenOrderStatus.pending || CanteenOrderStatus.accepted =>
        isInstantOrder ? CanteenOrderStatus.completed : CanteenOrderStatus.preparing,
      CanteenOrderStatus.preparing => CanteenOrderStatus.ready,
      CanteenOrderStatus.ready => CanteenOrderStatus.completed,
      _ => status.isActive ? CanteenOrderStatus.completed : null,
    };
  }

  /// Where one food item stands. Settled orders settle every item; an item
  /// never moved on its own follows its order, except that instant food has
  /// no kitchen stage to follow.
  CanteenOrderStatus lineStatus(int index) {
    if (!status.isActive) return status;
    final line = lines[index];
    if (line.status != null) return line.status!;
    return switch (status) {
      CanteenOrderStatus.preparing || CanteenOrderStatus.ready =>
        line.item.isInstant ? CanteenOrderStatus.pending : status,
      _ => CanteenOrderStatus.pending,
    };
  }

  /// The next step for one food item: instant food is handed over straight
  /// from pending; prepared food goes pending → preparing → ready → delivered.
  CanteenOrderStatus? nextLineStep(int index) {
    final current = lineStatus(index);
    if (lines[index].item.isInstant) {
      return current.isActive ? CanteenOrderStatus.completed : null;
    }
    return current.nextServiceStep;
  }

  /// The order after one item moves: every item is pinned to its own status
  /// and the order's status summarises them, as the server does.
  CanteenOrder withLineStatus(int index, CanteenOrderStatus next) {
    final statuses = [
      for (var i = 0; i < lines.length; i++) i == index ? next : lineStatus(i),
    ];
    final remaining =
        statuses.where((s) => s != CanteenOrderStatus.completed).toList();
    final CanteenOrderStatus summary;
    if (remaining.isEmpty) {
      summary = CanteenOrderStatus.completed;
    } else if (remaining.contains(CanteenOrderStatus.preparing)) {
      summary = CanteenOrderStatus.preparing;
    } else if (remaining.every((s) => s == CanteenOrderStatus.ready)) {
      summary = CanteenOrderStatus.ready;
    } else if (statuses.any((s) => s != CanteenOrderStatus.pending)) {
      summary = CanteenOrderStatus.accepted;
    } else {
      summary = status;
    }
    return CanteenOrder(
      id: id,
      lines: [
        for (var i = 0; i < lines.length; i++)
          CartLine(
            item: lines[i].item,
            quantity: lines[i].quantity,
            status: statuses[i],
          ),
      ],
      total: total,
      status: summary,
      fulfilmentMode: fulfilmentMode,
      createdAt: createdAt,
      tokenNumber: tokenNumber,
      orderNumber: orderNumber,
      customerName: customerName,
      customerUserId: customerUserId,
      qrPayload: qrPayload,
      captainName: captainName,
    );
  }

  /// Who handled the order at the counter. Orders the server does not
  /// attribute are grouped together rather than credited to an invented name.
  String get effectiveCaptainName {
    if (captainName != null && captainName!.trim().isNotEmpty) {
      return captainName!.trim();
    }
    return 'Counter';
  }

  CanteenOrder copyWith({
    CanteenOrderStatus? status,
    int? tokenNumber,
    String? captainName,
  }) =>
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
        customerUserId: customerUserId,
        qrPayload: qrPayload,
        captainName: captainName ?? this.captainName,
      );

  int get itemCount => lines.fold(0, (total, line) => total + line.quantity);

  bool get isInstantOnly =>
      lines.isNotEmpty && lines.every((line) => line.item.isInstant);

  double get totalCost =>
      lines.fold<double>(0, (sum, line) => sum + line.costTotal);

  double get totalProfit => lines.isEmpty
      ? total * 0.3
      : lines.fold<double>(0, (sum, line) => sum + line.profitTotal);
}

enum WalletTransactionType { credit, debit }

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.shopKey,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.kind,
    this.referenceId,
  });

  final String id;
  final String shopKey;
  final WalletTransactionType type;
  final double amount;
  final String description;
  final DateTime createdAt;

  /// The ledger's own kind (`order_debit`, `online_top_up`, `manual_top_up`,
  /// `refund`), when the source reports it.
  final String? kind;

  /// What the movement was for: the order or laundry charge it paid, the order
  /// a refund returned, or the gateway order of an online top-up.
  final String? referenceId;

  double get signedAmount =>
      type == WalletTransactionType.credit ? amount : -amount;
}

class CanteenUser {
  const CanteenUser({
    this.id,
    required this.name,
    required this.email,
    required this.rollNumber,
    required this.department,
  });

  /// The signed-in account's id, when the source reports it.
  final String? id;
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
    this.walletBalances = const {},
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
    this.canConfigureShops = false,
    this.staffState = const CanteenStaffState(),
    this.analytics = const CanteenAnalytics(),
    this.laundryPricePerKg = 0,
    this.laundryCharges = const [],
    this.hasPin = false,
    this.hasPinHint = false,
  });

  final CanteenUser user;
  final Map<String, double> walletBalances;
  final List<CanteenMenuItem> menu;
  final List<CanteenOrder> orders;
  final List<WalletTransaction> walletTransactions;
  final List<CanteenShop> shops;
  final List<String> assignedShopKeys;
  final bool canManage;

  /// Owners can edit the catalogue. Order-only operators are canteen captains.
  final bool canManageMenu;

  /// Holds the grant to configure the campus's shops (vendor management).
  /// Someone with it who is not assigned to a shop oversees that shop — its
  /// figures and, for food, its menu — rather than working its counter.
  final bool canConfigureShops;
  final CanteenStaffState staffState;
  final CanteenAnalytics analytics;
  final double laundryPricePerKg;
  final List<LaundryCharge> laundryCharges;

  /// Whether the user has set a 4-digit transaction PIN.
  final bool hasPin;

  /// Whether a recovery word is stored for the PIN, so "Use recovery word"
  /// can be offered when changing it.
  final bool hasPinHint;

  CanteenStore copyWith({
    Map<String, double>? walletBalances,
    List<CanteenOrder>? orders,
    List<WalletTransaction>? walletTransactions,
    List<CanteenMenuItem>? menu,
    List<CanteenShop>? shops,
    List<String>? assignedShopKeys,
    CanteenStaffState? staffState,
    CanteenAnalytics? analytics,
    double? laundryPricePerKg,
    List<LaundryCharge>? laundryCharges,
    bool? hasPin,
    bool? hasPinHint,
  }) {
    return CanteenStore(
      user: user,
      walletBalances: walletBalances ?? this.walletBalances,
      menu: menu ?? this.menu,
      orders: orders ?? this.orders,
      walletTransactions: walletTransactions ?? this.walletTransactions,
      shops: shops ?? this.shops,
      assignedShopKeys: assignedShopKeys ?? this.assignedShopKeys,
      canManage: canManage,
      canManageMenu: canManageMenu,
      canConfigureShops: canConfigureShops,
      staffState: staffState ?? this.staffState,
      analytics: analytics ?? this.analytics,
      laundryPricePerKg: laundryPricePerKg ?? this.laundryPricePerKg,
      laundryCharges: laundryCharges ?? this.laundryCharges,
      hasPin: hasPin ?? this.hasPin,
      hasPinHint: hasPinHint ?? this.hasPinHint,
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
    this.claimedBy,
  });

  final String id;

  /// The account that claimed the charge. Only a laundry operator's payload
  /// carries it, since they see every charge the counter raised.
  final String? claimedBy;
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
        claimedBy: claimedBy,
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

/// Whether someone with a shop job is at work or shopping.
///
/// [eat] keeps its wire name (`eat`) for the stored preference, but it means
/// Shop: the person buys from every campus store like any student — canteen,
/// stationery and laundry — with their own wallets.
enum CanteenStaffMode { eat, work }

extension CanteenStaffModeLabel on CanteenStaffMode {
  String get label => switch (this) {
    CanteenStaffMode.work => 'Work',
    CanteenStaffMode.eat => 'Shop',
  };

  String get description => switch (this) {
    CanteenStaffMode.work => 'Run your counter, menu and sales',
    CanteenStaffMode.eat =>
      'Buy from Campus Canteen, Stationery and Laundry with your wallet',
  };
}

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
