import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../screens/tuition_fee/razorpay_checkout.dart';
import '../../authentication/data/auth_http_client.dart';
import '../../authentication/data/auth_repository.dart';
import 'payment_request_models.dart';

/// Bumped whenever payment requests or online payments change: a realtime
/// `payments.*` event, or a payment the student just made. Home and the
/// admin pages listen and reload.
final ValueNotifier<int> paymentRequestRevision = ValueNotifier<int>(0);

bool isPaymentEvent(String type) => type.startsWith('payments.');

class PaymentRequestException implements Exception {
  const PaymentRequestException(this.message, {this.cancelled = false});

  final String message;
  final bool cancelled;

  @override
  String toString() => message;
}

/// What the student home needs: the requests addressed to the viewer.
abstract interface class StudentPaymentRequestSource {
  Future<StudentPaymentRequests> mine();
}

/// Pays a request through Razorpay checkout.
abstract interface class PaymentRequestCheckout {
  Future<void> payOnline(
    StudentPaymentRequest request, {
    required String customerName,
    required String customerEmail,
  });
}

/// Accounts office operations on payment requests and online payments.
abstract interface class PaymentRequestAdminRepository {
  Future<List<PaymentRequestSummary>> list({String? status});
  Future<PaymentRequestSummary> detail(String requestId);
  Future<PaymentRequestOptions> options();
  Future<List<PaymentStudent>> searchStudents(String query);
  Future<PaymentRequestSummary> create(NewPaymentRequest request);
  Future<PaymentRequestSummary> cancel(String requestId, {String? reason});
  Future<PaymentRequestSummary> markPaid(
    String requestId,
    String payerId, {
    required String method,
    String? reference,
    String? note,
  });
  Future<OnlinePaymentsReport> onlinePayments({
    DateTime? from,
    DateTime? to,
    String? status,
    String? query,
  });
  Future<OnlinePaymentsSyncResult> syncOnlinePayments({
    DateTime? from,
    DateTime? to,
  });
}

class BackendPaymentRequestRepository
    implements
        StudentPaymentRequestSource,
        PaymentRequestCheckout,
        PaymentRequestAdminRepository {
  BackendPaymentRequestRepository({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    http.Client? client,
    RazorpayCheckoutClient checkout = const RazorpayCheckoutClient(),
  }) : _baseUri = Uri.parse(baseUrl.replaceFirst(RegExp(r'/$'), '')),
       _accessTokenProvider = accessTokenProvider,
       _client = client ?? createAuthHttpClient(),
       _checkout = checkout;

  final Uri _baseUri;
  final AccessTokenProvider _accessTokenProvider;
  final http.Client _client;
  final RazorpayCheckoutClient _checkout;

  static const _operations = '/api/v1/operations';

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = _baseUri.resolve(path);
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  Map<String, dynamic> _data(Map<String, dynamic> body) =>
      body['data'] as Map<String, dynamic>? ?? const {};

  @override
  Future<StudentPaymentRequests> mine() async {
    final data = _data(
      await _request(
        (headers) => _client.get(
          _uri('$_operations/payment-requests/mine'),
          headers: headers,
        ),
      ),
    );
    return StudentPaymentRequests(
      requests: (data['requests'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(StudentPaymentRequest.fromJson)
          .toList(),
      onlinePaymentsEnabled: data['onlinePaymentsEnabled'] == true,
    );
  }

  @override
  Future<void> payOnline(
    StudentPaymentRequest request, {
    required String customerName,
    required String customerEmail,
  }) async {
    final receipt = 'pr-${request.payerId.replaceAll('-', '')}';
    final order = await _request(
      (headers) => _client.post(
        _uri('/api/v1/payments/razorpay/orders'),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({
          'purpose': 'payment_request',
          'referenceId': request.payerId,
          'amount': (request.amount * 100).round(),
          'currency': request.currency,
          'receipt': receipt.length > 40 ? receipt.substring(0, 40) : receipt,
        }),
      ),
    );
    final orderId = order['order_id']?.toString() ?? '';
    final keyId = order['key_id']?.toString() ?? '';
    if (orderId.isEmpty || keyId.isEmpty) {
      throw const PaymentRequestException(
        'Online payment could not be started. Try again.',
      );
    }
    final RazorpayCheckoutResult result;
    try {
      result = await _checkout.open(
        keyId: keyId,
        orderId: orderId,
        amount: (order['amount'] as num?)?.toInt() ??
            (request.amount * 100).round(),
        currency: order['currency']?.toString() ?? request.currency,
        name: 'SuperCampus',
        description: request.title,
        customerName: customerName,
        customerEmail: customerEmail,
      );
    } on RazorpayCheckoutException catch (error) {
      throw PaymentRequestException(error.message, cancelled: error.cancelled);
    }
    final verified = await _request(
      (headers) => _client.post(
        _uri('/api/v1/payments/razorpay/verify'),
        headers: {...headers, 'content-type': 'application/json'},
        body: jsonEncode({
          'razorpay_payment_id': result.paymentId,
          'razorpay_order_id': result.orderId,
          'razorpay_signature': result.signature,
        }),
      ),
    );
    if (verified['success'] != true) {
      throw const PaymentRequestException(
        'The payment could not be verified. If money left your account, '
        'the accounts office will reconcile it.',
      );
    }
    paymentRequestRevision.value++;
  }

  @override
  Future<List<PaymentRequestSummary>> list({String? status}) async {
    final data = _data(
      await _request(
        (headers) => _client.get(
          _uri('$_operations/payment-requests', {
            if (status != null && status != 'all') 'status': status,
          }),
          headers: headers,
        ),
      ),
    );
    return (data['requests'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PaymentRequestSummary.fromJson)
        .toList();
  }

  @override
  Future<PaymentRequestSummary> detail(String requestId) async =>
      PaymentRequestSummary.fromJson(
        _data(
          await _request(
            (headers) => _client.get(
              _uri('$_operations/payment-requests/$requestId'),
              headers: headers,
            ),
          ),
        ),
      );

  @override
  Future<PaymentRequestOptions> options() async => PaymentRequestOptions.fromJson(
    _data(
      await _request(
        (headers) => _client.get(
          _uri('$_operations/payment-requests/options'),
          headers: headers,
        ),
      ),
    ),
  );

  @override
  Future<List<PaymentStudent>> searchStudents(String query) async {
    final data = _data(
      await _request(
        (headers) => _client.get(
          _uri('$_operations/payment-requests/students', {'q': query.trim()}),
          headers: headers,
        ),
      ),
    );
    return (data['students'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PaymentStudent.fromJson)
        .toList();
  }

  @override
  Future<PaymentRequestSummary> create(NewPaymentRequest request) async {
    final created = PaymentRequestSummary.fromJson(
      _data(
        await _request(
          (headers) => _client.post(
            _uri('$_operations/payment-requests'),
            headers: {...headers, 'content-type': 'application/json'},
            body: jsonEncode(request.toJson()),
          ),
        ),
      ),
    );
    paymentRequestRevision.value++;
    return created;
  }

  @override
  Future<PaymentRequestSummary> cancel(
    String requestId, {
    String? reason,
  }) async {
    final cancelled = PaymentRequestSummary.fromJson(
      _data(
        await _request(
          (headers) => _client.post(
            _uri('$_operations/payment-requests/$requestId/cancel'),
            headers: {...headers, 'content-type': 'application/json'},
            body: jsonEncode({
              if (reason != null && reason.trim().isNotEmpty)
                'reason': reason.trim(),
            }),
          ),
        ),
      ),
    );
    paymentRequestRevision.value++;
    return cancelled;
  }

  @override
  Future<PaymentRequestSummary> markPaid(
    String requestId,
    String payerId, {
    required String method,
    String? reference,
    String? note,
  }) async {
    final updated = PaymentRequestSummary.fromJson(
      _data(
        await _request(
          (headers) => _client.post(
            _uri(
              '$_operations/payment-requests/$requestId/payers/$payerId/mark-paid',
            ),
            headers: {...headers, 'content-type': 'application/json'},
            body: jsonEncode({
              'method': method,
              if (reference != null && reference.trim().isNotEmpty)
                'reference': reference.trim(),
              if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
            }),
          ),
        ),
      ),
    );
    paymentRequestRevision.value++;
    return updated;
  }

  @override
  Future<OnlinePaymentsReport> onlinePayments({
    DateTime? from,
    DateTime? to,
    String? status,
    String? query,
  }) async => OnlinePaymentsReport.fromJson(
    _data(
      await _request(
        (headers) => _client.get(
          _uri('$_operations/online-payments', {
            if (from != null) 'from': formatApiDate(from),
            if (to != null) 'to': formatApiDate(to),
            if (status != null && status != 'all') 'status': status,
            if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
          }),
          headers: headers,
        ),
      ),
    ),
  );

  @override
  Future<OnlinePaymentsSyncResult> syncOnlinePayments({
    DateTime? from,
    DateTime? to,
  }) async {
    final result = OnlinePaymentsSyncResult.fromJson(
      _data(
        await _request(
          (headers) => _client.post(
            _uri('$_operations/online-payments/sync'),
            headers: {...headers, 'content-type': 'application/json'},
            body: jsonEncode({
              if (from != null) 'from': formatApiDate(from),
              if (to != null) 'to': formatApiDate(to),
            }),
          ),
        ),
      ),
    );
    paymentRequestRevision.value++;
    return result;
  }

  Future<Map<String, dynamic>> _request(
    Future<http.Response> Function(Map<String, String> headers) send,
  ) async {
    Map<String, String> headers(String token) => {
      'authorization': 'Bearer $token',
      'x-client-surface': 'app',
      'accept': 'application/json',
    };
    var response = await send(headers(await _accessTokenProvider()));
    if (response.statusCode == 401) {
      response = await send(
        headers(await _accessTokenProvider(forceRefresh: true)),
      );
    }
    final text = response.body.trim();
    Map<String, dynamic> body = const {};
    if (text.isNotEmpty) {
      try {
        final decoded = jsonDecode(text);
        if (decoded is Map<String, dynamic>) body = decoded;
      } on FormatException {
        // Reported below with the status code.
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body['error'];
      final message = error is Map
          ? (error['message'] ?? error['description'])?.toString()
          : error?.toString();
      throw PaymentRequestException(
        message ?? 'Request failed (${response.statusCode})',
      );
    }
    return body;
  }
}
