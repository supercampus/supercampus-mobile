import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/features/canteen/data/backend_canteen_repository.dart';

void main() {
  test('creates a wallet top-up order in paise', () async {
    final repository = BackendCanteenRepository(
      baseUrl: 'https://api.example.test',
      accessToken: 'student-token',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/payments/razorpay/orders');
        expect(request.headers['authorization'], 'Bearer student-token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['amount'], 50000);
        expect(body['currency'], 'INR');
        expect(body['purpose'], 'wallet_top_up');
        return http.Response(
          jsonEncode({
            'order_id': 'order_wallet',
            'amount': 50000,
            'currency': 'INR',
            'key_id': 'rzp_test_public',
          }),
          201,
        );
      }),
    );

    final order = await repository.createWalletTopUpOrder(500);

    expect(order.id, 'order_wallet');
    expect(order.amount, 50000);
  });

  test('uses verified server balance for a wallet top-up', () async {
    final repository = BackendCanteenRepository(
      baseUrl: 'https://api.example.test',
      accessToken: 'student-token',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/payments/razorpay/verify');
        expect(jsonDecode(request.body), {
          'razorpay_payment_id': 'pay_wallet',
          'razorpay_order_id': 'order_wallet',
          'razorpay_signature': 'signed',
        });
        return http.Response(
          jsonEncode({
            'success': true,
            'order_id': 'order_wallet',
            'payment_id': 'pay_wallet',
            'purpose': 'wallet_top_up',
            'wallet_balance': 725,
            'wallet_transaction': {
              'id': 'wallet-transaction',
              'amount': 500,
              'transactionType': 'online_top_up',
              'description': 'Razorpay wallet top-up',
              'createdAt': '2026-09-04T12:00:00Z',
            },
          }),
          200,
        );
      }),
    );

    final result = await repository.verifyWalletTopUp(
      paymentId: 'pay_wallet',
      orderId: 'order_wallet',
      signature: 'signed',
    );

    expect(result.balance, 725);
    expect(result.transaction.amount, 500);
    expect(result.transaction.description, 'Razorpay wallet top-up');
  });
}
