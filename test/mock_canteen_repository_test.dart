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
    expect(
      store.menu.map((item) => item.category).toSet(),
      MenuCategory.values.toSet(),
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
      fulfilmentMode: FulfilmentMode.dineIn,
    );

    expect(result.order.total, item.price * 2);
    expect(result.order.status, CanteenOrderStatus.ready);
    expect(result.balance, before.walletBalance - item.price * 2);
    expect(result.transaction.type, WalletTransactionType.debit);
  });

  test('rejects top-up amounts outside the configured range', () async {
    expect(repository.topUpWallet(25), throwsA(isA<CanteenException>()));
  });

  test('rejects an order when wallet balance is insufficient', () async {
    final store = await repository.loadStore();
    final item = store.menu.first;

    expect(
      repository.placeOrder(
        lines: [CartLine(item: item, quantity: 100)],
        fulfilmentMode: FulfilmentMode.pickup,
      ),
      throwsA(isA<CanteenException>()),
    );
  });
}
