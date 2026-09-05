import 'dart:convert';
import 'dart:typed_data';

import 'canteen_models.dart';
import 'canteen_repository.dart';

class MockCanteenRepository implements CanteenRepository {
  MockCanteenRepository({required this.studentName, required this.email});

  final String studentName;
  final String email;

  double _balance = 820;
  late final List<CanteenMenuItem> _menu = _seedMenu();
  late final List<CanteenOrder> _orders = _seedOrders();
  late final List<WalletTransaction> _transactions = _seedTransactions();
  final List<LaundryCharge> _laundryCharges = [];
  double _laundryPrice = 50;

  @override
  Future<CanteenStore> loadStore() async {
    await Future<void>.delayed(const Duration(milliseconds: 420));
    return CanteenStore(
      user: CanteenUser(
        name: studentName,
        email: email,
        rollNumber: 'MEC26CS041',
        department: 'Computer Science',
      ),
      walletBalance: _balance,
      shops: const [
        CanteenShop(
          id: 'shop-classic',
          shopKey: 'classic',
          name: 'Campus Classic',
          category: 'canteen',
        ),
        CanteenShop(
          id: 'shop-bites',
          shopKey: 'bites',
          name: 'Quick Bites',
          category: 'canteen',
        ),
        CanteenShop(
          id: 'shop-stationery',
          shopKey: 'stationery',
          name: 'Stationery Store',
          category: 'stationery',
        ),
        CanteenShop(
          id: 'shop-laundry',
          shopKey: 'mec-laundry',
          name: 'Campus Laundry',
          category: 'laundry',
        ),
      ],
      assignedShopKeys: const ['classic', 'bites', 'stationery'],
      menu: List.unmodifiable(_menu),
      orders: List.unmodifiable(_orders),
      walletTransactions: List.unmodifiable(_transactions),
      laundryPricePerKg: _laundryPrice,
      laundryCharges: List.unmodifiable(_laundryCharges),
    );
  }

  @override
  Future<void> updateOrderStatus(
    String orderId,
    CanteenOrderStatus status, {
    String? reason,
  }) async {
    final index = _orders.indexWhere((order) => order.id == orderId);
    if (index >= 0) _orders[index] = _orders[index].copyWith(status: status);
  }

  @override
  Future<void> scanOrder(String qrPayload) async {
    final index = _orders.indexWhere(
      (order) => order.qrPayload == qrPayload || order.id == qrPayload,
    );
    if (index < 0) throw const CanteenException('Order QR is invalid.');
    _orders[index] = _orders[index].copyWith(
      status: CanteenOrderStatus.completed,
    );
  }

  @override
  Future<CanteenStaffState> updateStaffState({
    required CanteenStaffMode mode,
    bool? shopOpen,
  }) async => CanteenStaffState(mode: mode, shopOpen: shopOpen);

  @override
  Future<CanteenMenuItem> saveMenuItem(
    CanteenMenuItem item, {
    required bool create,
  }) async {
    final saved = create
        ? item.copyWith(id: 'menu-${DateTime.now().microsecondsSinceEpoch}')
        : item;
    final index = _menu.indexWhere((value) => value.id == saved.id);
    if (index < 0) {
      _menu.add(saved);
    } else {
      _menu[index] = saved;
    }
    return saved;
  }

  @override
  Future<void> deleteMenuItem(String itemId) async =>
      _menu.removeWhere((item) => item.id == itemId);

  @override
  Future<String> uploadMedia(
    Uint8List bytes, {
    required String filename,
  }) async => 'data:image/png;base64,${base64Encode(bytes)}';

  @override
  Future<double> updateLaundryPrice(double pricePerKg) async =>
      _laundryPrice = pricePerKg;

  @override
  Future<LaundryCharge> createLaundryCharge({
    required LaundryServiceType serviceType,
    required String name,
    required String description,
    required double quantity,
    double? price,
  }) async {
    final total = serviceType == LaundryServiceType.wash
        ? quantity * _laundryPrice
        : price ?? 0;
    final charge = LaundryCharge(
      id: 'laundry-${DateTime.now().microsecondsSinceEpoch}',
      serviceType: serviceType,
      name: name,
      description: description,
      quantity: quantity,
      unitLabel: serviceType == LaundryServiceType.wash ? 'kg' : 'clothes',
      unitPrice: serviceType == LaundryServiceType.wash
          ? _laundryPrice
          : total / quantity,
      total: total,
      status: LaundryChargeStatus.pending,
      createdAt: DateTime.now(),
      qrPayload:
          'supercampus://laundry/mock-${DateTime.now().microsecondsSinceEpoch}',
    );
    _laundryCharges.insert(0, charge);
    return charge;
  }

  @override
  Future<LaundryCharge> claimLaundryCharge(String qrPayload) async {
    final index = _laundryCharges.indexWhere(
      (charge) => charge.qrPayload == qrPayload,
    );
    if (index < 0) throw const CanteenException('Laundry QR is invalid.');
    final charge = _laundryCharges[index].copyWith(
      status: LaundryChargeStatus.claimed,
    );
    _laundryCharges[index] = charge;
    return charge;
  }

  @override
  Future<LaundryPaymentResult> payLaundryCharge(String chargeId) async {
    final index = _laundryCharges.indexWhere((charge) => charge.id == chargeId);
    if (index < 0) throw const CanteenException('Laundry charge not found.');
    final charge = _laundryCharges[index];
    if (_balance < charge.total) {
      throw const CanteenException('Wallet balance is insufficient.');
    }
    _balance -= charge.total;
    final paid = charge.copyWith(
      status: LaundryChargeStatus.paid,
      paidAt: DateTime.now(),
    );
    _laundryCharges[index] = paid;
    final transaction = WalletTransaction(
      id: 'laundry-txn-${DateTime.now().microsecondsSinceEpoch}',
      type: WalletTransactionType.debit,
      amount: charge.total,
      description: 'Campus Laundry payment',
      createdAt: DateTime.now(),
    );
    _transactions.insert(0, transaction);
    return LaundryPaymentResult(
      balance: _balance,
      charge: paid,
      transaction: transaction,
    );
  }

  @override
  Future<WalletTopUpResult> topUpWallet(double amount) async {
    if (amount < 50 || amount > 5000) {
      throw const CanteenException('Top-up must be between ₹50 and ₹5,000.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 800));
    _balance += amount;
    final transaction = WalletTransaction(
      id: 'txn-${DateTime.now().millisecondsSinceEpoch}',
      type: WalletTransactionType.credit,
      amount: amount,
      description: 'Wallet top-up',
      createdAt: DateTime.now(),
    );
    _transactions.insert(0, transaction);
    return WalletTopUpResult(balance: _balance, transaction: transaction);
  }

  @override
  Future<OrderPlacementResult> placeOrder({
    required List<CartLine> lines,
  }) async {
    if (lines.isEmpty) throw const CanteenException('Your cart is empty.');
    final total = lines.fold<double>(0, (sum, line) => sum + line.total);
    if (_balance < total) {
      throw const CanteenException(
        'Insufficient wallet balance. Top up and try again.',
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 950));

    // Each shop hands its own order over at its own counter, so a cart that
    // spans shops becomes one order — and one QR — per shop. The wallet is
    // shared, so the balance moves once per shop against the same purse.
    final byShop = <String, List<CartLine>>{};
    for (final line in lines) {
      byShop.putIfAbsent(line.item.effectiveShopKey, () => []).add(line);
    }

    final placedOrders = <CanteenOrder>[];
    final placedTransactions = <WalletTransaction>[];
    final timestamp = DateTime.now();
    var sequence = 0;

    for (final entry in byShop.entries) {
      final shopLines = entry.value;
      final shopTotal = shopLines.fold<double>(0, (sum, l) => sum + l.total);
      _balance -= shopTotal;

      final order = CanteenOrder(
        id: 'ORD-${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}-${(_orders.length + 241 + sequence).toString().padLeft(4, '0')}',
        lines: List.unmodifiable(shopLines),
        total: shopTotal,
        status: CanteenOrderStatus.ready,
        fulfilmentMode: FulfilmentMode.pickup,
        createdAt: timestamp,
        tokenNumber: 42 + _orders.length + sequence,
        qrPayload: 'QR-${timestamp.microsecondsSinceEpoch}-$sequence',
      );
      final transaction = WalletTransaction(
        id: 'txn-${timestamp.millisecondsSinceEpoch}-$sequence',
        type: WalletTransactionType.debit,
        amount: shopTotal,
        description: '${entry.key} order - ${order.id}',
        createdAt: timestamp,
      );

      _orders.insert(0, order);
      _transactions.insert(0, transaction);
      placedOrders.add(order);
      placedTransactions.add(transaction);
      sequence++;
    }

    return OrderPlacementResult(
      balance: _balance,
      orders: placedOrders,
      transactions: placedTransactions,
    );
  }

  /// Mirrors the storefronts in the product design so mock mode reads like the
  /// real counter: Classic is the meals window, Bites the snacks and drinks
  /// counter, Stationery the campus shop.
  List<CanteenMenuItem> _seedMenu() {
    return const [
      CanteenMenuItem(
        id: 'classic-parotta',
        name: '3 Parotta with Veg Kurma',
        description: 'Three parottas with vegetable kurma',
        store: MenuStore.classic,
        category: 'meals',
        price: 79,
        isVegetarian: true,
        isPopular: true,
        isInstant: true,
      ),
      CanteenMenuItem(
        id: 'classic-idli',
        name: 'Idli Podi',
        description: 'Idlis tossed with podi and oil',
        store: MenuStore.classic,
        category: 'meals',
        price: 10,
        isVegetarian: true,
        isInstant: true,
      ),
      CanteenMenuItem(
        id: 'classic-dosa',
        name: 'Kal Dosa',
        description: 'Soft griddle dosa with chutney',
        store: MenuStore.classic,
        category: 'meals',
        price: 59,
        isVegetarian: true,
        isInstant: true,
      ),
      // No image on purpose: the menu falls back to a category tile.
      CanteenMenuItem(
        id: 'classic-kuska',
        name: 'Kuska',
        description: 'Seasoned rice, served plain',
        store: MenuStore.classic,
        category: 'meals',
        price: 99,
        isVegetarian: true,
      ),
      CanteenMenuItem(
        id: 'bites-banana-cake',
        name: 'Banana cake',
        description: 'Freshly baked banana loaf',
        store: MenuStore.bites,
        category: 'snacks',
        price: 25,
        isVegetarian: true,
        isInstant: true,
      ),
      CanteenMenuItem(
        id: 'bites-vanilla-ice-cream',
        name: 'Bean Vanilla Ice Cream',
        description: 'Two scoops of vanilla bean',
        store: MenuStore.bites,
        category: 'snacks',
        price: 59,
        isVegetarian: true,
        isInstant: true,
      ),
      CanteenMenuItem(
        id: 'bites-vanilla-shake',
        name: 'Bean Vanilla Shake',
        description: 'Vanilla bean shake, whipped',
        store: MenuStore.bites,
        category: 'drinks',
        price: 89,
        isVegetarian: true,
      ),
      CanteenMenuItem(
        id: 'bites-chocolate-shake',
        name: 'Belgian Chocolate Shake',
        description: 'Belgian chocolate, blended thick',
        store: MenuStore.bites,
        category: 'drinks',
        price: 89,
        isVegetarian: true,
      ),
      CanteenMenuItem(
        id: 'bites-blue-mojito',
        name: 'Blue Diamond Mojito',
        description: 'Mint and lime over crushed ice',
        store: MenuStore.bites,
        category: 'drinks',
        price: 59,
        isVegetarian: true,
      ),
      CanteenMenuItem(
        id: 'stationery-shampoo',
        name: 'Shampoo Sachet',
        description: 'Single-use sachet',
        store: MenuStore.stationery,
        category: 'Hair Care & Shampoo',
        price: 5,
        isVegetarian: true,
        isInstant: true,
      ),
      CanteenMenuItem(
        id: 'stationery-soap',
        name: 'Bathing Soap',
        description: 'Standard bar',
        store: MenuStore.stationery,
        category: 'Soaps & Detergents',
        price: 40,
        isVegetarian: true,
      ),
      CanteenMenuItem(
        id: 'stationery-notebook',
        name: 'Long Notebook',
        description: '200 pages, ruled',
        store: MenuStore.stationery,
        category: 'Books & Paper',
        price: 60,
        isVegetarian: true,
      ),
    ];
  }

  List<CanteenOrder> _seedOrders() {
    final now = DateTime.now();
    return [
      CanteenOrder(
        id: 'ORD-20260802-0221',
        lines: [CartLine(item: _menu[0], quantity: 1)],
        total: 79,
        status: CanteenOrderStatus.completed,
        fulfilmentMode: FulfilmentMode.dineIn,
        createdAt: DateTime(now.year, now.month, now.day - 1, 20, 29),
        tokenNumber: 31,
      ),
      CanteenOrder(
        id: 'ORD-20260729-0184',
        lines: [
          CartLine(item: _menu[5], quantity: 2),
          CartLine(item: _menu[8], quantity: 1),
        ],
        total: 100,
        status: CanteenOrderStatus.completed,
        fulfilmentMode: FulfilmentMode.pickup,
        createdAt: DateTime(now.year, now.month, now.day - 5, 16, 12),
        tokenNumber: 18,
      ),
    ];
  }

  List<WalletTransaction> _seedTransactions() {
    final now = DateTime.now();
    return [
      WalletTransaction(
        id: 'txn-1',
        type: WalletTransactionType.debit,
        amount: 79,
        description: 'Order payment · ORD-20260802-0221',
        createdAt: DateTime(now.year, now.month, now.day - 1, 20, 29),
      ),
      WalletTransaction(
        id: 'txn-2',
        type: WalletTransactionType.credit,
        amount: 500,
        description: 'Wallet top-up',
        createdAt: DateTime(now.year, now.month, now.day - 4, 10, 18),
      ),
      WalletTransaction(
        id: 'txn-3',
        type: WalletTransactionType.debit,
        amount: 100,
        description: 'Order payment · ORD-20260729-0184',
        createdAt: DateTime(now.year, now.month, now.day - 5, 16, 12),
      ),
    ];
  }
}
