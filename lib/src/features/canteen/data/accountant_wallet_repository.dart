import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';
import '../../../core/students/student_year.dart';
import 'canteen_models.dart';
import 'canteen_repository.dart';

/// A campus store that holds a prepaid wallet (canteen, stationery, laundry).
class WalletStore {
  const WalletStore({
    required this.shopKey,
    required this.name,
    required this.category,
  });

  final String shopKey;
  final String name;

  /// `canteen`, `stationery` or `laundry`.
  final String category;
}

/// Who the recharge directory is narrowed to.
enum WalletAudience {
  all('all'),
  students('students'),
  staff('staff');

  const WalletAudience(this.apiValue);
  final String apiValue;
}

/// One person the accountant can recharge: a student or any other active
/// member of the campus (faculty, staff, wardens, parents ...).
class WalletAccount {
  const WalletAccount({
    required this.userId,
    required this.name,
    required this.email,
    this.isStudent = true,
    this.role = 'student',
    this.roleLabel = 'Student',
    this.roleLabels = const [],
    this.studentNumber = '',
    this.department = '',
    this.yearOfStudy,
    this.yearLabel,
    this.photoUrl,
    this.walletBalances = const {},
    this.updatedAt,
    this.lastTransactionAt,
  });

  final String userId;
  final String name;
  final String email;
  final bool isStudent;
  final String role;
  final String roleLabel;
  final List<String> roleLabels;
  final String studentNumber;
  final String department;
  final int? yearOfStudy;
  final String? yearLabel;
  final String? photoUrl;

  /// Balance per store, keyed by shop key.
  final Map<String, double> walletBalances;
  final DateTime? updatedAt;
  final DateTime? lastTransactionAt;

  /// Legacy name used by older screens and tests.
  String get studentName => name;

  double get balance =>
      walletBalances.values.fold<double>(0, (sum, value) => sum + value);

  double balanceFor(String shopKey) => walletBalances[shopKey] ?? 0;

  WalletAccount withBalance(String shopKey, double balance) => WalletAccount(
    userId: userId,
    name: name,
    email: email,
    isStudent: isStudent,
    role: role,
    roleLabel: roleLabel,
    roleLabels: roleLabels,
    studentNumber: studentNumber,
    department: department,
    yearOfStudy: yearOfStudy,
    yearLabel: yearLabel,
    photoUrl: photoUrl,
    walletBalances: {...walletBalances, shopKey: balance},
    updatedAt: DateTime.now(),
    lastTransactionAt: DateTime.now(),
  );
}

class WalletDirectoryCounts {
  const WalletDirectoryCounts({
    this.all = 0,
    this.students = 0,
    this.staff = 0,
    this.years = const {},
  });

  final int all;
  final int students;
  final int staff;

  /// Students per year of study (1–6); students without a year are left out.
  final Map<int, int> years;

  int forAudience(WalletAudience audience) => switch (audience) {
    WalletAudience.all => all,
    WalletAudience.students => students,
    WalletAudience.staff => staff,
  };
}

/// One page of the recharge directory.
class WalletDirectoryPage {
  const WalletDirectoryPage({
    required this.accounts,
    required this.total,
    this.offset = 0,
    this.hasMore = false,
    this.stores = const [],
    this.counts = const WalletDirectoryCounts(),
    this.totalBalance = 0,
    this.balancesByStore = const {},
  });

  final List<WalletAccount> accounts;

  /// Everyone matching the filters, across all pages.
  final int total;
  final int offset;
  final bool hasMore;
  final List<WalletStore> stores;
  final WalletDirectoryCounts counts;

  /// Wallet float across every wallet of the campus.
  final double totalBalance;
  final Map<String, double> balancesByStore;
}

class AccountantWalletCredit {
  const AccountantWalletCredit({
    required this.balance,
    this.shopKey = '',
    this.shopName = '',
    this.replayed = false,
  });

  /// The store wallet's balance after the credit.
  final double balance;
  final String shopKey;
  final String shopName;
  final bool replayed;
}

class AccountantWalletTransaction {
  const AccountantWalletTransaction({
    required this.id,
    required this.userId,
    required this.studentName,
    required this.studentNumber,
    required this.amount,
    required this.transactionType,
    required this.description,
    required this.createdAt,
    this.referenceId,
    this.shopKey = '',
    this.shopName = '',
    this.roleLabel = '',
    this.isStudent = true,
    this.email,
  });

  final String id;
  final String userId;

  /// The wallet holder's name (students and everyone else).
  final String studentName;
  final String studentNumber;
  final double amount;
  final String transactionType;
  final String description;
  final DateTime createdAt;
  final String? referenceId;
  final String shopKey;
  final String shopName;
  final String roleLabel;
  final bool isStudent;
  final String? email;

  String get name => studentName;

  bool get isCredit => amount > 0;
}

abstract interface class AccountantWalletRepository {
  Future<WalletDirectoryPage> listWallets({
    String search = '',
    WalletAudience audience = WalletAudience.all,
    int? year,
    int offset = 0,
    int limit = 50,
  });

  Future<List<AccountantWalletTransaction>> listTransactions({int limit = 50});

  /// Credits one store wallet. [idempotencyKey] makes a retried request safe.
  Future<AccountantWalletCredit> creditWallet({
    required String userId,
    required String shopKey,
    required double amount,
    required String idempotencyKey,
    String? reference,
  });

  Future<WalletTopUpSettings> getWalletTopUpSettings();

  Future<WalletTopUpSettings> updateWalletTopUpSettings({
    required double minimumAmount,
    required double maximumAmount,
  });
}

class BackendAccountantWalletRepository implements AccountantWalletRepository {
  BackendAccountantWalletRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.replaceFirst(RegExp(r'/$'), '')),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;

  @override
  Future<WalletDirectoryPage> listWallets({
    String search = '',
    WalletAudience audience = WalletAudience.all,
    int? year,
    int offset = 0,
    int limit = 50,
  }) async {
    final uri = _baseUri.replace(
      path: '/api/v1/operations/canteen/wallets',
      queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        if (audience != WalletAudience.all) 'audience': audience.apiValue,
        if (year != null) 'year': '$year',
        'offset': '$offset',
        'limit': '$limit',
      },
    );
    final data = await _request(
      (headers) => _client.get(uri, headers: headers),
    );
    return parseWalletDirectoryPage(data);
  }

  @override
  Future<List<AccountantWalletTransaction>> listTransactions({
    int limit = 50,
  }) async {
    final uri = _baseUri.replace(
      path: '/api/v1/operations/canteen/wallet-transactions',
      queryParameters: {'limit': '$limit'},
    );
    final data = await _request(
      (headers) => _client.get(uri, headers: headers),
    );
    final values = data['transactions'];
    if (values is! List) return const [];
    return values
        .whereType<Map<String, dynamic>>()
        .map(
          (transaction) => AccountantWalletTransaction(
            id: _text(transaction['id']),
            userId: _text(transaction['userId']),
            studentName: _text(
              transaction['name'],
              fallback: _text(
                transaction['studentName'],
                fallback: 'Campus user',
              ),
            ),
            studentNumber: _text(transaction['studentNumber']),
            amount: _number(transaction['amount']),
            transactionType: _text(transaction['transactionType']),
            description: _text(transaction['description']),
            referenceId: _text(transaction['referenceId']).isEmpty
                ? null
                : _text(transaction['referenceId']),
            shopKey: _text(transaction['shopKey']),
            shopName: _text(
              transaction['shopName'],
              fallback: _text(transaction['shopKey']),
            ),
            roleLabel: _text(transaction['roleLabel']),
            isStudent: transaction['isStudent'] != false,
            email: _text(transaction['email']).isEmpty
                ? null
                : _text(transaction['email']),
            createdAt:
                DateTime.tryParse(transaction['createdAt']?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0),
          ),
        )
        .where((transaction) => transaction.id.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<AccountantWalletCredit> creditWallet({
    required String userId,
    required String shopKey,
    required double amount,
    required String idempotencyKey,
    String? reference,
  }) async {
    final uri = _baseUri.replace(
      path:
          '/api/v1/operations/canteen/wallets/${Uri.encodeComponent(userId)}/top-ups',
    );
    final data = await _request(
      (headers) => _client.post(
        uri,
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'shopKey': shopKey,
          'source': 'manual',
          if (reference?.trim().isNotEmpty == true)
            'reference': reference!.trim(),
          'idempotencyKey': idempotencyKey,
        }),
      ),
    );
    return AccountantWalletCredit(
      balance: _number(data['balance']),
      shopKey: _text(data['shopKey'], fallback: shopKey),
      shopName: _text(data['shopName']),
      replayed: data['replayed'] == true,
    );
  }

  @override
  Future<WalletTopUpSettings> getWalletTopUpSettings() async {
    final data = await _request(
      (headers) => _client.get(
        _baseUri.replace(path: '/api/v1/operations/canteen/wallet-settings'),
        headers: headers,
      ),
    );
    return _settings(data);
  }

  @override
  Future<WalletTopUpSettings> updateWalletTopUpSettings({
    required double minimumAmount,
    required double maximumAmount,
  }) async {
    final data = await _request(
      (headers) => _client.put(
        _baseUri.replace(path: '/api/v1/operations/canteen/wallet-settings'),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({
          'minimumAmount': minimumAmount,
          'maximumAmount': maximumAmount,
        }),
      ),
    );
    return _settings(data);
  }

  WalletTopUpSettings _settings(Map<String, dynamic> data) =>
      WalletTopUpSettings(
        minimumAmount: _number(data['minimumAmount']),
        maximumAmount: _number(data['maximumAmount']),
      );

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    var token = await _accessTokenProvider();
    var response = await send(_headers(token));
    if (response.statusCode == 401) {
      token = await _accessTokenProvider(forceRefresh: true);
      response = await send(_headers(token));
    }
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw CanteenException(
        response.statusCode == 403
            ? 'Your account is not allowed to manage wallets.'
            : 'The wallet service returned an unreadable response.',
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body['error'];
      final message = switch (error) {
        Map<String, dynamic>() => _text(error['message']),
        String() => error,
        _ => _text(body['message']),
      };
      throw CanteenException(
        message.trim().isNotEmpty
            ? message
            : response.statusCode == 403
            ? 'Your account is not allowed to manage wallets.'
            : 'The wallet request failed.',
      );
    }
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw const CanteenException('The wallet response is missing data.');
    }
    return data;
  }

  Map<String, String> _headers(String token) => {
    'authorization': 'Bearer $token',
    'x-client-surface': 'app',
    'accept': 'application/json',
  };
}

/// Reads `GET /canteen/wallets`. Accepts the older shape (only `wallets`) too.
WalletDirectoryPage parseWalletDirectoryPage(Map<String, dynamic> data) {
  final values = data['wallets'];
  final accounts = values is List
      ? values
            .whereType<Map<String, dynamic>>()
            .map(_account)
            .where((account) => account.userId.isNotEmpty)
            .toList(growable: false)
      : const <WalletAccount>[];
  final stores = data['stores'] is List
      ? (data['stores'] as List)
            .whereType<Map<String, dynamic>>()
            .map(
              (store) => WalletStore(
                shopKey: _text(store['shopKey']),
                name: _text(store['name'], fallback: _text(store['shopKey'])),
                category: _text(store['category']).toLowerCase(),
              ),
            )
            .where((store) => store.shopKey.isNotEmpty)
            .toList(growable: false)
      : const <WalletStore>[];
  final counts = data['counts'] is Map<String, dynamic>
      ? data['counts'] as Map<String, dynamic>
      : const <String, dynamic>{};
  final years = <int, int>{};
  if (counts['years'] is Map) {
    for (final entry in (counts['years'] as Map).entries) {
      final year = int.tryParse(entry.key.toString());
      if (year != null) years[year] = _number(entry.value).toInt();
    }
  }
  final summary = data['summary'] is Map<String, dynamic>
      ? data['summary'] as Map<String, dynamic>
      : const <String, dynamic>{};
  final total = data['total'] is num
      ? (data['total'] as num).toInt()
      : accounts.length;
  final offset = data['offset'] is num ? (data['offset'] as num).toInt() : 0;
  return WalletDirectoryPage(
    accounts: accounts,
    total: total,
    offset: offset,
    hasMore: data['hasMore'] == true,
    stores: stores,
    counts: WalletDirectoryCounts(
      all: counts['all'] is num ? (counts['all'] as num).toInt() : total,
      students: _number(counts['students']).toInt(),
      staff: _number(counts['staff']).toInt(),
      years: years,
    ),
    totalBalance: summary.containsKey('totalBalance')
        ? _number(summary['totalBalance'])
        : accounts.fold<double>(0, (sum, account) => sum + account.balance),
    balancesByStore: _balances(summary['balancesByStore']),
  );
}

WalletAccount _account(Map<String, dynamic> wallet) {
  final isStudent =
      wallet['isStudent'] is bool ? wallet['isStudent'] as bool : true;
  final roleLabels = wallet['roleLabels'] is List
      ? (wallet['roleLabels'] as List)
            .map((value) => _text(value))
            .where((value) => value.isNotEmpty)
            .toList(growable: false)
      : const <String>[];
  final photoUrl = _text(wallet['photoUrl']);
  return WalletAccount(
    userId: _text(wallet['userId']),
    name: _text(
      wallet['name'],
      fallback: _text(
        wallet['studentName'],
        fallback: _text(wallet['email'], fallback: 'Campus user'),
      ),
    ),
    email: _text(wallet['email']),
    isStudent: isStudent,
    role: _text(wallet['role'], fallback: isStudent ? 'student' : 'staff'),
    roleLabel: _text(
      wallet['roleLabel'],
      fallback: isStudent ? 'Student' : 'Staff',
    ),
    roleLabels: roleLabels,
    studentNumber: _text(wallet['studentNumber']),
    department: _text(wallet['department']),
    yearOfStudy: isStudent
        ? parseStudentYear(wallet['yearOfStudy'] ?? wallet['year'])
        : null,
    yearLabel: _text(wallet['yearLabel']).isEmpty
        ? null
        : _text(wallet['yearLabel']),
    photoUrl: photoUrl.isEmpty ? null : photoUrl,
    walletBalances: _balances(wallet['walletBalances']),
    updatedAt: DateTime.tryParse(wallet['updatedAt']?.toString() ?? ''),
    lastTransactionAt: DateTime.tryParse(
      wallet['lastTransactionAt']?.toString() ?? '',
    ),
  );
}

Map<String, double> _balances(dynamic value) {
  if (value is! Map) return const {};
  return {
    for (final entry in value.entries)
      entry.key.toString(): _number(entry.value),
  };
}

String _text(dynamic value, {String fallback = ''}) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;
double _number(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;
