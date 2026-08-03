enum MenuCategory { meals, snacks, drinks }

extension MenuCategoryLabel on MenuCategory {
  String get label => switch (this) {
    MenuCategory.meals => 'Meals',
    MenuCategory.snacks => 'Snacks',
    MenuCategory.drinks => 'Drinks',
  };
}

class CanteenMenuItem {
  const CanteenMenuItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.isVegetarian,
    this.isPopular = false,
    this.isAvailable = true,
  });

  final String id;
  final String name;
  final String description;
  final MenuCategory category;
  final double price;
  final bool isVegetarian;
  final bool isPopular;
  final bool isAvailable;
}

class CartLine {
  const CartLine({required this.item, required this.quantity});

  final CanteenMenuItem item;
  final int quantity;

  double get total => item.price * quantity;
}

enum CanteenOrderStatus { preparing, ready, completed, cancelled }

extension CanteenOrderStatusLabel on CanteenOrderStatus {
  String get label => switch (this) {
    CanteenOrderStatus.preparing => 'Preparing',
    CanteenOrderStatus.ready => 'Ready for pickup',
    CanteenOrderStatus.completed => 'Completed',
    CanteenOrderStatus.cancelled => 'Cancelled',
  };

  bool get isActive =>
      this == CanteenOrderStatus.preparing || this == CanteenOrderStatus.ready;
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
  });

  final String id;
  final List<CartLine> lines;
  final double total;
  final CanteenOrderStatus status;
  final FulfilmentMode fulfilmentMode;
  final DateTime createdAt;
  final int? tokenNumber;

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
  });

  final CanteenUser user;
  final double walletBalance;
  final List<CanteenMenuItem> menu;
  final List<CanteenOrder> orders;
  final List<WalletTransaction> walletTransactions;

  CanteenStore copyWith({
    double? walletBalance,
    List<CanteenOrder>? orders,
    List<WalletTransaction>? walletTransactions,
  }) {
    return CanteenStore(
      user: user,
      walletBalance: walletBalance ?? this.walletBalance,
      menu: menu,
      orders: orders ?? this.orders,
      walletTransactions: walletTransactions ?? this.walletTransactions,
    );
  }
}

class WalletTopUpResult {
  const WalletTopUpResult({required this.balance, required this.transaction});

  final double balance;
  final WalletTransaction transaction;
}

class OrderPlacementResult {
  const OrderPlacementResult({
    required this.balance,
    required this.order,
    required this.transaction,
  });

  final double balance;
  final CanteenOrder order;
  final WalletTransaction transaction;
}
