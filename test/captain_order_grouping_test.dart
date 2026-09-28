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

CanteenMenuItem instant(String id, String name) => CanteenMenuItem(
  id: id,
  name: name,
  description: '',
  category: 'Drinks',
  price: 20,
  isVegetarian: true,
  isInstant: true,
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

  test('moving one item leaves the other items of the order where they are', () {
    final placed = order('0065', 'Vishnu S', [
      instant('w', 'Water bottle'),
      item('r', 'Chicken Fried Rice'),
    ]);

    // Instant food goes straight to delivered; prepared food starts preparing.
    expect(placed.nextLineStep(0), CanteenOrderStatus.completed);
    expect(placed.nextLineStep(1), CanteenOrderStatus.preparing);

    final waterOut = placed.withLineStatus(0, CanteenOrderStatus.completed);
    expect(waterOut.lineStatus(0), CanteenOrderStatus.completed);
    expect(waterOut.lineStatus(1), CanteenOrderStatus.pending);
    expect(waterOut.status.isActive, isTrue);

    final cooking = waterOut.withLineStatus(1, CanteenOrderStatus.preparing);
    expect(cooking.lineStatus(0), CanteenOrderStatus.completed);
    expect(cooking.lineStatus(1), CanteenOrderStatus.preparing);
    expect(cooking.nextLineStep(1), CanteenOrderStatus.ready);

    final ready = cooking.withLineStatus(1, CanteenOrderStatus.ready);
    expect(ready.status, CanteenOrderStatus.ready);
    final done = ready.withLineStatus(1, CanteenOrderStatus.completed);
    expect(done.status, CanteenOrderStatus.completed);

    // Delivered items drop out of the captain's dropdown.
    expect(
      groupOrdersByCustomer([cooking]).single.items.map((e) => e.$2.item.name),
      ['Chicken Fried Rice'],
    );
  });
}
