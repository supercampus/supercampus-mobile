/// Ad-hoc payment requests (fines, electricity bills, ...) and the Razorpay
/// online payment ledger, as the operations API returns them.
library;

enum PaymentRequestStatus { pending, overdue, paid, cancelled }

PaymentRequestStatus parsePaymentRequestStatus(Object? value) =>
    switch (value?.toString()) {
      'overdue' => PaymentRequestStatus.overdue,
      'paid' => PaymentRequestStatus.paid,
      'cancelled' => PaymentRequestStatus.cancelled,
      _ => PaymentRequestStatus.pending,
    };

extension PaymentRequestStatusLabel on PaymentRequestStatus {
  String get label => switch (this) {
    PaymentRequestStatus.pending => 'Pending',
    PaymentRequestStatus.overdue => 'Overdue',
    PaymentRequestStatus.paid => 'Paid',
    PaymentRequestStatus.cancelled => 'Withdrawn',
  };

  bool get isOpen =>
      this == PaymentRequestStatus.pending ||
      this == PaymentRequestStatus.overdue;
}

double _double(Object? value) => switch (value) {
  final num number => number.toDouble(),
  final String text => double.tryParse(text) ?? 0,
  _ => 0,
};

int _int(Object? value) => switch (value) {
  final num number => number.round(),
  final String text => int.tryParse(text) ?? 0,
  _ => 0,
};

DateTime? _date(Object? value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}

String? _text(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

List<String> _strings(Object? value) => value is List
    ? value.map((item) => item.toString()).where((s) => s.isNotEmpty).toList()
    : const [];

/// A request as the student it is addressed to sees it.
class StudentPaymentRequest {
  const StudentPaymentRequest({
    required this.payerId,
    required this.requestId,
    required this.purpose,
    required this.purposeLabel,
    required this.title,
    required this.description,
    required this.amount,
    required this.status,
    this.currency = 'INR',
    this.dueDate,
    this.showOnDashboard = true,
    this.paidAt,
    this.paymentMethod,
  });

  factory StudentPaymentRequest.fromJson(Map<String, dynamic> json) =>
      StudentPaymentRequest(
        payerId: json['payerId']?.toString() ?? '',
        requestId: json['requestId']?.toString() ?? '',
        purpose: json['purpose']?.toString() ?? 'other',
        purposeLabel: json['purposeLabel']?.toString() ?? 'Other',
        title: json['title']?.toString() ?? 'Payment request',
        description: json['description']?.toString() ?? '',
        amount: _double(json['amount']),
        currency: json['currency']?.toString() ?? 'INR',
        dueDate: _date(json['dueDate']),
        showOnDashboard: json['showOnDashboard'] != false,
        status: parsePaymentRequestStatus(json['status']),
        paidAt: _date(json['paidAt']),
        paymentMethod: _text(json['paymentMethod']),
      );

  final String payerId;
  final String requestId;
  final String purpose;
  final String purposeLabel;
  final String title;
  final String description;
  final double amount;
  final String currency;
  final DateTime? dueDate;
  final bool showOnDashboard;
  final PaymentRequestStatus status;
  final DateTime? paidAt;
  final String? paymentMethod;

  /// Whether the home screen shows this request: open ones always, a paid
  /// one for three days so the student sees the payment land.
  bool showsOnHome(DateTime now) {
    if (!showOnDashboard) return false;
    if (status.isOpen) return true;
    final paid = paidAt;
    return status == PaymentRequestStatus.paid &&
        paid != null &&
        now.difference(paid).inDays < 3;
  }
}

/// The student's requests plus whether online payment is possible.
class StudentPaymentRequests {
  const StudentPaymentRequests({
    this.requests = const [],
    this.onlinePaymentsEnabled = false,
  });

  final List<StudentPaymentRequest> requests;
  final bool onlinePaymentsEnabled;

  static const empty = StudentPaymentRequests();
}

class PaymentRequestPayer {
  const PaymentRequestPayer({
    required this.id,
    required this.userId,
    required this.name,
    required this.amount,
    required this.status,
    this.studentNumber,
    this.department,
    this.year,
    this.paidAt,
    this.paymentMethod,
    this.paymentReference,
    this.note,
  });

  factory PaymentRequestPayer.fromJson(Map<String, dynamic> json) =>
      PaymentRequestPayer(
        id: json['id']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        name: _text(json['name']) ?? 'Student',
        amount: _double(json['amount']),
        status: parsePaymentRequestStatus(json['status']),
        studentNumber: _text(json['studentNumber']),
        department: _text(json['department']),
        year: _text(json['year']),
        paidAt: _date(json['paidAt']),
        paymentMethod: _text(json['paymentMethod']),
        paymentReference: _text(json['paymentReference']),
        note: _text(json['note']),
      );

  final String id;
  final String userId;
  final String name;
  final double amount;
  final PaymentRequestStatus status;
  final String? studentNumber;
  final String? department;
  final String? year;
  final DateTime? paidAt;
  final String? paymentMethod;
  final String? paymentReference;
  final String? note;
}

/// A request as the accounts office sees it.
class PaymentRequestSummary {
  const PaymentRequestSummary({
    required this.id,
    required this.purpose,
    required this.purposeLabel,
    required this.title,
    required this.description,
    required this.amount,
    required this.status,
    this.dueDate,
    this.showOnDashboard = true,
    this.targetMode = 'all',
    this.targetDepartments = const [],
    this.targetYears = const [],
    this.overdue = false,
    this.createdByName,
    this.createdAt,
    this.cancelReason,
    this.payerCount = 0,
    this.paidCount = 0,
    this.pendingCount = 0,
    this.collectedAmount = 0,
    this.expectedAmount = 0,
    this.payers = const [],
    this.canManage = false,
  });

  factory PaymentRequestSummary.fromJson(Map<String, dynamic> json) =>
      PaymentRequestSummary(
        id: json['id']?.toString() ?? '',
        purpose: json['purpose']?.toString() ?? 'other',
        purposeLabel: json['purposeLabel']?.toString() ?? 'Other',
        title: json['title']?.toString() ?? 'Payment request',
        description: json['description']?.toString() ?? '',
        amount: _double(json['amount']),
        status: json['status']?.toString() ?? 'active',
        dueDate: _date(json['dueDate']),
        showOnDashboard: json['showOnDashboard'] != false,
        targetMode: json['targetMode']?.toString() ?? 'all',
        targetDepartments: _strings(json['targetDepartments']),
        targetYears: _strings(json['targetYears']),
        overdue: json['overdue'] == true,
        createdByName: _text(json['createdByName']),
        createdAt: _date(json['createdAt']),
        cancelReason: _text(json['cancelReason']),
        payerCount: _int(json['payerCount']),
        paidCount: _int(json['paidCount']),
        pendingCount: _int(json['pendingCount']),
        collectedAmount: _double(json['collectedAmount']),
        expectedAmount: _double(json['expectedAmount']),
        payers: (json['payers'] as List? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(PaymentRequestPayer.fromJson)
            .toList(),
        canManage: json['canManage'] == true,
      );

  final String id;
  final String purpose;
  final String purposeLabel;
  final String title;
  final String description;
  final double amount;

  /// active | closed | cancelled
  final String status;
  final DateTime? dueDate;
  final bool showOnDashboard;
  final String targetMode;
  final List<String> targetDepartments;
  final List<String> targetYears;
  final bool overdue;
  final String? createdByName;
  final DateTime? createdAt;
  final String? cancelReason;
  final int payerCount;
  final int paidCount;
  final int pendingCount;
  final double collectedAmount;
  final double expectedAmount;
  final List<PaymentRequestPayer> payers;
  final bool canManage;

  bool get isActive => status == 'active';

  double get collectedFraction =>
      expectedAmount <= 0 ? 0 : (collectedAmount / expectedAmount).clamp(0, 1);

  String get statusLabel => switch (status) {
    'closed' => 'Closed',
    'cancelled' => 'Cancelled',
    _ => overdue ? 'Overdue' : 'Active',
  };

  String get audienceLabel => switch (targetMode) {
    'students' => '$payerCount selected ${payerCount == 1 ? 'student' : 'students'}',
    'cohort' => [
      if (targetDepartments.isNotEmpty) targetDepartments.join(', '),
      if (targetYears.isNotEmpty) 'Year ${targetYears.join(', ')}',
    ].join(' · '),
    _ => 'All students',
  };
}

class PaymentOption {
  const PaymentOption(this.key, this.label);

  final String key;
  final String label;
}

class PaymentRequestOptions {
  const PaymentRequestOptions({
    this.purposes = defaultPurposes,
    this.manualMethods = defaultManualMethods,
    this.departments = const [],
    this.years = const [],
    this.studentCount = 0,
    this.onlinePaymentsEnabled = false,
  });

  static const defaultPurposes = [
    PaymentOption('fine', 'Fine'),
    PaymentOption('electricity', 'Electricity bill'),
    PaymentOption('hostel', 'Hostel'),
    PaymentOption('exam', 'Examination'),
    PaymentOption('library', 'Library'),
    PaymentOption('transport', 'Transport'),
    PaymentOption('event', 'Event'),
    PaymentOption('other', 'Other'),
  ];

  static const defaultManualMethods = [
    PaymentOption('cash', 'Cash'),
    PaymentOption('bank_transfer', 'Bank transfer'),
    PaymentOption('upi', 'UPI (outside the app)'),
    PaymentOption('cheque', 'Cheque'),
    PaymentOption('other', 'Other'),
  ];

  factory PaymentRequestOptions.fromJson(Map<String, dynamic> json) {
    List<PaymentOption> options(Object? value, List<PaymentOption> fallback) {
      final parsed = (value as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(
            (item) => PaymentOption(
              item['key']?.toString() ?? '',
              item['label']?.toString() ?? '',
            ),
          )
          .where((option) => option.key.isNotEmpty)
          .toList();
      return parsed.isEmpty ? fallback : parsed;
    }

    return PaymentRequestOptions(
      purposes: options(json['purposes'], defaultPurposes),
      manualMethods: options(json['manualMethods'], defaultManualMethods),
      departments: _strings(json['departments']),
      years: _strings(json['years']),
      studentCount: _int(json['studentCount']),
      onlinePaymentsEnabled: json['onlinePaymentsEnabled'] == true,
    );
  }

  final List<PaymentOption> purposes;
  final List<PaymentOption> manualMethods;
  final List<String> departments;
  final List<String> years;
  final int studentCount;
  final bool onlinePaymentsEnabled;
}

class PaymentStudent {
  const PaymentStudent({
    required this.userId,
    required this.name,
    this.studentNumber,
    this.email,
    this.department,
    this.year,
  });

  factory PaymentStudent.fromJson(Map<String, dynamic> json) => PaymentStudent(
    userId: json['userId']?.toString() ?? '',
    name: _text(json['name']) ?? 'Student',
    studentNumber: _text(json['studentNumber']),
    email: _text(json['email']),
    department: _text(json['department']),
    year: _text(json['year']),
  );

  final String userId;
  final String name;
  final String? studentNumber;
  final String? email;
  final String? department;
  final String? year;

  String get detail => [
    if (studentNumber != null) studentNumber!,
    if (department != null) department!,
    if (year != null) 'Year $year',
  ].join(' · ');
}

/// What the create form sends.
class NewPaymentRequest {
  const NewPaymentRequest({
    required this.purpose,
    required this.title,
    required this.description,
    required this.amount,
    required this.target,
    this.dueDate,
    this.showOnDashboard = true,
    this.studentUserIds = const [],
    this.departments = const [],
    this.years = const [],
  });

  final String purpose;
  final String title;
  final String description;
  final double amount;

  /// all | students | cohort
  final String target;
  final DateTime? dueDate;
  final bool showOnDashboard;
  final List<String> studentUserIds;
  final List<String> departments;
  final List<String> years;

  Map<String, dynamic> toJson() => {
    'purpose': purpose,
    'title': title.trim(),
    'description': description.trim(),
    'amount': amount,
    'target': target,
    'showOnDashboard': showOnDashboard,
    if (dueDate != null) 'dueDate': formatApiDate(dueDate!),
    if (target == 'students') 'studentUserIds': studentUserIds,
    if (target == 'cohort') 'departments': departments,
    if (target == 'cohort') 'years': years,
  };
}

String formatApiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// Tracking state of one online payment.
enum OnlinePaymentState { pending, credited, capturedNotCredited, failed, refunded }

OnlinePaymentState parseOnlinePaymentState(Object? value) =>
    switch (value?.toString()) {
      'credited' => OnlinePaymentState.credited,
      'captured_not_credited' => OnlinePaymentState.capturedNotCredited,
      'failed' => OnlinePaymentState.failed,
      'refunded' => OnlinePaymentState.refunded,
      _ => OnlinePaymentState.pending,
    };

extension OnlinePaymentStateLabel on OnlinePaymentState {
  String get label => switch (this) {
    OnlinePaymentState.pending => 'Pending',
    OnlinePaymentState.credited => 'Credited',
    OnlinePaymentState.capturedNotCredited => 'Captured, not credited',
    OnlinePaymentState.failed => 'Failed',
    OnlinePaymentState.refunded => 'Refunded',
  };

  /// The API's filter value.
  String get apiValue => switch (this) {
    OnlinePaymentState.capturedNotCredited => 'captured_not_credited',
    _ => name,
  };
}

class OnlinePayment {
  const OnlinePayment({
    required this.state,
    required this.amount,
    required this.purposeLabel,
    required this.createdAt,
    this.orderId,
    this.paymentId,
    this.source = 'checkout',
    this.detail,
    this.userName,
    this.userEmail,
    this.userNumber,
    this.gatewayStatus,
    this.paymentMethod,
    this.errorDescription,
    this.capturedAt,
    this.fulfilledAt,
    this.recovered = false,
    this.feePaise,
    this.taxPaise,
    this.settlementId,
    this.settled,
    this.settledAt,
    this.lastSyncedAt,
  });

  factory OnlinePayment.fromJson(Map<String, dynamic> json) => OnlinePayment(
    state: parseOnlinePaymentState(json['state']),
    amount: _double(json['amount']),
    purposeLabel: json['purposeLabel']?.toString() ?? 'Payment',
    createdAt: _date(json['createdAt']) ?? DateTime.now(),
    orderId: _text(json['orderId']),
    paymentId: _text(json['paymentId']),
    source: json['source']?.toString() ?? 'checkout',
    detail: _text(json['detail']),
    userName: _text(json['userName']),
    userEmail: _text(json['userEmail']),
    userNumber: _text(json['userNumber']),
    gatewayStatus: _text(json['gatewayStatus']),
    paymentMethod: _text(json['paymentMethod']),
    errorDescription: _text(json['errorDescription']),
    capturedAt: _date(json['capturedAt']),
    fulfilledAt: _date(json['fulfilledAt']),
    recovered: json['recovered'] == true,
    feePaise: json['feePaise'] is num ? _int(json['feePaise']) : null,
    taxPaise: json['taxPaise'] is num ? _int(json['taxPaise']) : null,
    settlementId: _text(json['settlementId']),
    settled: json['settled'] is bool ? json['settled'] as bool : null,
    settledAt: _date(json['settledAt']),
    lastSyncedAt: _date(json['lastSyncedAt']),
  );

  final OnlinePaymentState state;
  final double amount;
  final String purposeLabel;
  final DateTime createdAt;
  final String? orderId;
  final String? paymentId;

  /// checkout | wallet_ledger | fee_records | payment_link
  final String source;
  final String? detail;
  final String? userName;
  final String? userEmail;
  final String? userNumber;
  final String? gatewayStatus;
  final String? paymentMethod;
  final String? errorDescription;
  final DateTime? capturedAt;
  final DateTime? fulfilledAt;
  final bool recovered;
  final int? feePaise;
  final int? taxPaise;
  final String? settlementId;

  /// Null when no reconciliation has read this payment's settlement.
  final bool? settled;
  final DateTime? settledAt;
  final DateTime? lastSyncedAt;

  String get payerLabel => userName ?? userEmail ?? userNumber ?? 'Campus user';

  String get settlementLabel => switch (settled) {
    true => 'Settled',
    false => 'Not settled yet',
    null => 'Not available',
  };
}

class OnlinePaymentsSummary {
  const OnlinePaymentsSummary({
    this.totalRecords = 0,
    this.creditedCount = 0,
    this.creditedAmount = 0,
    this.capturedNotCreditedCount = 0,
    this.capturedNotCreditedAmount = 0,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.refundedCount = 0,
    this.recoveredCount = 0,
    this.settlementKnownCount = 0,
    this.settledCount = 0,
    this.settledAmount = 0,
  });

  factory OnlinePaymentsSummary.fromJson(Map<String, dynamic> json) =>
      OnlinePaymentsSummary(
        totalRecords: _int(json['totalRecords']),
        creditedCount: _int(json['creditedCount']),
        creditedAmount: _double(json['creditedAmount']),
        capturedNotCreditedCount: _int(json['capturedNotCreditedCount']),
        capturedNotCreditedAmount: _double(json['capturedNotCreditedAmount']),
        pendingCount: _int(json['pendingCount']),
        failedCount: _int(json['failedCount']),
        refundedCount: _int(json['refundedCount']),
        recoveredCount: _int(json['recoveredCount']),
        settlementKnownCount: _int(json['settlementKnownCount']),
        settledCount: _int(json['settledCount']),
        settledAmount: _double(json['settledAmount']),
      );

  final int totalRecords;
  final int creditedCount;
  final double creditedAmount;
  final int capturedNotCreditedCount;
  final double capturedNotCreditedAmount;
  final int pendingCount;
  final int failedCount;
  final int refundedCount;
  final int recoveredCount;
  final int settlementKnownCount;
  final int settledCount;
  final double settledAmount;
}

class OnlinePaymentsReport {
  const OnlinePaymentsReport({
    required this.from,
    required this.to,
    this.summary = const OnlinePaymentsSummary(),
    this.payments = const [],
    this.gatewayConfigured = false,
    this.canReconcile = false,
    this.lastSyncedAt,
    this.truncated = false,
  });

  factory OnlinePaymentsReport.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return OnlinePaymentsReport(
      from: _date(json['from']) ?? now.subtract(const Duration(days: 29)),
      to: _date(json['to']) ?? now,
      summary: OnlinePaymentsSummary.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
      payments: (json['payments'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(OnlinePayment.fromJson)
          .toList(),
      gatewayConfigured: json['gatewayConfigured'] == true,
      canReconcile: json['canReconcile'] == true,
      lastSyncedAt: _date(json['lastSyncedAt']),
      truncated: json['truncated'] == true,
    );
  }

  final DateTime from;
  final DateTime to;
  final OnlinePaymentsSummary summary;
  final List<OnlinePayment> payments;
  final bool gatewayConfigured;
  final bool canReconcile;
  final DateTime? lastSyncedAt;
  final bool truncated;
}

class OnlinePaymentsSyncResult {
  const OnlinePaymentsSyncResult({
    this.checked = 0,
    this.captured = 0,
    this.recovered = 0,
    this.failed = 0,
    this.settlementsMatched = 0,
    this.settlementError,
    this.errors = const [],
  });

  factory OnlinePaymentsSyncResult.fromJson(Map<String, dynamic> json) =>
      OnlinePaymentsSyncResult(
        checked: _int(json['checked']),
        captured: _int(json['captured']),
        recovered: _int(json['recovered']),
        failed: _int(json['failed']),
        settlementsMatched: _int(json['settlementsMatched']),
        settlementError: _text(json['settlementError']),
        errors: _strings(json['errors']),
      );

  final int checked;
  final int captured;
  final int recovered;
  final int failed;
  final int settlementsMatched;
  final String? settlementError;
  final List<String> errors;

  String get summary {
    final parts = <String>[
      'Checked $checked ${checked == 1 ? 'order' : 'orders'}',
      if (recovered > 0) 'recovered $recovered',
      if (failed > 0) '$failed failed',
      '$settlementsMatched ${settlementsMatched == 1 ? 'settlement' : 'settlements'} matched',
    ];
    return parts.join(' · ');
  }
}
