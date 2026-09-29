import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/core/utils/formatters.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/data/wallet_transaction_detail.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/student_wallet_screen.dart';
import 'package:supercampus_mobile/src/features/insights/data/insight.dart';
import 'package:supercampus_mobile/src/features/insights/data/sources/wallet_balance_source.dart';

/// An accountant deduction can take a wallet below zero. Wherever the student
/// sees it, the balance reads as negative and in red, and the deduction shows
/// up as a debit with its reason.
CanteenStore _store({required double balance}) => CanteenStore(
  user: const CanteenUser(
    id: 'me',
    name: 'Test Student',
    email: 'student@example.com',
    rollNumber: 'MEC26CS001',
    department: 'CSE',
  ),
  walletBalances: {'mec-canteen': balance},
  shops: const [
    CanteenShop(
      id: 's1',
      shopKey: 'mec-canteen',
      name: 'Campus Canteen',
      category: 'canteen',
    ),
  ],
  menu: const [],
  orders: const [],
  walletTransactions: [
    WalletTransaction(
      id: 't-deduction',
      shopKey: 'mec-canteen',
      type: WalletTransactionType.debit,
      amount: 50,
      description: 'Broken plate',
      createdAt: DateTime(2026, 9, 29, 10),
      kind: 'manual_debit',
    ),
  ],
);

Future<void> _pumpWallet(WidgetTester tester, double balance) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: StudentWalletSheet(
          store: _store(balance: balance),
          onTopUp: (_) async => throw UnimplementedError(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('currency formatting keeps the minus sign', () {
    expect(formatCurrency(-50), '-₹50');
    expect(formatCurrency(-12.5), '-₹12.50');
  });

  testWidgets('a negative wallet balance is shown in red with a hint', (
    tester,
  ) async {
    await _pumpWallet(tester, -50);
    final balance = find.byKey(const ValueKey('student-wallet-balance'));
    final text = tester.widget<Text>(balance);
    expect(text.data, '-₹50');
    expect(text.style?.color, tester.element(balance).palette.danger);
    expect(
      find.byKey(const ValueKey('student-wallet-negative-hint')),
      findsOneWidget,
    );
  });

  testWidgets('a positive wallet balance has no negative hint', (tester) async {
    await _pumpWallet(tester, 120);
    final balance = find.byKey(const ValueKey('student-wallet-balance'));
    final text = tester.widget<Text>(balance);
    expect(text.data, '₹120');
    expect(text.style?.color, isNot(tester.element(balance).palette.danger));
    expect(
      find.byKey(const ValueKey('student-wallet-negative-hint')),
      findsNothing,
    );
  });

  testWidgets('an accounts deduction is listed as a debit with its reason', (
    tester,
  ) async {
    await _pumpWallet(tester, -50);
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    expect(find.text('Broken plate'), findsOneWidget);
    expect(find.textContaining('Deducted by Accounts'), findsOneWidget);
    expect(find.text('-₹50'), findsWidgets);
  });

  test('a manual_debit ledger row reads as a wallet deduction', () {
    final detail = WalletTransactionDetail.fromJson({
      'id': 'tx-1',
      'amount': -50,
      'transactionType': 'manual_debit',
      'description': 'Broken plate',
      'shopKey': 'mec-canteen',
      'shopName': 'Campus Canteen',
      'createdAt': '2026-09-29T10:00:00Z',
      'balanceAfter': -50,
    });
    expect(detail.kind, WalletTransactionKind.accountDeduction);
    expect(detail.kind.label, 'Wallet deduction');
    expect(detail.isCredit, isFalse);
    expect(detail.paymentMethod, isNull);
    expect(detail.balanceAfter, -50);
  });

  test('the wallet insight reports a negative balance plainly', () {
    final insight = const WalletBalanceSource().evaluate(
      InsightContext(now: DateTime(2026, 9, 29, 9), walletBalance: -50),
    );
    expect(insight, isNotNull);
    expect(insight!.headline, 'Wallet balance is negative');
    expect(insight.metric?.label, '-₹50');
    expect(insight.supporting, startsWith('-₹50'));
  });
}
