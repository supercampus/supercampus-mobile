import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';
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

abstract interface class AccountantWalletRepository {
  Future<List<StudentWalletAccount>> listWallets({String search = ''});

  Future<AccountantWalletCredit> creditWallet({
    required String userId,
    required double amount,
    String? reference,
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
        'limit': '250',
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
      throw CanteenException(
        error is Map<String, dynamic>
            ? _text(error['message'], fallback: 'The wallet request failed.')
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

String _text(dynamic value, {String fallback = ''}) =>
    value is String && value.trim().isNotEmpty ? value.trim() : fallback;
double _number(dynamic value) => value is num
    ? value.toDouble()
    : double.tryParse(value?.toString() ?? '') ?? 0;
