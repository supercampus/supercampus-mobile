import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/canteen/data/accountant_wallet_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/accountant_wallet_screen.dart';

void main() {
  testWidgets('accountant finds a student and credits the shared wallet', (
    tester,
  ) async {
    final repository = _WalletRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AccountantWalletScreen(
          repository: repository,
          accountantName: 'Abhinaya',
          onSignOut: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Abinaya S'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('open-student-wallets')));
    await tester.pumpAndSettle();

    expect(find.text('Abinaya S'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('credit-student-1')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Credits to add'),
      '250',
    );
    await tester.tap(find.byKey(const ValueKey('confirm-wallet-credit')));
    await tester.pumpAndSettle();

    expect(repository.creditedAmount, 250);
    expect(find.text('370'), findsOneWidget);
    expect(find.textContaining('250 credits added'), findsOneWidget);
  });
}

class _WalletRepository implements AccountantWalletRepository {
  double creditedAmount = 0;
  WalletTopUpSettings settings = WalletTopUpSettings.defaults;

  @override
  Future<List<StudentWalletAccount>> listWallets({String search = ''}) async =>
      [
        StudentWalletAccount(
          userId: 'student-1',
          studentNumber: 'MEC25AD01',
          studentName: 'Abinaya S',
          email: 'abinaya@example.com',
          department: 'AIDS',
          balance: 120 + creditedAmount,
        ),
      ];

  @override
  Future<List<AccountantWalletTransaction>> listTransactions({
    int limit = 50,
  }) async => const [];

  @override
  Future<AccountantWalletCredit> creditWallet({
    required String userId,
    required double amount,
    String? reference,
  }) async {
    creditedAmount = amount;
    return AccountantWalletCredit(balance: 120 + amount);
  }

  @override
  Future<WalletTopUpSettings> getWalletTopUpSettings() async => settings;

  @override
  Future<WalletTopUpSettings> updateWalletTopUpSettings({
    required double minimumAmount,
    required double maximumAmount,
  }) async => settings = WalletTopUpSettings(
    minimumAmount: minimumAmount,
    maximumAmount: maximumAmount,
  );
}
