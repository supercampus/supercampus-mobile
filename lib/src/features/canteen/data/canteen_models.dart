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

  /// The cost price the shop recorded for the item; null when it recorded
  /// none. Sales figures use this, never [effectiveCost]'s estimate.
  double? get recordedCost => actualPrice ?? cost;
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
    this.createdAt,
    this.parentShopKey,
  });

  final String id;
  final String shopKey;
  final String name;
  final String category;
  final String description;
  final bool isActive;
  final bool isOpen;

  /// The canteen this shop is a counter of (Meals, Beverages, Snacks under
  /// the campus canteen). A counter runs its own staff, menu and orders;
  /// students find it inside its canteen, and its canteen holds the wallet.
  final String? parentShopKey;

  bool get isCounter =>
      parentShopKey != null && parentShopKey!.trim().isNotEmpty;

  /// When the administrator added the shop. Legacy store keys belong to the
  /// oldest shop of their category, so a newer second canteen never takes
  /// over the original canteen's old items and orders.
  final DateTime? createdAt;

  /// Whether the shop sells food (anything that is not stationery or
  /// laundry), and so has a menu and kitchen queue.
  bool get isFood {
    final kind = '${category.toLowerCase()} ${shopKey.toLowerCase()}';
    return !kind.contains('station') && !kind.contains('laundry');
  }
}

/// One shop the signed-in person works at, and in what capacity.
class ShopAssignment {
  const ShopAssignment({
    required this.shopKey,
    required this.role,
    this.name,
    this.parentShopKey,
  });

  final String shopKey;

  /// The shop's name, when the server sends it.
  final String? name;

  /// The canteen [shopKey] is a counter of, when it is one.
  final String? parentShopKey;

  /// `owner` (runs the counter and its menu) or `captain` (runs the counter).
  final String role;

  bool get isOwner => role == 'owner';
}

/// The shop category a store key implies, by the server's own rule: anything
/// naming laundry is laundry, anything naming station(ery) is stationery, and
/// everything else — `classic`, `bites`, `mec-canteen` — is the canteen.
String shopCategoryForStoreKey(String key) {
  final value = key.trim().toLowerCase();
  if (value.contains('laundry')) return 'laundry';
  if (value.contains('station')) return 'stationery';
  return 'canteen';
}

/// Maps a stored store key — possibly a legacy one like `classic` or
/// `stationery` — onto the configured shop it belongs to.
///
/// Mirrors the platform API's resolver (`resolved_shop_key_sql!`), so a
/// campus can run several shops of one category — two canteens — without
/// one absorbing the other:
///
/// - a key that is some shop's own key is that shop, active or not;
/// - only a key naming no shop (a legacy `classic`, `bites`) falls back to a
///   shop of the category it implies: the oldest active one, else the oldest;
/// - with no shop of that category the category itself stands in, so two
///   legacy keys of one kind still agree with each other.
String resolveShopKey(String? raw, List<CanteenShop> shops) {
  final key = (raw ?? '').trim();
  for (final shop in shops) {
    if (shop.shopKey == key) return shop.shopKey;
  }
  final category = shopCategoryForStoreKey(key);
  final candidates = [
    for (var i = 0; i < shops.length; i++)
      if (shops[i].category.trim().toLowerCase() == category) (i, shops[i]),
  ];
  if (candidates.isEmpty) return 'category:$category';
  candidates.sort((a, b) {
    final (indexA, shopA) = a;
    final (indexB, shopB) = b;
    if (shopA.isActive != shopB.isActive) return shopA.isActive ? -1 : 1;
    final createdA = shopA.createdAt;
    final createdB = shopB.createdAt;
    if (createdA != null && createdB != null) {
      final byAge = createdA.compareTo(createdB);
      return byAge != 0 ? byAge : shopA.shopKey.compareTo(shopB.shopKey);
    }
    // Without creation times (older servers) the listed order decides.
    return indexA.compareTo(indexB);
  });
  return candidates.first.$2.shopKey;
}

/// The first active shop of [category] in the campus's listed order. A
/// counter is never "the canteen": links land on the canteen it belongs to.
String? firstShopKeyOfCategory(List<CanteenShop> shops, String category) {
  for (final shop in shops) {
    if (shop.isActive &&
        !shop.isCounter &&
        shop.category.trim().toLowerCase() == category) {
      return shop.shopKey;
    }
  }
  return null;
}

/// Whether [rowKey] and [walletKey] name the same shop's wallet.
bool sameShop(String? rowKey, String walletKey, List<CanteenShop> shops) {
  if (rowKey == null || rowKey.trim().isEmpty) return false;
  return resolveShopKey(rowKey, shops) == resolveShopKey(walletKey, shops);
}

/// The active counters of [canteenKey], in the campus's listed order.
List<CanteenShop> countersOf(String canteenKey, List<CanteenShop> shops) => [
  for (final shop in shops)
    if (shop.isActive && shop.parentShopKey == canteenKey) shop,
];

/// The wallet [shopKey] spends from: the canteen of a counter, otherwise the
/// shop itself.
String walletKeyOf(String shopKey, List<CanteenShop> shops) {
  for (final shop in shops) {
    if (shop.shopKey == shopKey && shop.isCounter) return shop.parentShopKey!;
  }
  return shopKey;
}

/// One canteen wallet split into what each counter may spend.
///
/// The canteen's own balance is general credit, spendable at any of its
/// counters; a counter's own balance is credit the accountant restricted to
/// that counter. A shop without counters has only [general].
class WalletBreakdown {
  const WalletBreakdown({
    required this.walletKey,
    required this.general,
    this.restricted = const {},
  });

  final String walletKey;
  final double general;

  /// Counter key → credit only that counter accepts, for every active
  /// counter of the canteen (zero when there is none).
  final Map<String, double> restricted;

  bool get hasCounters => restricted.isNotEmpty;

  /// Everything held in this wallet, restricted credit included.
  double get total =>
      restricted.values.fold<double>(general, (sum, value) => sum + value);

  /// What an order at [counterKey] can spend: its restricted credit first,
  /// then the general credit. A balance below zero counts as nothing.
  double spendableAt(String counterKey) =>
      _positive(restricted[counterKey] ?? 0) + _positive(general);

  static double _positive(double value) => value > 0 ? value : 0;
}

/// [WalletBreakdown] for the wallet [shopKey] spends from.
WalletBreakdown walletBreakdownOf(
  String shopKey,
  Map<String, double> balances,
  List<CanteenShop> shops,
) {
  final walletKey = walletKeyOf(shopKey, shops);
  return WalletBreakdown(
    walletKey: walletKey,
    general: balances[walletKey] ?? 0,
    restricted: {
      for (final counter in countersOf(walletKey, shops))
        counter.shopKey: balances[counter.shopKey] ?? 0,
    },
  );
}

/// One wallet bucket's share of paying a shop's order.
class WalletDebit {
  const WalletDebit({required this.bucket, required this.amount});

  /// The bucket's key: a counter's (its restricted credit) or the canteen's
  /// (general credit), or a shop's only wallet.
  final String bucket;
  final double amount;

  @override
  bool operator ==(Object other) =>
      other is WalletDebit && other.bucket == bucket && other.amount == amount;

  @override
  int get hashCode => Object.hash(bucket, amount);

  @override
  String toString() => 'WalletDebit($bucket, $amount)';
}

/// How a cart is paid, mirroring the server's checkout: each shop's basket
/// ([shopTotals], in cart order) spends its own wallet — a counter's
/// restricted credit — first, then, for a counter, its canteen's general
/// credit, which the baskets share. Returns the debits per basket, or the
/// index of the first basket the wallet cannot cover as `failedAt`.
({List<List<WalletDebit>> debits, int? failedAt}) planWalletDebits(
  List<({String shop, double total})> shopTotals,
  Map<String, double> balances,
  List<CanteenShop> shops,
) {
  int paise(double value) => (value * 100).round();
  final left = {
    for (final entry in balances.entries) entry.key: paise(entry.value),
  };
  final plans = <List<WalletDebit>>[];
  for (var index = 0; index < shopTotals.length; index++) {
    final basket = shopTotals[index];
    final parent = walletKeyOf(basket.shop, shops);
    var remaining = paise(basket.total);
    final plan = <WalletDebit>[];
    for (final bucket in [basket.shop, if (parent != basket.shop) parent]) {
      if (remaining <= 0) break;
      final available = (left[bucket] ?? 0) > 0 ? left[bucket]! : 0;
      final take = available < remaining ? available : remaining;
      if (take > 0) {
        plan.add(WalletDebit(bucket: bucket, amount: take / 100));
        remaining -= take;
        left[bucket] = (left[bucket] ?? 0) - take;
      }
    }
    if (remaining > 0) return (debits: plans, failedAt: index);
    plans.add(plan);
  }
  return (debits: plans, failedAt: null);
}

/// Laundry charges are raised by the one laundry counter the API knows.
const laundryChargeShopKey = 'mec-laundry';

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

  /// [quantity] at the item's recorded cost price; null when none is recorded.
  double? get recordedCostTotal {
    final cost = item.recordedCost;
    return cost == null ? null : cost * quantity;
  }
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
    this.shopKey,
  });

  final String id;

  /// The shop the order was placed with, as the server resolved it. Older
  /// payloads leave it out; [storeKey] then falls back to the lines.
  final String? shopKey;

  /// The raw store key this order belongs to — possibly a legacy one such as
  /// `classic`; [resolveShopKey] maps it onto a configured shop.
  String? get storeKey {
    final key = shopKey?.trim();
    if (key != null && key.isNotEmpty) return key;
    return lines.isEmpty ? null : lines.first.item.effectiveShopKey;
  }

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

  /// What a pickup-QR scan did, for the counter's confirmation message.
  String get scanSummary {
    if (status == CanteenOrderStatus.completed) {
      return 'Order #$displayId delivered';
    }
    final parts = [
      for (var i = 0; i < lines.length; i++)
        '${lines[i].item.name} ${switch (lineStatus(i)) {
          CanteenOrderStatus.completed => 'delivered',
          CanteenOrderStatus.preparing => 'preparing',
          CanteenOrderStatus.ready => 'ready to serve',
          _ => 'pending',
        }}',
    ];
    return 'Order #$displayId · ${parts.join(' · ')}';
  }

  /// Where the next pickup-QR scan takes the order: instant food is handed
  /// over at once, prepared food moves one step per scan.
  CanteenOrder afterScan() {
    var order = this;
    for (var i = 0; i < lines.length; i++) {
      final current = order.lineStatus(i);
      if (current == CanteenOrderStatus.completed) continue;
      final next = lines[i].item.isInstant
          ? CanteenOrderStatus.completed
          : (current.nextServiceStep ?? CanteenOrderStatus.completed);
      order = order.withLineStatus(i, next);
    }
    return order;
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
      shopKey: shopKey,
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
        shopKey: shopKey,
      );

  int get itemCount => lines.fold(0, (total, line) => total + line.quantity);

  bool get isInstantOnly =>
      lines.isNotEmpty && lines.every((line) => line.item.isInstant);

  /// What the items cost the shop, from each item's recorded cost price;
  /// null when any item has none (or the order carries no item details) —
  /// never an estimate.
  double? get recordedCost {
    if (lines.isEmpty) return null;
    var sum = 0.0;
    for (final line in lines) {
      final cost = line.recordedCostTotal;
      if (cost == null) return null;
      sum += cost;
    }
    return sum;
  }

  /// [total] less [recordedCost]; null when the cost is not recorded.
  double? get recordedProfit {
    final cost = recordedCost;
    return cost == null ? null : total - cost;
  }
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
    this.walletScope,
    this.counterShopKey,
  });

  final String id;

  /// The wallet bucket the row moved: a shop's own wallet, a canteen's
  /// general credit, or a counter's restricted credit (the counter's key).
  final String shopKey;

  /// `all` (credit any counter of the canteen accepts) or the counter the
  /// credit is restricted to. Older rows leave it out.
  final String? walletScope;

  /// The counter a purchase or refund was at, when the server reports it.
  final String? counterShopKey;
  final WalletTransactionType type;
  final double amount;
  final String description;
  final DateTime createdAt;

  /// The ledger's own kind (`order_debit`, `online_top_up`, `manual_top_up`,
  /// `refund`, `manual_debit` for an accounts deduction), when the source
  /// reports it.
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

/// Shown to shop staff whose role is set but who have no counter yet.
const unassignedCounterFallbackMessage =
    "You're not assigned to a counter yet. Ask the admin to add you to a shop.";

class CanteenStore {
  const CanteenStore({
    required this.user,
    this.walletBalances = const {},
    required this.menu,
    required this.orders,
    required this.walletTransactions,
    this.shops = const [],
    this.assignedShopKeys = const [],
    this.assignedShops = const [],
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
    this.shopAssignmentPending = false,
    this.shopAssignmentMessage,
  });

  final CanteenUser user;
  final Map<String, double> walletBalances;
  final List<CanteenMenuItem> menu;
  final List<CanteenOrder> orders;
  final List<WalletTransaction> walletTransactions;
  final List<CanteenShop> shops;
  final List<String> assignedShopKeys;

  /// The capacity in which this person works each of [assignedShopKeys].
  /// Older servers do not send it; every assigned shop then counts as run in
  /// whatever capacity the person's grants allow.
  final List<ShopAssignment> assignedShops;
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

  /// The person holds shop-staff grants but works no counter yet. Their work
  /// screens say so instead of an empty queue that looks like a quiet day.
  final bool shopAssignmentPending;

  /// The server's wording for [shopAssignmentPending], when it sends one.
  final String? shopAssignmentMessage;

  /// What to tell shop staff with no counter.
  String get unassignedCounterMessage =>
      shopAssignmentMessage ?? unassignedCounterFallbackMessage;

  CanteenStore copyWith({
    Map<String, double>? walletBalances,
    List<CanteenOrder>? orders,
    List<WalletTransaction>? walletTransactions,
    List<CanteenMenuItem>? menu,
    List<CanteenShop>? shops,
    List<String>? assignedShopKeys,
    List<ShopAssignment>? assignedShops,
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
      assignedShops: assignedShops ?? this.assignedShops,
      canManage: canManage,
      canManageMenu: canManageMenu,
      canConfigureShops: canConfigureShops,
      staffState: staffState ?? this.staffState,
      analytics: analytics ?? this.analytics,
      laundryPricePerKg: laundryPricePerKg ?? this.laundryPricePerKg,
      laundryCharges: laundryCharges ?? this.laundryCharges,
      hasPin: hasPin ?? this.hasPin,
      hasPinHint: hasPinHint ?? this.hasPinHint,
      shopAssignmentPending: shopAssignmentPending,
      shopAssignmentMessage: shopAssignmentMessage,
    );
  }
}

/// What the signed-in person does at each shop, decided by scope — their
/// assignments and grants — never by a role name or an email address.
extension CanteenStoreCounterScope on CanteenStore {
  /// `owner` or `captain` at [shopKey]; null when not assigned there.
  String? assignmentRoleAt(String shopKey) {
    for (final assignment in assignedShops) {
      if (assignment.shopKey == shopKey) return assignment.role;
    }
    if (assignedShopKeys.contains(shopKey)) {
      // An older server: the grants say what the person can do there.
      return canManageMenu ? 'owner' : 'captain';
    }
    return null;
  }

  /// Whether this person may change [shopKey]'s menu: its owner, or someone
  /// overseeing the campus's shops who does not work that counter.
  bool canEditMenuOf(String shopKey) {
    if (!canManageMenu) return false;
    final role = assignmentRoleAt(shopKey);
    if (role != null) return role == 'owner';
    return canConfigureShops;
  }

  /// Whether this person has an owner's work: a shop whose menu they run,
  /// or the campus's shops to oversee. Counter staff who own nothing — even
  /// with owner grants from elsewhere — run the captain's queue.
  bool get hasOwnerWork {
    if (canConfigureShops) return true;
    if (!canManageMenu) return false;
    if (assignedShopKeys.isEmpty) return true;
    return assignedShopKeys.any((key) => assignmentRoleAt(key) == 'owner');
  }

  /// The shop an order was placed with, as a configured shop key.
  String orderShopKey(CanteenOrder order) =>
      resolveShopKey(order.storeKey, shops);

  /// The shop a menu item is sold by, as a configured shop key.
  String itemShopKey(CanteenMenuItem item) =>
      resolveShopKey(item.effectiveShopKey, shops);

  /// The first active shop of [category] (`canteen`, `stationery`,
  /// `laundry`), for links that open "the laundry" rather than one shop.
  String? firstShopKeyOf(String category) =>
      firstShopKeyOfCategory(shops, category);

  /// The wallet to open when no shop was chosen: the campus's first canteen,
  /// else its first shop. Never a hard-coded key the campus may not have.
  String get defaultWalletShopKey {
    final canteen = firstShopKeyOf('canteen');
    if (canteen != null) return canteen;
    for (final shop in shops) {
      if (shop.isActive) return shop.shopKey;
    }
    return walletBalances.keys.isEmpty
        ? 'canteen'
        : walletBalances.keys.first;
  }
}

/// What one shop's wallet paid for and how its balance moved.
///
/// Every shop keeps its own prepaid wallet, so each wallet's history holds
/// only that shop's rows — legacy store keys are mapped with
/// [resolveShopKey], never guessed.
extension CanteenStoreWalletScope on CanteenStore {
  bool _isMine(String? ownerId) {
    final me = user.id;
    return ownerId == null || me == null || ownerId == me;
  }

  /// The signed-in person's own orders placed with [shopKey]'s shop. Staff
  /// payloads also carry their counter's queue; those are not theirs.
  List<CanteenOrder> walletOrdersFor(String shopKey) => [
    for (final order in orders)
      if (_isMine(order.customerUserId) &&
          _sameWallet(order.storeKey, shopKey))
        order,
  ];

  /// A canteen's wallet history includes its counters' restricted credit.
  List<WalletTransaction> walletTransactionsFor(String shopKey) => [
    for (final transaction in walletTransactions)
      if (_sameWallet(transaction.shopKey, shopKey)) transaction,
  ];

  bool _sameWallet(String? rowKey, String walletKey) {
    if (rowKey == null || rowKey.trim().isEmpty) return false;
    return walletKeyOf(resolveShopKey(rowKey, shops), shops) ==
        walletKeyOf(resolveShopKey(walletKey, shops), shops);
  }

  /// The wallet [shopKey] spends from: its canteen when it is a counter.
  String walletKeyFor(String shopKey) =>
      walletKeyOf(resolveShopKey(shopKey, shops), shops);

  /// The wallet behind [shopKey], split into general and counter-only credit.
  WalletBreakdown walletBreakdownFor(String shopKey) =>
      walletBreakdownOf(resolveShopKey(shopKey, shops), walletBalances, shops);

  /// Laundry charges this person claimed, when [shopKey] is the laundry's
  /// wallet. An operator's payload also lists unclaimed and others' charges.
  List<LaundryCharge> walletLaundryChargesFor(String shopKey) {
    if (!sameShop(laundryChargeShopKey, shopKey, shops)) return const [];
    return [
      for (final charge in laundryCharges)
        if (charge.claimedBy == null
            ? charge.status != LaundryChargeStatus.pending
            : _isMine(charge.claimedBy))
          charge,
    ];
  }

  /// The configured shop behind [shopKey], when there is one.
  CanteenShop? walletShopFor(String shopKey) {
    final resolved = resolveShopKey(shopKey, shops);
    for (final shop in shops) {
      if (shop.shopKey == resolved) return shop;
    }
    return null;
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
    this.cancelledAt,
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

  /// When the counter voided the charge, if it did.
  final DateTime? cancelledAt;

  /// Whether the charge still waits on the student: the QR stays with the
  /// counter until it is paid or cancelled.
  bool get isOpen =>
      status == LaundryChargeStatus.pending ||
      status == LaundryChargeStatus.claimed;

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
        cancelledAt: cancelledAt,
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
      'Buy from the canteen, stationery and laundry with your wallet',
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
