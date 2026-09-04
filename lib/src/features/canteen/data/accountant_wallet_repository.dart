import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';
import 'canteen_models.dart';
import 'canteen_repository.dart';

class StudentWalletAccount {
  const StudentWalletAccount({
    required this.userId,
    required this.studentNumber,
    required this.studentName,
    required this.email,
    required this.department,
    required this.balance,
    this.updatedAt,
  });

  final String userId;
  final String studentNumber;
  final String studentName;
  final String email;
  final String department;
  final double balance;
  final DateTime? updatedAt;

  StudentWalletAccount copyWith({double? balance, DateTime? updatedAt}) =>
      StudentWalletAccount(
        userId: userId,
        studentNumber: studentNumber,
        studentName: studentName,
        email: email,
        department: department,
        balance: balance ?? this.balance,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

class AccountantWalletCredit {
  const AccountantWalletCredit({required this.balance});

  final double balance;
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
  });

  final String id;
  final String userId;
  final String studentName;
  final String studentNumber;
  final double amount;
  final String transactionType;
  final String description;
  final DateTime createdAt;
  final String? referenceId;

  bool get isCredit => amount > 0;
}

abstract interface class AccountantWalletRepository {
  Future<List<StudentWalletAccount>> listWallets({String search = ''});

  Future<List<AccountantWalletTransaction>> listTransactions({int limit = 50});

  Future<AccountantWalletCredit> creditWallet({
    required String userId,
    required double amount,
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
  Future<List<StudentWalletAccount>> listWallets({String search = ''}) async {
    final uri = _baseUri.replace(
      path: '/api/v1/operations/canteen/wallets',
      queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'limit': '2000',
      },
    );
    final data = await _request(
      (headers) => _client.get(uri, headers: headers),
    );
    final values = data['wallets'];
    if (values is! List) return const [];
    return values
        .whereType<Map<String, dynamic>>()
        .map((wallet) {
          return StudentWalletAccount(
            userId: _text(wallet['userId']),
            studentNumber: _text(wallet['studentNumber']),
            studentName: _text(wallet['studentName'], fallback: 'Student'),
            email: _text(wallet['email']),
            department: _text(wallet['department']),
            balance: _number(wallet['balance']),
            updatedAt: DateTime.tryParse(wallet['updatedAt']?.toString() ?? ''),
          );
        })
        .where((wallet) => wallet.userId.isNotEmpty)
        .toList(growable: false);
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
              transaction['studentName'],
              fallback: 'Campus user',
            ),
            studentNumber: _text(transaction['studentNumber']),
            amount: _number(transaction['amount']),
            transactionType: _text(transaction['transactionType']),
            description: _text(transaction['description']),
            referenceId: _text(transaction['referenceId']).isEmpty
                ? null
                : _text(transaction['referenceId']),
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
    required double amount,
    String? reference,
  }) async {
    final uri = _baseUri.replace(
      path: '/api/v1/operations/canteen/wallets/$userId/top-ups',
    );
    final data = await _request(
      (headers) => _client.post(
        uri,
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'source': 'manual',
          if (reference?.trim().isNotEmpty == true)
            'reference': reference!.trim(),
          'idempotencyKey':
              'accountant-$userId-${DateTime.now().microsecondsSinceEpoch}',
        }),
      ),
    );
    return AccountantWalletCredit(balance: _number(data['balance']));
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
      throw const CanteenException(
        'The wallet service returned an unreadable response.',
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
        message.trim().isEmpty ? 'The wallet request failed.' : message,
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

String _text(dynamic value, {String fallback = ''}) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;
double _number(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;
