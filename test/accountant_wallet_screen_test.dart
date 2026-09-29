import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/canteen/data/accountant_wallet_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/data/canteen_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/accountant_wallet_screen.dart';

const _stores = [
  WalletStore(shopKey: 'mec-canteen', name: 'Canteen', category: 'canteen'),
  WalletStore(
    shopKey: 'mec-stationery',
    name: 'Campus Stationery',
    category: 'stationery',
  ),
  WalletStore(
    shopKey: 'mec-laundry',
    name: 'Campus Laundry',
    category: 'laundry',
  ),
];

Future<void> _pumpScreen(
  WidgetTester tester,
  _WalletRepository repository, {
  String? initialAction,
  VoidCallback? onExit,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: AccountantWalletScreen(
        repository: repository,
        accountantName: 'Abhinaya',
        onSignOut: () {},
        onExitModule: onExit,
        initialAction: initialAction,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDirectory(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('open-student-wallets')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('recharge directory lists students and staff with roles', (
    tester,
  ) async {
    final repository = _WalletRepository();
    var exited = false;
    await _pumpScreen(tester, repository, onExit: () => exited = true);

    expect(find.byKey(const ValueKey('open-student-wallets')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-wallet-activity')), findsOneWidget);
    expect(find.byKey(const ValueKey('open-wallet-limits')), findsOneWidget);
    expect(find.text('Abinaya S'), findsNothing);

    await tester.tap(find.byTooltip('Back'));
    expect(exited, isTrue);

    await _openDirectory(tester);
    expect(find.text('Abinaya S'), findsOneWidget);
    expect(find.text('Rahul Subramanian'), findsOneWidget);
    expect(find.text('Warden'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Showing 2 of 2'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('wallet-avatar-student-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('audience-staff')));
    await tester.pumpAndSettle();
    expect(repository.lastAudience, WalletAudience.staff);
    expect(find.text('Abinaya S'), findsNothing);
    expect(find.text('Rahul Subramanian'), findsOneWidget);
    expect(find.text('Showing 1 of 1'), findsOneWidget);
  });

  testWidgets('recharge requires a store, confirms and shows the new balance', (
    tester,
  ) async {
    final repository = _WalletRepository();
    await _pumpScreen(tester, repository);
    await _openDirectory(tester);

    await tester.tap(find.byKey(const ValueKey('credit-warden-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wallet-quick-500')));
    await tester.pump();

    // No store chosen yet: the recharge is refused inline.
    await tester.tap(find.byKey(const ValueKey('wallet-review-recharge')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wallet-recharge-error')), findsOneWidget);
    expect(find.text('Choose which wallet to recharge.'), findsOneWidget);
    expect(repository.credits, isEmpty);

    await tester.tap(find.byKey(const ValueKey('wallet-store-mec-stationery')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('wallet-review-recharge')));
    await tester.pumpAndSettle();

    expect(
      find.text("Add ₹500 to Rahul Subramanian’s Campus Stationery wallet?"),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('confirm-wallet-recharge')));
    await tester.pumpAndSettle();

    expect(repository.credits, hasLength(1));
    expect(repository.credits.single.shopKey, 'mec-stationery');
    expect(repository.credits.single.userId, 'warden-1');
    expect(repository.credits.single.amount, 500);
    expect(repository.credits.single.idempotencyKey, isNotEmpty);

    expect(find.byKey(const ValueKey('wallet-recharge-success')), findsOneWidget);
    expect(find.text('₹500 added'), findsOneWidget);
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('wallet-recharge-new-balance')),
          )
          .data,
      '₹540',
    );

    await tester.tap(find.byKey(const ValueKey('wallet-recharge-done')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wallet-recharge-success')), findsNothing);
    // The row now shows the new stationery balance.
    expect(find.text('₹540'), findsOneWidget);
  });

  testWidgets('a server error is shown inside the recharge sheet', (
    tester,
  ) async {
    final repository = _WalletRepository()
      ..creditError = const CanteenException(
        "'mec-laundry' is not an active canteen, stationery or laundry store of this campus",
      );
    await _pumpScreen(tester, repository);
    await _openDirectory(tester);

    await tester.tap(find.byKey(const ValueKey('credit-student-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wallet-store-mec-laundry')));
    await tester.enterText(find.byKey(const ValueKey('wallet-amount')), '200');
    await tester.tap(find.byKey(const ValueKey('wallet-review-recharge')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-wallet-recharge')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('wallet-recharge-error')), findsOneWidget);
    expect(
      find.textContaining('is not an active canteen, stationery or laundry'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('wallet-recharge-success')), findsNothing);
  });

  testWidgets('a forbidden wallet desk shows an error, never zeros', (
    tester,
  ) async {
    final repository = _WalletRepository()
      ..loadError = const CanteenException(
        'Your account is not allowed to manage wallets.',
      );
    await _pumpScreen(tester, repository);

    expect(find.byKey(const ValueKey('accounts-error')), findsOneWidget);
    expect(
      find.text('Your account is not allowed to manage wallets.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('open-student-wallets')), findsNothing);
    expect(find.byKey(const ValueKey('summary-wallet-float')), findsNothing);

    repository.loadError = null;
    await tester.tap(find.byKey(const ValueKey('accounts-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('accounts-error')), findsNothing);
    expect(find.byKey(const ValueKey('open-student-wallets')), findsOneWidget);
  });

  testWidgets('the wallet action opens the recharge directory directly', (
    tester,
  ) async {
    await _pumpScreen(tester, _WalletRepository(), initialAction: 'wallet');
    expect(find.text('Wallet recharge'), findsOneWidget);
    expect(find.text('Rahul Subramanian'), findsOneWidget);
  });

  testWidgets('a deduction needs a reason, confirms the resulting negative '
      'balance and shows it in red', (tester) async {
    final repository = _WalletRepository();
    await _pumpScreen(tester, repository);
    await _openDirectory(tester);

    await tester.tap(find.byKey(const ValueKey('credit-warden-1')));
    await tester.pumpAndSettle();
    // Add is the default; switch to Deduct.
    expect(find.byKey(const ValueKey('wallet-reason')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('wallet-action-deduct')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wallet-reason')), findsOneWidget);
    expect(find.text('Review deduction'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wallet-store-mec-stationery')));
    await tester.enterText(find.byKey(const ValueKey('wallet-amount')), '100');
    await tester.pump();
    // Live preview: ₹40 − ₹100 goes below zero.
    expect(
      find.textContaining('goes below zero'),
      findsOneWidget,
    );

    // No reason yet: refused inline, nothing sent.
    await tester.tap(find.byKey(const ValueKey('wallet-review-recharge')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a reason for the deduction.'), findsOneWidget);
    expect(repository.debits, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('wallet-reason')),
      'Damaged library book',
    );
    await tester.tap(find.byKey(const ValueKey('wallet-review-recharge')));
    await tester.pumpAndSettle();

    expect(find.text('Confirm deduction'), findsOneWidget);
    expect(
      find.text("Deduct ₹100 from Rahul Subramanian’s Campus Stationery wallet?"),
      findsOneWidget,
    );
    Text textOf(String key) =>
        tester.widget<Text>(find.byKey(ValueKey(key)));
    final palette = tester
        .element(find.byKey(const ValueKey('wallet-confirm-balance-after')))
        .palette;
    expect(textOf('wallet-confirm-current-balance').data, '₹40');
    expect(textOf('wallet-confirm-balance-after').data, '-₹60');
    expect(textOf('wallet-confirm-balance-after').style?.color, palette.danger);
    expect(
      find.byKey(const ValueKey('wallet-confirm-negative-warning')),
      findsOneWidget,
    );
    expect(find.text('Reason: Damaged library book'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('confirm-wallet-deduction')));
    await tester.pumpAndSettle();

    expect(repository.credits, isEmpty);
    expect(repository.debits, hasLength(1));
    final debit = repository.debits.single;
    expect(debit.userId, 'warden-1');
    expect(debit.shopKey, 'mec-stationery');
    expect(debit.amount, 100);
    expect(debit.reason, 'Damaged library book');
    expect(debit.idempotencyKey, isNotEmpty);

    expect(find.text('₹100 deducted'), findsOneWidget);
    expect(textOf('wallet-recharge-new-balance').data, '-₹60');
    expect(textOf('wallet-recharge-new-balance').style?.color, palette.danger);

    await tester.tap(find.byKey(const ValueKey('wallet-recharge-done')));
    await tester.pumpAndSettle();
    // The directory row now shows the negative stationery balance in red.
    final pill = find.byKey(
      const ValueKey('wallet-balance-warden-1-mec-stationery'),
    );
    final pillText = tester.widget<Text>(
      find.descendant(of: pill, matching: find.byType(Text)),
    );
    expect(pillText.data, '-₹60');
    expect(pillText.style?.color, palette.danger);
  });

  testWidgets('a deduction that stays above zero shows no warning', (
    tester,
  ) async {
    final repository = _WalletRepository();
    await _pumpScreen(tester, repository);
    await _openDirectory(tester);

    await tester.tap(find.byKey(const ValueKey('credit-student-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wallet-action-deduct')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wallet-store-mec-canteen')));
    await tester.enterText(find.byKey(const ValueKey('wallet-amount')), '20');
    await tester.enterText(
      find.byKey(const ValueKey('wallet-reason')),
      'Correction',
    );
    await tester.tap(find.byKey(const ValueKey('wallet-review-recharge')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('wallet-confirm-balance-after')),
          )
          .data,
      '₹100',
    );
    expect(
      find.byKey(const ValueKey('wallet-confirm-negative-warning')),
      findsNothing,
    );
    // Cancelling sends nothing.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.debits, isEmpty);
  });

  testWidgets('a server error during a deduction stays in the sheet', (
    tester,
  ) async {
    final repository = _WalletRepository()
      ..debitError = const CanteenException('Give a reason for the deduction');
    await _pumpScreen(tester, repository);
    await _openDirectory(tester);

    await tester.tap(find.byKey(const ValueKey('credit-student-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wallet-action-deduct')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wallet-store-mec-canteen')));
    await tester.enterText(find.byKey(const ValueKey('wallet-amount')), '20');
    await tester.enterText(find.byKey(const ValueKey('wallet-reason')), 'Fine');
    await tester.tap(find.byKey(const ValueKey('wallet-review-recharge')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-wallet-deduction')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('wallet-recharge-error')), findsOneWidget);
    expect(find.text('Give a reason for the deduction'), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-recharge-success')), findsNothing);
  });

  testWidgets('the ledger labels deductions and shows their reason', (
    tester,
  ) async {
    final repository = _WalletRepository()
      ..transactions = [
        AccountantWalletTransaction(
          id: 'tx-1',
          userId: 'student-1',
          studentName: 'Abinaya S',
          studentNumber: 'MEC25AD01',
          amount: -50,
          transactionType: 'manual_debit',
          description: 'Broken plate',
          createdAt: DateTime(2026, 9, 29, 10),
          shopName: 'Canteen',
        ),
      ];
    await _pumpScreen(tester, repository);
    await tester.tap(find.byKey(const ValueKey('open-wallet-activity')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Deduction · Canteen wallet'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('wallet-deduction-reason-tx-1')),
      findsOneWidget,
    );
    expect(find.text('Reason: Broken plate'), findsOneWidget);
    expect(find.text('−₹50'), findsOneWidget);
  });

  test('directory page parsing reads stores, counts and non-students', () {
    final page = parseWalletDirectoryPage({
      'wallets': [
        {
          'userId': 'u-2',
          'studentName': 'Rahul Subramanian',
          'name': 'Rahul Subramanian',
          'studentNumber': '',
          'email': 'warden.boys@mec.local',
          'isStudent': false,
          'role': 'warden',
          'roleLabel': 'Warden',
          'roleLabels': ['Warden'],
          'yearOfStudy': null,
          'walletBalances': {'mec-canteen': 100, 'mec-laundry': 50.5},
        },
      ],
      'total': 246,
      'offset': 0,
      'hasMore': true,
      'counts': {
        'all': 246,
        'students': 200,
        'staff': 46,
        'years': {'1': 120, '2': 80},
      },
      'stores': [
        {'shopKey': 'mec-canteen', 'name': 'Canteen', 'category': 'canteen'},
      ],
      'summary': {
        'totalBalance': 2185,
        'balancesByStore': {'mec-canteen': 500},
      },
    });
    expect(page.total, 246);
    expect(page.hasMore, isTrue);
    expect(page.counts.staff, 46);
    expect(page.counts.years, {1: 120, 2: 80});
    expect(page.stores.single.shopKey, 'mec-canteen');
    expect(page.totalBalance, 2185);
    final warden = page.accounts.single;
    expect(warden.isStudent, isFalse);
    expect(warden.roleLabel, 'Warden');
    expect(warden.balance, 150.5);
    expect(warden.balanceFor('mec-laundry'), 50.5);
  });
}

class _Credit {
  const _Credit(this.userId, this.shopKey, this.amount, this.idempotencyKey);
  final String userId;
  final String shopKey;
  final double amount;
  final String idempotencyKey;
}

class _Debit {
  const _Debit(
    this.userId,
    this.shopKey,
    this.amount,
    this.reason,
    this.idempotencyKey,
  );
  final String userId;
  final String shopKey;
  final double amount;
  final String reason;
  final String idempotencyKey;
}

class _WalletRepository implements AccountantWalletRepository {
  final credits = <_Credit>[];
  final debits = <_Debit>[];
  Object? debitError;
  List<AccountantWalletTransaction> transactions = const [];
  WalletTopUpSettings settings = WalletTopUpSettings.defaults;
  WalletAudience? lastAudience;
  Object? loadError;
  Object? creditError;

  final _people = <WalletAccount>[
    const WalletAccount(
      userId: 'student-1',
      name: 'Abinaya S',
      email: 'abinaya@example.com',
      studentNumber: 'MEC25AD01',
      department: 'AIDS',
      yearOfStudy: 2,
      walletBalances: {'mec-canteen': 120},
    ),
    const WalletAccount(
      userId: 'warden-1',
      name: 'Rahul Subramanian',
      email: 'warden.boys@mec.local',
      isStudent: false,
      role: 'warden',
      roleLabel: 'Warden',
      roleLabels: ['Warden'],
      walletBalances: {'mec-stationery': 40},
    ),
  ];

  @override
  Future<WalletDirectoryPage> listWallets({
    String search = '',
    WalletAudience audience = WalletAudience.all,
    int? year,
    int offset = 0,
    int limit = 50,
  }) async {
    if (loadError != null) throw loadError!;
    lastAudience = audience;
    final matches = _people
        .where(
          (person) => switch (audience) {
            WalletAudience.all => true,
            WalletAudience.students => person.isStudent,
            WalletAudience.staff => !person.isStudent,
          },
        )
        .toList();
    return WalletDirectoryPage(
      accounts: matches.skip(offset).take(limit).toList(),
      total: matches.length,
      offset: offset,
      hasMore: offset + limit < matches.length,
      stores: _stores,
      counts: const WalletDirectoryCounts(
        all: 2,
        students: 1,
        staff: 1,
        years: {2: 1},
      ),
      totalBalance: 160,
    );
  }

  @override
  Future<List<AccountantWalletTransaction>> listTransactions({
    int limit = 50,
  }) async {
    if (loadError != null) throw loadError!;
    return transactions;
  }

  @override
  Future<AccountantWalletCredit> debitWallet({
    required String userId,
    required String shopKey,
    required double amount,
    required String reason,
    required String idempotencyKey,
  }) async {
    if (debitError != null) throw debitError!;
    debits.add(_Debit(userId, shopKey, amount, reason, idempotencyKey));
    final index = _people.indexWhere((person) => person.userId == userId);
    // Like the server: no floor, a deduction may take the wallet negative.
    final balance = _people[index].balanceFor(shopKey) - amount;
    _people[index] = _people[index].withBalance(shopKey, balance);
    return AccountantWalletCredit(
      balance: balance,
      shopKey: shopKey,
      shopName: _stores.firstWhere((store) => store.shopKey == shopKey).name,
    );
  }

  @override
  Future<AccountantWalletCredit> creditWallet({
    required String userId,
    required String shopKey,
    required double amount,
    required String idempotencyKey,
    String? reference,
  }) async {
    if (creditError != null) throw creditError!;
    credits.add(_Credit(userId, shopKey, amount, idempotencyKey));
    final index = _people.indexWhere((person) => person.userId == userId);
    final balance = _people[index].balanceFor(shopKey) + amount;
    _people[index] = _people[index].withBalance(shopKey, balance);
    return AccountantWalletCredit(
      balance: balance,
      shopKey: shopKey,
      shopName: _stores.firstWhere((store) => store.shopKey == shopKey).name,
    );
  }

  @override
  Future<WalletTopUpSettings> getWalletTopUpSettings() async {
    if (loadError != null) throw loadError!;
    return settings;
  }

  @override
  Future<WalletTopUpSettings> updateWalletTopUpSettings({
    required double minimumAmount,
    required double maximumAmount,
  }) async => settings = WalletTopUpSettings(
    minimumAmount: minimumAmount,
    maximumAmount: maximumAmount,
  );
}
