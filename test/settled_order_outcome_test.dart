import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/order_pickup_sheet.dart';

CanteenOrder _order(CanteenOrderStatus status) => CanteenOrder(
  id: 'o71',
  orderNumber: '71',
  lines: const [
    CartLine(
      item: CanteenMenuItem(
        id: 'boost',
        name: 'Boost',
        description: '',
        category: 'drinks',
        price: 1,
        isVegetarian: true,
      ),
      quantity: 1,
    ),
  ],
  total: 1,
  status: status,
  fulfilmentMode: FulfilmentMode.pickup,
  createdAt: DateTime(2026, 9, 28, 17, 25),
);

Future<void> _open(WidgetTester tester, CanteenOrder order) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: OrderPickupSheet(order: order))),
  );
  await tester.pump();
}

void main() {
  testWidgets('a rejected order shows its outcome, not a pickup QR', (
    tester,
  ) async {
    await _open(tester, _order(CanteenOrderStatus.rejected));

    expect(find.text('Your order was rejected'), findsOneWidget);
    expect(find.textContaining('refunded to your wallet'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('a cancelled order shows its outcome, not a pickup QR', (
    tester,
  ) async {
    await _open(tester, _order(CanteenOrderStatus.cancelled));

    expect(find.text('Your order was cancelled'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('an active order still shows its pickup QR', (tester) async {
    await _open(tester, _order(CanteenOrderStatus.pending));

    expect(find.byType(QrImageView), findsOneWidget);
    // Stop the sheet's status polling before the test ends.
    await tester.pumpWidget(const SizedBox());
  });
}
