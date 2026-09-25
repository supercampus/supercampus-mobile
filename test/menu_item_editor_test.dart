import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/canteen_menu_item_editor_screen.dart';

void main() {
  testWidgets('CanteenMenuItemEditorScreen displays Cost & Selling Price and calculates profit', (
    tester,
  ) async {
    const shops = [
      CanteenShop(
        id: 'shop-1',
        shopKey: 'classic',
        name: 'Campus Canteen',
        category: 'food',
      ),
    ];

    CanteenMenuItem? savedResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<CanteenMenuItem>(
                  MaterialPageRoute(
                    builder: (_) => CanteenMenuItemEditorScreen(
                      shops: shops,
                      selectedShopKey: 'classic',
                      onUploadMedia: (bytes, filename) async => 'http://example.com/img.png',
                    ),
                  ),
                );
                savedResult = result;
              },
              child: const Text('Open Editor'),
            ),
          ),
        ),
      ),
    );

    // Open the editor page
    await tester.tap(find.text('Open Editor'));
    await tester.pumpAndSettle();

    // Verify it is on the separate page titled "Add menu item"
    expect(find.text('Add menu item'), findsOneWidget);
    expect(find.text('Pricing & Profit'), findsOneWidget);
    expect(find.text('Cost *'), findsOneWidget);
    expect(find.text('Selling Price *'), findsOneWidget);

    // Fill in Name
    await tester.enterText(find.widgetWithText(TextFormField, 'Item name *'), 'Special Dosa');

    // Fill in Cost (₹30) and Selling Price (₹50)
    await tester.enterText(find.widgetWithText(TextFormField, 'Cost *'), '30');
    await tester.enterText(find.widgetWithText(TextFormField, 'Selling Price *'), '50');
    await tester.pump();

    // Verify profit preview shows Estimated Profit: ₹20 and 40.0% margin
    expect(find.textContaining('Estimated Profit: ₹20'), findsOneWidget);
    expect(find.textContaining('40.0% margin'), findsOneWidget);

    // Tap Save button in AppBar
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Verify the returned item has correct cost, price, and profit
    expect(savedResult, isNotNull);
    expect(savedResult!.name, 'Special Dosa');
    expect(savedResult!.price, 50.0);
    expect(savedResult!.cost, 30.0);
    expect(savedResult!.profit, 20.0);
    expect(savedResult!.profitMargin, closeTo(0.40, 0.01));
  });
}
