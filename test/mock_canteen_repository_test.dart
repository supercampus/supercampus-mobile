import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/mock_canteen_repository.dart';

void main() {
  late MockCanteenRepository repository;

  setUp(() {
    repository = MockCanteenRepository(
      studentName: 'Test Student',
      email: 'student@example.com',
    );
  });

  test('loads the menu, wallet and order history', () async {
    final store = await repository.loadStore();

    expect(store.user.name, 'Test Student');
    expect(store.menu.length, greaterThanOrEqualTo(10));
    // Every storefront has stock, so each of the three tabs has something to
    // show rather than opening onto an empty list.
    expect(
      store.menu.map((item) => item.store).toSet(),
      MenuStore.values.toSet(),
    );
    expect(store.walletBalance, greaterThan(0));
    expect(store.orders, isNotEmpty);
    expect(store.walletTransactions, isNotEmpty);
  });

  test('top-up credits the wallet', () async {
    final before = await repository.loadStore();
    final result = await repository.topUpWallet(500);

    expect(result.balance, before.walletBalance + 500);
    expect(result.transaction.type, WalletTransactionType.credit);
  });

  test('places an order and deducts its total', () async {
    final before = await repository.loadStore();
    final item = before.menu.first;
    final result = await repository.placeOrder(
      lines: [CartLine(item: item, quantity: 2)],
    );

    // One shop in the cart, so one order and one debit.
    expect(result.orders, hasLength(1));
    expect(result.order.total, item.price * 2);
    expect(result.order.status, CanteenOrderStatus.ready);
    expect(result.balance, before.walletBalance - item.price * 2);
    expect(result.transactions.single.type, WalletTransactionType.debit);
  });

  test('a cart spanning shops becomes one order per shop', () async {
    final before = await repository.loadStore();
    final classic = before.menu.firstWhere(
      (item) => item.store == MenuStore.classic,
    );
    final bites = before.menu.firstWhere(
      (item) => item.store == MenuStore.bites,
    );

    final result = await repository.placeOrder(
      lines: [
        CartLine(item: classic, quantity: 1),
        CartLine(item: bites, quantity: 1),
      ],
    );

    // Each shop hands over its own food, so each gets its own order and QR.
    expect(result.orders, hasLength(2));
    expect(result.spansMultipleShops, isTrue);
    expect(
      result.orders.map((order) => order.lines.single.item.store).toSet(),
      {MenuStore.classic, MenuStore.bites},
    );

    // One wallet: the balance falls by the whole cart, debited per shop.
    expect(result.transactions, hasLength(2));
    expect(result.balance, before.walletBalance - classic.price - bites.price);
    expect(
      result.transactions.fold<double>(0, (sum, t) => sum + t.amount),
      classic.price + bites.price,
    );
  });

  test('rejects top-up amounts outside the configured range', () async {
    expect(repository.topUpWallet(25), throwsA(isA<CanteenException>()));
  });

  test('rejects an order when wallet balance is insufficient', () async {
    final store = await repository.loadStore();
    final item = store.menu.first;

    expect(
      repository.placeOrder(lines: [CartLine(item: item, quantity: 100)]),
      throwsA(isA<CanteenException>()),
    );
  });
}
