import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_captain_home.dart';

CanteenMenuItem item(String id, String name) => CanteenMenuItem(
  id: id,
  name: name,
  description: '',
  category: 'Food',
  price: 50,
  isVegetarian: true,
);

CanteenOrder order(String number, String? customer, List<CanteenMenuItem> items) =>
    CanteenOrder(
      id: 'o-$number',
      orderNumber: number,
      customerName: customer,
      lines: [for (final i in items) CartLine(item: i, quantity: 1)],
      total: 50.0 * items.length,
      status: CanteenOrderStatus.pending,
      fulfilmentMode: FulfilmentMode.pickup,
      createdAt: DateTime(2026, 9, 28, 13),
    );

void main() {
  test('orders are grouped per customer in queue order, one entry per item', () {
    final mojito = item('m', 'Blue Diamond Mojito');
    final rice = item('r', 'Chicken Fried Rice');
    final shake = item('s', 'Belgian Chocolate Shake');
    final groups = groupOrdersByCustomer([
      order('0063', 'Sahana S', [mojito, shake]),
      order('0059', 'Vishnu S', [rice]),
      order('0058', 'Vishnu S', [mojito]),
      order('0057', 'Vishnu S', [shake]),
      order('0056', null, [shake]),
    ]);

    expect(groups.map((g) => g.customer), ['Sahana S', 'Vishnu S', 'Campus user']);
    expect(groups[1].orders, hasLength(3));

    // Sahana's single order with two items gives two item entries that keep
    // the same order number.
    final sahanaItems = groups[0].items;
    expect(sahanaItems, hasLength(2));
    expect(sahanaItems.map((e) => e.$1.orderNumber), ['0063', '0063']);
    expect(sahanaItems.map((e) => e.$2.item.name), [
      'Blue Diamond Mojito',
      'Belgian Chocolate Shake',
    ]);
  });
}
