import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supercampus_mobile/src/features/canteen/data/canteen_models.dart';
import 'package:supercampus_mobile/src/features/canteen/data/mock_canteen_repository.dart';
import 'package:supercampus_mobile/src/features/canteen/data/wallet_transaction_detail.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/student_wallet_screen.dart';
import 'package:supercampus_mobile/src/features/canteen/presentation/wallet_transaction_details_screen.dart';
import 'package:supercampus_mobile/src/features/canteen/services/wallet_receipt_pdf.dart';

Future<CanteenStore> _loadStore(WidgetTester tester) async {
  final repository = MockCanteenRepository(
    studentName: 'Test Student',
    email: 'student@example.com',
  );
  return (await tester.runAsync(repository.loadStore))!;
}

WalletTransactionDetail _orderDetail() => WalletTransactionDetail.fromJson({
  'id': '9c1238bb-bd08-4be4-9d6f-a79cd764adb2',
  'shopKey': 'mec-canteen',
  'shopName': 'Mec Canteen',
  'amount': -250.0,
  'transactionType': 'order_debit',
  'description': 'Mec Canteen order',
  'referenceId': '7c3be48e-95fc-4d58-b7c7-9e34340a9462',
  'createdAt': '2026-09-27T19:13:01.204454+00:00',
  'balanceAfter': 250.0,
  'order': {
    'id': '7c3be48e-95fc-4d58-b7c7-9e34340a9462',
    'orderNumber': 60,
    'status': 'completed',
    'fulfilmentMode': 'pickup',
    'total': 250.0,
    'lines': [
      {'name': 'Masala dosa', 'price': 65.0, 'quantity': 2},
      {'name': 'Filter coffee', 'price': 120.0, 'quantity': 1},
    ],
  },
  'customer': {
    'name': 'Nandhini Subramanian',
    'studentNumber': 'MEC26AI007',
    'email': 'student007@mec.local',
  },
  'institutionName': 'Madras Engineering College',
});

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
  });

  Future<CanteenStore> pumpWallet(
    WidgetTester tester, {
    WalletTransactionDetailLoader? loader,
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = await _loadStore(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StudentWalletSheet(
            store: store,
            onTopUp: (_) async => throw UnimplementedError(),
            loadTransactionDetail: loader,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transactions'));
    await tester.pumpAndSettle();
    return store;
  }

  testWidgets('tapping a transaction opens its details page', (tester) async {
    final store = await pumpWallet(tester);
    final transaction = store.walletTransactions.first;

    await tester.tap(find.text(transaction.description));
    await tester.pumpAndSettle();

    expect(find.text('Transaction details'), findsOneWidget);
    expect(find.text(transaction.id), findsOneWidget);
    expect(find.byKey(const Key('transaction-detail-amount')), findsOneWidget);
    final amount = tester.widget<Text>(
      find.byKey(const Key('transaction-detail-amount')),
    );
    expect(amount.data, '-₹${transaction.amount.toStringAsFixed(0)}');
    expect(find.text('Download invoice (PDF)'), findsOneWidget);
  });

  testWidgets('the server record adds order lines, references and a copy', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final detail = _orderDetail();
    final store = await pumpWallet(tester, loader: (_) async => detail);

    await tester.tap(find.text(store.walletTransactions.first.description));
    await tester.pumpAndSettle();

    expect(find.text(detail.id), findsOneWidget);
    expect(find.text('-₹250'), findsOneWidget);
    expect(find.text('#0060'), findsOneWidget);
    expect(find.text('Masala dosa'), findsOneWidget);
    expect(find.text('MEC26AI007'), findsOneWidget);
    expect(find.text('Madras Engineering College'), findsOneWidget);

    await tester.tap(find.byTooltip('Copy transaction ID'));
    await tester.pump();
    expect(copied, detail.id);
    expect(find.text('Transaction ID copied'), findsOneWidget);
  });

  test('details derive the receipt number and file name from the id', () {
    final detail = _orderDetail();
    expect(detail.kind, WalletTransactionKind.orderPayment);
    expect(detail.receiptNumber, 'SC-9C1238BB');
    expect(detail.receiptFileName, 'SuperCampus-receipt-9c1238bb.pdf');
    expect(detail.paymentMethod, 'SuperCampus wallet');
    expect(detail.order!.lines.last.total, 120);
  });

  test('online top-ups expose their gateway references only', () {
    final detail = WalletTransactionDetail.fromJson({
      'id': 'a1b2c3d4-0000-0000-0000-000000000000',
      'amount': 500,
      'transactionType': 'online_top_up',
      'description': 'Razorpay wallet top-up',
      'referenceId': 'order_XYZ',
      'paymentId': 'pay_ABC',
      'createdAt': '2026-09-27T10:00:00Z',
    });
    expect(detail.kind, WalletTransactionKind.onlineTopUp);
    expect(detail.gatewayOrderId, 'order_XYZ');
    expect(detail.paymentId, 'pay_ABC');
    expect(detail.order, isNull);
    expect(detail.balanceAfter, isNull);
  });

  test('the receipt PDF builds with an embedded rupee-capable font', () async {
    final regular = pw.Font.ttf(
      ByteData.sublistView(
        File('assets/fonts/Poppins-Regular.ttf').readAsBytesSync(),
      ),
    );
    final medium = pw.Font.ttf(
      ByteData.sublistView(
        File('assets/fonts/Poppins-Medium.ttf').readAsBytesSync(),
      ),
    );
    final bytes = await WalletReceiptPdf.build(
      _orderDetail(),
      regular: regular,
      medium: medium,
    );
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });
}
