import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/authentication/data/auth_http_client.dart';
import '../../features/authentication/data/auth_repository.dart';

class StudentFeeRecord {
  const StudentFeeRecord({
    required this.id,
    required this.type,
    required this.data,
  });

  factory StudentFeeRecord.fromJson(Map<String, dynamic> json) =>
      StudentFeeRecord(
        id: json['id']?.toString() ?? '',
        type: json['recordType']?.toString() ?? '',
        data: Map<String, dynamic>.from(
          json['data'] is Map ? json['data'] as Map : const {},
        ),
      );

  final String id;
  final String type;
  final Map<String, dynamic> data;
}

class RazorpayOrder {
  const RazorpayOrder({
    required this.id,
    required this.amount,
    required this.currency,
    required this.keyId,
  });

  final String id;
  final int amount;
  final String currency;
  final String keyId;
}

class TuitionFeeRepository {
  TuitionFeeRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl.trim().replaceAll(RegExp(r'/+$'), '')),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient();

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;

  Future<List<StudentFeeRecord>> load() async {
    var token = await _accessTokenProvider();
    var response = await _get(token);
    if (response.statusCode == 401) {
      token = await _accessTokenProvider(forceRefresh: true);
      response = await _get(token);
    }
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map) {
      final error = decoded is Map && decoded['error'] is Map
          ? (decoded['error'] as Map)['message']?.toString()
          : null;
      throw TuitionFeeException(
        error ?? 'Your fee account could not be loaded.',
      );
    }
    final data = decoded['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((row) => StudentFeeRecord.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  Future<RazorpayOrder> createOrder({
    required int amount,
    required String receipt,
  }) async {
    final data = await _post('/api/v1/payments/razorpay/orders', {
      'amount': amount,
      'currency': 'INR',
      'receipt': receipt,
    });
    final id = data['order_id']?.toString() ?? '';
    final keyId = data['key_id']?.toString() ?? '';
    if (id.isEmpty || keyId.isEmpty) {
      throw const TuitionFeeException(
        'The payment order response was incomplete.',
      );
    }
    return RazorpayOrder(
      id: id,
      amount: data['amount'] is num ? (data['amount'] as num).toInt() : amount,
      currency: data['currency']?.toString() ?? 'INR',
      keyId: keyId,
    );
  }

  Future<void> verifyPayment({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    final data = await _post('/api/v1/payments/razorpay/verify', {
      'razorpay_payment_id': paymentId,
      'razorpay_order_id': orderId,
      'razorpay_signature': signature,
    });
    if (data['success'] != true) {
      throw const TuitionFeeException(
        'Payment verification was not completed.',
      );
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    var token = await _accessTokenProvider();
    var response = await _client.post(
      _baseUri.resolve(path),
      headers: {
        'authorization': 'Bearer $token',
        'x-client-surface': 'app',
        'content-type': 'application/json',
        'accept': 'application/json',
      },
      body: jsonEncode(body),
    );
    if (response.statusCode == 401) {
      final firstError = _errorMessage(response.body);
      // A Razorpay credential rejection is a backend configuration problem,
      // not an expired SuperCampus session. Do not hide it behind a token retry.
      if (!firstError.toLowerCase().contains('razorpay')) {
        token = await _accessTokenProvider(forceRefresh: true);
        response = await _client.post(
          _baseUri.resolve(path),
          headers: {
            'authorization': 'Bearer $token',
            'x-client-surface': 'app',
            'content-type': 'application/json',
            'accept': 'application/json',
          },
          body: jsonEncode(body),
        );
      }
    }
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded is! Map) {
      throw TuitionFeeException(_errorMessage(response.body, decoded: decoded));
    }
    return Map<String, dynamic>.from(decoded);
  }

  String _errorMessage(String body, {Object? decoded}) {
    Object? value = decoded;
    if (value == null) {
      try {
        value = jsonDecode(body);
      } catch (_) {
        value = null;
      }
    }
    if (value is Map) {
      final error = value['error'];
      if (error is String && error.trim().isNotEmpty) return error;
      if (error is Map) {
        final message = error['message']?.toString().trim();
        if (message != null && message.isNotEmpty) return message;
      }
    }
    return 'The payment request could not be completed.';
  }

  Future<http.Response> _get(String token) => _client.get(
    _baseUri.resolve('/api/v1/student/fees'),
    headers: {
      'authorization': 'Bearer $token',
      'x-client-surface': 'app',
      'accept': 'application/json',
    },
  );
}

class TuitionFeeException implements Exception {
  const TuitionFeeException(this.message);
  final String message;
}
