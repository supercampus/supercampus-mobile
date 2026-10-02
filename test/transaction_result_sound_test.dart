import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/widgets/transaction_result_overlay.dart';

Future<void> _show(WidgetTester tester, TransactionResult result) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => showTransactionResult(
            context,
            result: result,
            title: result == TransactionResult.success
                ? 'Order placed'
                : 'Payment unsuccessful',
          ),
          child: const Text('go'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final played = <String>[];
  setUp(() {
    played.clear();
    TransactionResultSound.debugOverride = played.add;
  });
  tearDown(() => TransactionResultSound.debugOverride = null);

  testWidgets('the ✓ screen plays the order-success sound', (tester) async {
    await _show(tester, TransactionResult.success);
    expect(find.text('Order placed'), findsOneWidget);
    expect(played, [TransactionResultSound.successAsset]);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('the ✖ screen plays the order-failed sound', (tester) async {
    await _show(tester, TransactionResult.failure);
    expect(find.text('Payment unsuccessful'), findsOneWidget);
    expect(played, [TransactionResultSound.failureAsset]);
    await tester.pump(const Duration(seconds: 3));
  });

  test('both sounds ship with the app', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final asset in [
      TransactionResultSound.successAsset,
      TransactionResultSound.failureAsset,
    ]) {
      final bytes = await rootBundle.load('assets/$asset');
      expect(bytes.lengthInBytes, greaterThan(10000), reason: asset);
    }
  });
}
