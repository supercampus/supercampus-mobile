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
      menu: List.unmodifiable(_menu),
      orders: List.unmodifiable(_orders),
      walletTransactions: List.unmodifiable(_transactions),
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
    required FulfilmentMode fulfilmentMode,
  }) async {
    if (lines.isEmpty) throw const CanteenException('Your cart is empty.');
    final total = lines.fold<double>(0, (sum, line) => sum + line.total);
    if (_balance < total) {
      throw const CanteenException(
        'Insufficient wallet balance. Top up and try again.',
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 950));
    _balance -= total;
    final timestamp = DateTime.now();
    final order = CanteenOrder(
      id: 'ORD-${timestamp.year}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}-${(_orders.length + 241).toString().padLeft(4, '0')}',
      lines: List.unmodifiable(lines),
      total: total,
      status: CanteenOrderStatus.ready,
      fulfilmentMode: fulfilmentMode,
      createdAt: timestamp,
      tokenNumber: 42 + _orders.length,
    );
    final transaction = WalletTransaction(
      id: 'txn-${timestamp.millisecondsSinceEpoch}',
      type: WalletTransactionType.debit,
      amount: total,
      description: 'Order payment · ${order.id}',
      createdAt: timestamp,
    );
    _orders.insert(0, order);
    _transactions.insert(0, transaction);
    return OrderPlacementResult(
      balance: _balance,
      order: order,
      transaction: transaction,
    );
  }

  List<CanteenMenuItem> _seedMenu() {
    return const [
      CanteenMenuItem(
        id: 'meal-parotta',
        name: 'Parotta with Veg Kurma',
        description: '3 parottas with vegetable kurma',
        category: MenuCategory.meals,
        price: 79,
        isVegetarian: true,
        isPopular: true,
      ),
      CanteenMenuItem(
        id: 'meal-idli',
        name: 'Idli Podi',
        description: '4 idlis tossed with podi and oil',
        category: MenuCategory.meals,
        price: 30,
        isVegetarian: true,
        isPopular: true,
      ),
      CanteenMenuItem(
        id: 'meal-dosa',
        name: 'Kal Dosa',
        description: '2 soft dosas with sambar and chutney',
        category: MenuCategory.meals,
        price: 59,
        isVegetarian: true,
      ),
      CanteenMenuItem(
        id: 'meal-veg-rice',
        name: 'Veg Fried Rice',
        description: 'Wok-tossed rice with fresh vegetables',
        category: MenuCategory.meals,
        price: 70,
        isVegetarian: true,
      ),
      CanteenMenuItem(
        id: 'meal-chicken-rice',
        name: 'Chicken Fried Rice',
        description: 'Fried rice with boneless chicken',
        category: MenuCategory.meals,
        price: 95,
        isVegetarian: false,
        isPopular: true,
      ),
      CanteenMenuItem(
        id: 'snack-samosa',
        name: 'Vegetable Samosa',
        description: 'Crisp pastry with spiced potato filling',
        category: MenuCategory.snacks,
        price: 20,
        isVegetarian: true,
      ),
      CanteenMenuItem(
        id: 'snack-puff',
        name: 'Veg Puff',
        description: 'Flaky baked puff with vegetable filling',
        category: MenuCategory.snacks,
        price: 25,
        isVegetarian: true,
      ),
      CanteenMenuItem(
        id: 'snack-cake',
        name: 'Banana Cake',
        description: 'Soft house-baked banana loaf slice',
        category: MenuCategory.snacks,
        price: 30,
        isVegetarian: true,
      ),
      CanteenMenuItem(
        id: 'drink-coffee',
        name: 'Cold Coffee',
        description: 'Chilled creamy coffee',
        category: MenuCategory.drinks,
        price: 60,
        isVegetarian: true,
        isPopular: true,
      ),
      CanteenMenuItem(
        id: 'drink-lime',
        name: 'Fresh Lime Soda',
        description: 'Sweet, salt or mixed',
        category: MenuCategory.drinks,
        price: 35,
        isVegetarian: true,
      ),
      CanteenMenuItem(
        id: 'drink-rose',
        name: 'Rose Milk',
        description: 'Chilled milk with rose syrup',
        category: MenuCategory.drinks,
        price: 45,
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
