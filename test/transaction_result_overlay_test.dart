import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/widgets/transaction_result_overlay.dart';

void main() {
  testWidgets('shows full-screen animated success and failure results', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                TextButton(
                  onPressed: () => showTransactionResult(
                    context,
                    result: TransactionResult.success,
                    title: 'Payment successful',
                    amount: '₹250',
                  ),
                  child: const Text('Success'),
                ),
                TextButton(
                  onPressed: () => showTransactionResult(
                    context,
                    result: TransactionResult.failure,
                    title: 'Payment unsuccessful',
                    amount: '₹250',
                  ),
                  child: const Text('Failure'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Success'));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const ValueKey('animated-check')), findsOneWidget);
    expect(find.text('Payment successful'), findsOneWidget);
    expect(find.text('₹250'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('transaction-result-done')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Failure'));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byKey(const ValueKey('animated-cross')), findsOneWidget);
    expect(find.text('Payment unsuccessful'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('transaction-result-done')));
    await tester.pumpAndSettle();
  });
}
