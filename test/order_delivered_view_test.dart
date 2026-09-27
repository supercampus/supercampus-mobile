import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/widgets/order_delivered_view.dart';

void main() {
  final order = CanteenOrder(
    id: 'o-55',
    orderNumber: '0055',
    lines: const [
      CartLine(
        item: CanteenMenuItem(
          id: 'm1',
          name: 'Blue Diamond Mojito',
          description: '',
          category: 'Beverages',
          price: 1,
          isVegetarian: true,
        ),
        quantity: 1,
      ),
    ],
    total: 1,
    status: CanteenOrderStatus.completed,
    fulfilmentMode: FulfilmentMode.pickup,
    createdAt: DateTime(2026, 9, 26, 16, 50),
  );

  for (final theme in [AppTheme.light, AppTheme.dark]) {
    testWidgets(
      'delivered view is readable on the white pickup page '
      '(${theme.brightness.name} app theme)',
      (tester) async {
        var done = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: ColoredBox(
                color: Colors.white,
                child: OrderDeliveredView(order: order, onDone: () => done++),
              ),
            ),
          ),
        );

        final title = tester.widget<Text>(find.text('Your order is delivered'));
        // Dark ink, never white-on-white.
        expect(title.style!.color!.computeLuminance(), lessThan(0.1));
        expect(find.text('Order #0055'), findsOneWidget);
        expect(find.text('Blue Diamond Mojito'), findsOneWidget);
        expect(find.text('Delivered'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('order-delivered-done')));
        expect(done, 1);
      },
    );
  }
}
