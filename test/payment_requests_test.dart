import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supercampus_mobile/src/core/access/effective_permissions.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';
import 'package:supercampus_mobile/src/features/admin_portal/presentation/admin_dashboard_screen.dart';
import 'package:supercampus_mobile/src/features/authentication/data/auth_repository.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/today_glance.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/payment_request_card.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/status_card_builder.dart';
import 'package:supercampus_mobile/src/features/modules/presentation/widgets/status_cards/status_card_models.dart';
import 'package:supercampus_mobile/src/features/payment_requests/data/payment_request_models.dart';
import 'package:supercampus_mobile/src/features/payment_requests/data/payment_request_repository.dart';
import 'package:supercampus_mobile/src/features/payment_requests/presentation/admin_payment_requests_page.dart';
import 'package:supercampus_mobile/src/features/payment_requests/presentation/online_payments_page.dart';
import 'package:supercampus_mobile/src/features/payment_requests/presentation/payment_request_sheet.dart';
import 'package:supercampus_mobile/src/screens/tuition_fee/razorpay_checkout.dart';

StudentPaymentRequest _request({
  String id = 'payer-1',
  PaymentRequestStatus status = PaymentRequestStatus.pending,
  DateTime? due,
  DateTime? paidAt,
  bool showOnDashboard = true,
  String title = 'Library late fine',
}) => StudentPaymentRequest(
  payerId: id,
  requestId: 'req-$id',
  purpose: 'fine',
  purposeLabel: 'Fine',
  title: title,
  description: 'Late return of two library books',
  amount: 150,
  status: status,
  dueDate: due,
  paidAt: paidAt,
  showOnDashboard: showOnDashboard,
);

class _FakeCheckout implements PaymentRequestCheckout {
  final paid = <String>[];
  Object? failWith;

  @override
  Future<void> payOnline(
    StudentPaymentRequest request, {
    required String customerName,
    required String customerEmail,
  }) async {
    if (failWith != null) throw failWith!;
    paid.add(request.payerId);
  }
}

class _FakeRazorpay implements RazorpayCheckoutClient {
  String? openedOrder;

  @override
  Future<RazorpayCheckoutResult> open({
    required String keyId,
    required String orderId,
    required int amount,
    required String currency,
    required String name,
    required String description,
    required String customerName,
    required String customerEmail,
  }) async {
    openedOrder = orderId;
    return RazorpayCheckoutResult(
      paymentId: 'pay_1',
      orderId: orderId,
      signature: 'sig',
    );
  }
}

Map<String, Object?> _summaryJson({
  String status = 'active',
  List<Map<String, Object?>> payers = const [],
}) => {
  'id': 'req-1',
  'purpose': 'electricity',
  'purposeLabel': 'Electricity bill',
  'title': 'Hostel electricity bill',
  'description': 'September electricity usage',
  'amount': 320.5,
  'currency': 'INR',
  'dueDate': '2026-10-15',
  'showOnDashboard': true,
  'targetMode': 'cohort',
  'targetDepartments': ['AIDS'],
  'targetYears': ['I'],
  'status': status,
  'overdue': false,
  'payerCount': 2,
  'paidCount': 1,
  'pendingCount': 1,
  'collectedAmount': 320.5,
  'expectedAmount': 641,
  'createdAt': '2026-09-29T08:00:00Z',
  'payers': payers,
  'canManage': true,
};

const _payers = [
  {
    'id': 'p-1',
    'userId': 'u-1',
    'studentNumber': 'MEC26AI001',
    'name': 'Priya Kumar',
    'department': 'AIDS',
    'year': 'I',
    'amount': 320.5,
    'status': 'pending',
  },
  {
    'id': 'p-2',
    'userId': 'u-2',
    'studentNumber': 'MEC26AI002',
    'name': 'Vignesh Kumar',
    'department': 'AIDS',
    'year': 'I',
    'amount': 320.5,
    'status': 'paid',
    'paymentMethod': 'razorpay',
    'paidAt': '2026-09-29T09:00:00Z',
  },
];

BackendPaymentRequestRepository _repository(
  Future<http.Response> Function(http.Request request) handler, {
  RazorpayCheckoutClient checkout = const RazorpayCheckoutClient(),
}) => BackendPaymentRequestRepository(
  baseUrl: 'https://api.test',
  accessTokenProvider: ({bool forceRefresh = false}) async => 'token',
  client: MockClient(handler),
  checkout: checkout,
);

http.Response _json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {
      'content-type': 'application/json; charset=utf-8',
    });

Future<void> _pumpPage(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: page));
  await tester.pumpAndSettle();
}

void main() {
  group('home status cards', () {
    final now = DateTime(2026, 9, 29, 10);

    test('open requests show, overdue first; stale paid and hidden do not', () {
      final cards = buildPaymentRequestCards(
        [
          _request(id: 'a', due: DateTime(2026, 10, 20), title: 'Later'),
          _request(
            id: 'b',
            status: PaymentRequestStatus.overdue,
            due: DateTime(2026, 9, 20),
            title: 'Overdue',
          ),
          _request(
            id: 'c',
            status: PaymentRequestStatus.paid,
            paidAt: now.subtract(const Duration(days: 10)),
          ),
          _request(id: 'd', showOnDashboard: false),
          _request(
            id: 'e',
            status: PaymentRequestStatus.paid,
            paidAt: now.subtract(const Duration(hours: 5)),
            title: 'Just paid',
          ),
        ],
        now: now,
      );
      expect(cards.map((c) => c.request.title), [
        'Overdue',
        'Later',
        'Just paid',
      ]);
    });

    test('the student carousel carries payment cards from the glance', () {
      final checkout = _FakeCheckout();
      final cards = buildStudentStatusCards(
        glance: GlanceFacts(
          paymentRequests: [_request()],
          onlinePaymentsEnabled: true,
          paymentCheckout: checkout,
        ),
        now: now,
      );
      final card = cards.whereType<PaymentRequestCardData>().single;
      expect(card.type, StatusCardType.paymentRequest);
      expect(card.canPayOnline, isTrue);
    });

    testWidgets('card shows title, purpose, amount, due date and status', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PaymentRequestCard(
              data: PaymentRequestCardData(
                request: _request(
                  status: PaymentRequestStatus.overdue,
                  due: DateTime(2026, 9, 20),
                ),
              ),
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      expect(find.text('Library late fine'), findsOneWidget);
      expect(find.text('FINE'), findsOneWidget);
      expect(find.text('₹150'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);
      expect(find.text('Was due 20 Sep 2026'), findsOneWidget);
      await tester.tap(find.byType(PaymentRequestCard));
      expect(tapped, isTrue);
    });

    testWidgets('paid card says when it was paid', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PaymentRequestCard(
              data: PaymentRequestCardData(
                request: _request(
                  status: PaymentRequestStatus.paid,
                  paidAt: DateTime(2026, 9, 28),
                ),
              ),
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('Paid'), findsOneWidget);
      expect(find.text('Paid 28 Sep 2026'), findsOneWidget);
    });

    testWidgets('sheet pays online when Razorpay is available', (tester) async {
      final checkout = _FakeCheckout();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PaymentRequestSheet(
              data: PaymentRequestCardData(
                request: _request(),
                onlinePaymentsEnabled: true,
                checkout: checkout..failWith = const PaymentRequestException(
                  'Razorpay Standard Checkout is available in the web portal.',
                ),
              ),
              customerName: 'Priya',
              customerEmail: 'priya@mec.local',
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('payment-request-pay')));
      await tester.pumpAndSettle();
      expect(
        find.text('Razorpay Standard Checkout is available in the web portal.'),
        findsOneWidget,
      );
      checkout.failWith = null;
      await tester.tap(find.byKey(const ValueKey('payment-request-pay')));
      await tester.pump();
      expect(checkout.paid, ['payer-1']);
      // The success overlay closes itself after a moment.
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Payment received'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('without online payment the sheet points to the office', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PaymentRequestSheet(
              data: PaymentRequestCardData(request: _request()),
              customerName: 'Priya',
              customerEmail: 'priya@mec.local',
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('payment-request-pay')), findsNothing);
      expect(find.textContaining('accounts office'), findsOneWidget);
    });
  });

  group('repository', () {
    test('pays a request: server-priced order, checkout, verify', () async {
      final bodies = <String, Map<String, dynamic>>{};
      final razorpay = _FakeRazorpay();
      final repository = _repository((request) async {
        bodies[request.url.path] = jsonDecode(request.body)
            as Map<String, dynamic>;
        if (request.url.path.endsWith('/razorpay/orders')) {
          return _json({
            'order_id': 'order_1',
            'amount': 15000,
            'currency': 'INR',
            'key_id': 'rzp_test',
          }, 201);
        }
        return _json({'success': true, 'purpose': 'payment_request'});
      }, checkout: razorpay);
      final before = paymentRequestRevision.value;
      await repository.payOnline(
        _request(),
        customerName: 'Priya',
        customerEmail: 'priya@mec.local',
      );
      final order = bodies['/api/v1/payments/razorpay/orders']!;
      expect(order['purpose'], 'payment_request');
      expect(order['referenceId'], 'payer-1');
      expect((order['receipt'] as String).length, lessThanOrEqualTo(40));
      expect(razorpay.openedOrder, 'order_1');
      expect(
        bodies['/api/v1/payments/razorpay/verify']!['razorpay_payment_id'],
        'pay_1',
      );
      expect(paymentRequestRevision.value, greaterThan(before));
    });

    test('surfaces the API error message', () async {
      final repository = _repository(
        (_) async => _json({
          'error': 'This request is already paid',
          'code': 'conflict',
        }, 409),
      );
      expect(
        () => repository.list(),
        throwsA(
          isA<PaymentRequestException>().having(
            (e) => e.message,
            'message',
            'This request is already paid',
          ),
        ),
      );
    });
  });

  group('admin payment requests', () {
    testWidgets('lists requests and marks a student paid in cash', (
      tester,
    ) async {
      Map<String, dynamic>? markBody;
      final repository = _repository((request) async {
        final path = request.url.path;
        if (path.endsWith('/payment-requests')) {
          return _json({
            'data': {
              'requests': [_summaryJson()],
              'canManage': true,
            },
          });
        }
        if (path.endsWith('/payment-requests/options')) {
          return _json({'data': <String, Object?>{}});
        }
        if (path.endsWith('/mark-paid')) {
          markBody = jsonDecode(request.body) as Map<String, dynamic>;
          return _json({
            'data': _summaryJson(
              status: 'closed',
              payers: [
                {..._payers[0], 'status': 'paid', 'paymentMethod': 'cash'},
                _payers[1],
              ],
            ),
          });
        }
        if (path.endsWith('/payment-requests/req-1')) {
          return _json({'data': _summaryJson(payers: _payers)});
        }
        return _json({'data': <String, Object?>{}});
      });
      await _pumpPage(
        tester,
        AdminPaymentRequestsPage(repository: repository, canManage: true),
      );
      expect(find.text('Hostel electricity bill'), findsOneWidget);
      expect(find.textContaining('1 of 2 paid'), findsOneWidget);
      expect(find.byKey(const ValueKey('payment-requests-new')), findsOneWidget);

      await tester.tap(find.text('Hostel electricity bill'));
      await tester.pumpAndSettle();
      expect(find.text('NOT PAID YET · 1'), findsOneWidget);
      expect(find.text('PAID · 1'), findsOneWidget);

      await tester.tap(find.text('Priya Kumar'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('payment-request-confirm-paid')),
      );
      await tester.pumpAndSettle();
      expect(markBody, {'method': 'cash'});
      expect(find.text('PAID · 2'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cancels an active request', (tester) async {
      var cancelled = false;
      final repository = _repository((request) async {
        final path = request.url.path;
        if (path.endsWith('/cancel')) {
          cancelled = true;
          return _json({'data': _summaryJson(status: 'cancelled')});
        }
        if (path.endsWith('/payment-requests/req-1')) {
          return _json({'data': _summaryJson(payers: _payers)});
        }
        return _json({'data': <String, Object?>{}});
      });
      await _pumpPage(
        tester,
        PaymentRequestDetailPage(
          repository: repository,
          requestId: 'req-1',
          canManage: true,
        ),
      );
      await tester.tap(find.byKey(const ValueKey('payment-request-cancel')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('payment-request-confirm-cancel')),
      );
      await tester.pumpAndSettle();
      expect(cancelled, isTrue);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.byKey(const ValueKey('payment-request-cancel')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('read-only viewers cannot create or mark paid', (tester) async {
      final repository = _repository((request) async {
        if (request.url.path.endsWith('/payment-requests')) {
          return _json({
            'data': {
              'requests': [_summaryJson()],
            },
          });
        }
        return _json({'data': _summaryJson(payers: _payers)});
      });
      await _pumpPage(
        tester,
        AdminPaymentRequestsPage(repository: repository, canManage: false),
      );
      expect(find.byKey(const ValueKey('payment-requests-new')), findsNothing);
      await tester.tap(find.text('Hostel electricity bill'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('payment-request-cancel')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('create form validates, then sends the request', (
      tester,
    ) async {
      Map<String, dynamic>? sent;
      final repository = _repository((request) async {
        final path = request.url.path;
        if (path.endsWith('/options')) {
          return _json({
            'data': {
              'departments': ['AIDS', 'CSE'],
              'years': ['I'],
              'studentCount': 200,
              'onlinePaymentsEnabled': true,
            },
          });
        }
        if (request.method == 'POST' && path.endsWith('/payment-requests')) {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return _json({'data': _summaryJson()}, 201);
        }
        return _json({'data': <String, Object?>{}});
      });
      await _pumpPage(tester, CreatePaymentRequestPage(repository: repository));
      expect(find.text('Every active student (200).'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('payment-request-title')),
        'Hostel electricity bill',
      );
      await tester.enterText(
        find.byKey(const ValueKey('payment-request-description')),
        'short',
      );
      await tester.enterText(
        find.byKey(const ValueKey('payment-request-amount')),
        '320.50',
      );
      await tester.tap(find.byKey(const ValueKey('payment-request-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Describe it in at least 10 characters'), findsOneWidget);
      expect(sent, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('payment-request-description')),
        'September electricity usage',
      );
      await tester.tap(find.text('Electricity bill'));
      await tester.tap(find.text('Year / dept'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AIDS'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('payment-request-submit')));
      await tester.pumpAndSettle();
      expect(sent, isNotNull);
      expect(sent!['purpose'], 'electricity');
      expect(sent!['amount'], 320.5);
      expect(sent!['target'], 'cohort');
      expect(sent!['departments'], ['AIDS']);
      expect(sent!['showOnDashboard'], isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('online payments', () {
    Map<String, Object?> report({bool settled = false}) => {
      'from': '2026-08-31',
      'to': '2026-09-29',
      'summary': {
        'totalRecords': 3,
        'creditedCount': 1,
        'creditedAmount': 400,
        'capturedNotCreditedCount': 1,
        'capturedNotCreditedAmount': 75,
        'pendingCount': 1,
        'failedCount': 0,
        'settlementKnownCount': settled ? 1 : 0,
        'settledCount': settled ? 1 : 0,
        'settledAmount': settled ? 400 : 0,
      },
      'payments': [
        {
          'orderId': 'order_1',
          'paymentId': 'pay_1',
          'purposeLabel': 'Payment request',
          'detail': 'Exam re-evaluation',
          'userName': 'Priya Kumar',
          'amount': 400,
          'state': 'credited',
          'gatewayStatus': 'captured',
          'recovered': true,
          'settled': settled ? true : null,
          'createdAt': '2026-09-29T08:00:00Z',
        },
      ],
      'gatewayConfigured': true,
      'canReconcile': true,
    };

    testWidgets('shows totals, says settlement is not available, and syncs', (
      tester,
    ) async {
      var synced = false;
      final queries = <Map<String, String>>[];
      final repository = _repository((request) async {
        if (request.url.path.endsWith('/online-payments/sync')) {
          synced = true;
          return _json({
            'data': {
              'checked': 2,
              'recovered': 1,
              'settlementsMatched': 1,
              'errors': <String>[],
            },
          });
        }
        queries.add(request.url.queryParameters);
        return _json({'data': report(settled: synced)});
      });
      await _pumpPage(tester, OnlinePaymentsPage(repository: repository));
      expect(find.text('₹400'), findsWidgets);
      expect(find.text('₹75'), findsOneWidget);
      expect(find.text('Not available'), findsOneWidget);
      expect(find.text('Priya Kumar'), findsOneWidget);
      expect(find.text('Recovered'), findsWidgets);
      expect(queries.first.containsKey('from'), isTrue);

      await tester.tap(find.byKey(const ValueKey('online-payments-sync')));
      await tester.pumpAndSettle();
      expect(synced, isTrue);
      expect(find.textContaining('recovered 1'), findsOneWidget);
      expect(find.text('Not available'), findsNothing);

      final failedChip = find.widgetWithText(ChoiceChip, 'Failed');
      await tester.ensureVisible(failedChip);
      await tester.pumpAndSettle();
      await tester.tap(failedChip);
      await tester.pumpAndSettle();
      expect(queries.last['status'], 'failed');

      await tester.tap(find.text('Priya Kumar'));
      await tester.pumpAndSettle();
      expect(find.text('SETTLEMENT'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('refreshes on its own while open', (tester) async {
      var calls = 0;
      final repository = _repository((request) async {
        calls++;
        return _json({'data': report()});
      });
      await _pumpPage(
        tester,
        OnlinePaymentsPage(
          repository: repository,
          refreshInterval: const Duration(seconds: 5),
        ),
      );
      final initial = calls;
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(calls, greaterThan(initial));
      paymentRequestRevision.value++;
      await tester.pumpAndSettle();
      expect(calls, greaterThan(initial + 1));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('admin home entries', () {
    const session = UserSession(
      email: 'admin@mec.local',
      displayName: 'Arun Iyer',
      role: UserRole.admin,
      roleId: 'tenant_admin',
      roleIds: ['tenant_admin'],
    );

    Future<void> pumpHome(WidgetTester tester, Set<String> grants) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: AdminDashboardScreen(
            session: session,
            permissions: EffectivePermissions(grants: grants),
            onOpenModule: (_, [_]) {},
            onSignOut: () {},
            onProfileTap: () {},
            onAlertsTap: () {},
            onOpenPaymentRequests: () {},
            onOpenOnlinePayments: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('are gated on payment grants, not role names', (tester) async {
      await pumpHome(tester, {'*'});
      expect(find.text('Payment requests', skipOffstage: false), findsWidgets);
      expect(find.text('Online payments', skipOffstage: false), findsWidgets);

      await pumpHome(tester, {'administration.users.read'});
      expect(find.text('Payment requests', skipOffstage: false), findsNothing);
      expect(find.text('Online payments', skipOffstage: false), findsNothing);
    });
  });
}
