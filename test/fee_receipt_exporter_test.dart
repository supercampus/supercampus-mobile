import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/screens/tuition_fee/fee_receipt_exporter.dart';
import 'package:supercampus_mobile/src/screens/tuition_fee/tuition_fee_repository.dart';

void main() {
  test('verified fee receipt is generated as a PDF', () async {
    const session = UserSession(
      email: 'student@example.edu',
      displayName: 'Student Name',
      idNumber: '413225000001',
      role: UserRole.student,
    );
    const payment = StudentFeeRecord(
      id: 'record-1',
      type: 'payments',
      data: {
        'amount': 1250,
        'paymentReference': 'pay_verified_1',
        'razorpayOrderId': 'order_1',
        'receipt': 'sc_receipt_1',
        'paymentDate': '2026-09-10T12:00:00Z',
        'method': 'Razorpay',
        'status': 'verified',
      },
    );

    final bytes = await const FeeReceiptExporter().build(session, payment);

    expect(bytes.length, greaterThan(500));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
