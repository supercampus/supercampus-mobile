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

class _WalletRepository implements AccountantWalletRepository {
  final credits = <_Credit>[];
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
    return const [];
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
