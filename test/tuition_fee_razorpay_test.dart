import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/screens/tuition_fee/tuition_fee_repository.dart';

void main() {
  test('creates an authenticated Razorpay order in paise', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/payments/razorpay/orders');
      expect(request.headers['authorization'], 'Bearer app-token');
      expect(jsonDecode(request.body), {
        'amount': 12500,
        'currency': 'INR',
        'receipt': 'receipt-1',
      });
      return http.Response(
        jsonEncode({
          'order_id': 'order_test',
          'amount': 12500,
          'currency': 'INR',
          'key_id': 'rzp_test_public',
        }),
        201,
      );
    });
    final repository = TuitionFeeRepository(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'app-token',
      client: client,
    );

    final order = await repository.createOrder(
      amount: 12500,
      receipt: 'receipt-1',
    );

    expect(order.id, 'order_test');
    expect(order.amount, 12500);
    expect(order.currency, 'INR');
    expect(order.keyId, 'rzp_test_public');
  });

  test('sends every checkout field for server-side verification', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/payments/razorpay/verify');
      expect(jsonDecode(request.body), {
        'razorpay_payment_id': 'pay_test',
        'razorpay_order_id': 'order_test',
        'razorpay_signature': 'signature_test',
      });
      return http.Response(
        jsonEncode({
          'success': true,
          'order_id': 'order_test',
          'payment_id': 'pay_test',
        }),
        200,
      );
    });
    final repository = TuitionFeeRepository(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'app-token',
      client: client,
    );

    await repository.verifyPayment(
      paymentId: 'pay_test',
      orderId: 'order_test',
      signature: 'signature_test',
    );
  });

  test('surfaces a signature mismatch and never reports success', () async {
    final repository = TuitionFeeRepository(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'app-token',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': 'Payment signature verification failed',
            'code': 'bad_request',
          }),
          400,
        ),
      ),
    );

    await expectLater(
      repository.verifyPayment(
        paymentId: 'pay_test',
        orderId: 'order_test',
        signature: 'tampered',
      ),
      throwsA(
        isA<TuitionFeeException>().having(
          (error) => error.message,
          'message',
          contains('signature verification failed'),
        ),
      ),
    );
  });

  test('loads the access-controlled admin fee workspace', () async {
    final requestedPaths = <String>[];
    final repository = TuitionFeeRepository(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'admin-token',
      client: MockClient((request) async {
        requestedPaths.add(request.url.path);
        expect(request.headers['authorization'], 'Bearer admin-token');
        if (request.url.path == '/api/v1/student-master') {
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'id': 'student-record',
                  'userId': 'student-user',
                  'rollNo': '413225243049',
                  'name': 'Vishnu S',
                  'department': 'AIDS',
                  'email': 'vishnu@mec.local',
                },
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'data': []}), 200);
      }),
    );

    final data = await repository.loadAdmin();

    expect(
      requestedPaths,
      containsAll(['/api/v1/fees/records', '/api/v1/student-master']),
    );
    expect(requestedPaths, isNot(contains('/api/v1/student/fees')));
    expect(data.students.single.rollNumber, '413225243049');
  });

  test('creates a fee assignment linked to the selected student', () async {
    final repository = TuitionFeeRepository(
      baseUrl: 'https://api.example.test',
      accessTokenProvider: ({bool forceRefresh = false}) async => 'admin-token',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/fees/records');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['recordType'], 'fee_assignment');
        final data = body['data'] as Map<String, dynamic>;
        expect(data['studentId'], 'student-user');
        expect(data['studentNumber'], '413225243049');
        expect(data['amountPerStudent'], 25000);
        return http.Response(jsonEncode({'id': 'assignment-1'}), 201);
      }),
    );

    await repository.createFeeAssignment(
      student: const FeeStudent(
        id: 'student-record',
        userId: 'student-user',
        rollNumber: '413225243049',
        name: 'Vishnu S',
        department: 'AIDS',
        email: 'vishnu@mec.local',
      ),
      title: 'Semester fee',
      academicContext: '2026–27',
      amount: 25000,
    );
  });
}
