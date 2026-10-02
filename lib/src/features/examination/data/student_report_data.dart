import 'dart:math' as math;

import '../../academics/data/student_assessments_repository.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../authentication/data/auth_repository.dart';
import '../../canteen/data/backend_canteen_repository.dart';
import '../../canteen/data/canteen_models.dart';
import '../../gatepass/data/backend_gatepass_repository.dart';
import '../../gatepass/data/gatepass_models.dart';
import '../../hostel/data/backend_hostel_repository.dart';
import '../../insights/data/insight.dart';
import '../../library/data/library_lending_repository.dart';
import '../../../screens/tuition_fee/tuition_fee_repository.dart';

/// The institution minimum the whole app measures attendance against.
/// Sourced from [AttendanceSnapshot] so the report and the home insights can
/// never disagree about it.
final double kRequiredAttendanceFraction = const AttendanceSnapshot(
  attended: 0,
  total: 0,
).requiredFraction;

/// Largest k where `attended / (total + k)` still clears [required].
int classesYouCanMiss(int attended, int total, [double? required]) {
  final r = required ?? kRequiredAttendanceFraction;
  if (total <= 0 || attended / total < r) return 0;
  return math.max(0, (attended / r - total + 1e-9).floor());
}

/// Smallest m where `(attended + m) / (total + m)` clears [required].
int classesNeededToRecover(int attended, int total, [double? required]) {
  final r = required ?? kRequiredAttendanceFraction;
  if (total <= 0 || attended / total >= r || r >= 1) return 0;
  return math.max(0, ((r * total - attended) / (1 - r) - 1e-9).ceil());
}

enum AttendanceStanding { safe, close, below, none }

/// Safe once the student has a cushion of at least three classes; close when
/// they are on or just above the line; below under it.
AttendanceStanding attendanceStanding(int attended, int total) {
  if (total <= 0) return AttendanceStanding.none;
  if (attended / total < kRequiredAttendanceFraction) {
    return AttendanceStanding.below;
  }
  return classesYouCanMiss(attended, total) < 3
      ? AttendanceStanding.close
      : AttendanceStanding.safe;
}

// ─────────────────────────────── Attendance ───────────────────────────────

enum AttendanceMark { present, absent, onDuty, leave, other }

AttendanceMark parseAttendanceMark(Object? raw) =>
    switch (raw?.toString().trim().toLowerCase()) {
      'present' || 'p' || 'late' => AttendanceMark.present,
      'absent' || 'a' => AttendanceMark.absent,
      'od' || 'on_duty' || 'onduty' || 'on duty' => AttendanceMark.onDuty,
      'leave' || 'l' || 'medical_leave' => AttendanceMark.leave,
      _ => AttendanceMark.other,
    };

class SubjectAttendance {
  const SubjectAttendance({
    required this.code,
    required this.name,
    required this.total,
    required this.attended,
  });

  final String code;
  final String name;
  final int total;
  final int attended;

  double get fraction => total == 0 ? 1 : attended / total;
  double get percent => fraction * 100;
  bool get isBelow => total > 0 && fraction < kRequiredAttendanceFraction;
  int get needed => classesNeededToRecover(attended, total);
  int get canMiss => classesYouCanMiss(attended, total);
}

class AttendancePeriod {
  const AttendancePeriod({
    required this.heldOn,
    required this.mark,
    this.periodLabel,
    this.subjectName,
    this.subjectCode,
    this.facultyName,
    this.rawStatus = '',
  });

  final String heldOn;
  final AttendanceMark mark;
  final String? periodLabel;
  final String? subjectName;
  final String? subjectCode;
  final String? facultyName;
  final String rawStatus;
}

class AttendanceReport {
  const AttendanceReport({
    required this.total,
    required this.attended,
    this.present = 0,
    this.absent = 0,
    this.onDuty = 0,
    this.leave = 0,
    this.subjects = const [],
    this.records = const [],
  });

  /// Reads the `/attendance/summary/:id` payload.
  factory AttendanceReport.fromSummary(Map<String, dynamic> json) {
    int n(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    String? t(Object? v) {
      final s = v?.toString().trim() ?? '';
      return s.isEmpty ? null : s;
    }

    final subjects = [
      for (final row
          in (json['bySubject'] as List? ?? const []).whereType<Map>())
        SubjectAttendance(
          code: t(row['subjectCode']) ?? '',
          name: t(row['subjectName']) ?? t(row['subjectCode']) ?? 'Subject',
          total: n(row['totalClasses']),
          attended: n(row['attendedClasses']),
        ),
    ];
    final records = [
      for (final row in (json['records'] as List? ?? const []).whereType<Map>())
        AttendancePeriod(
          heldOn: t(row['heldOn']) ?? '',
          mark: parseAttendanceMark(row['status']),
          rawStatus: t(row['status']) ?? '',
          periodLabel: t(row['periodLabel']),
          subjectName: t(row['subjectName']),
          subjectCode: t(row['subjectCode']),
          facultyName: t(row['facultyName']),
        ),
    ];
    return AttendanceReport(
      total: n(json['totalClasses']),
      attended: n(json['attendedClasses']),
      present: n(json['presentClasses']),
      absent: n(json['absences']),
      onDuty: n(json['onDutyClasses']),
      leave: n(json['leaveClasses']),
      subjects: subjects,
      records: records,
    );
  }

  final int total;
  final int attended;
  final int present;
  final int absent;
  final int onDuty;
  final int leave;
  final List<SubjectAttendance> subjects;
  final List<AttendancePeriod> records;

  double get fraction => total == 0 ? 0 : attended / total;
  double get percent => fraction * 100;
  int get canMiss => classesYouCanMiss(attended, total);
  int get needed => classesNeededToRecover(attended, total);
  AttendanceStanding get standing => attendanceStanding(attended, total);

  /// Riskiest first: lowest percentage, then the one needing most classes.
  List<SubjectAttendance> get subjectsByRisk {
    final sorted = [...subjects.where((s) => s.total > 0)]
      ..sort((a, b) {
        final byPercent = a.fraction.compareTo(b.fraction);
        if (byPercent != 0) return byPercent;
        final byNeed = b.needed.compareTo(a.needed);
        return byNeed != 0 ? byNeed : a.name.compareTo(b.name);
      });
    return [...sorted, ...subjects.where((s) => s.total == 0)];
  }

  /// Most recent periods, oldest on the left so the strip reads like time.
  List<AttendancePeriod> recent([int count = 14]) {
    final sorted = [...records]
      ..sort((a, b) {
        final byDate = b.heldOn.compareTo(a.heldOn);
        if (byDate != 0) return byDate;
        return (b.periodLabel ?? '').compareTo(a.periodLabel ?? '');
      });
    return sorted.take(count).toList().reversed.toList(growable: false);
  }
}

// ───────────────────────────────── Marks ──────────────────────────────────

class MarksGroup {
  const MarksGroup(this.kind, this.assessments);

  final StudentAssessmentKind kind;
  final List<StudentAssessment> assessments;

  String get label => switch (kind) {
    StudentAssessmentKind.semester => 'Semester exams',
    StudentAssessmentKind.internal => 'Internal assessments',
    StudentAssessmentKind.test => 'Tests',
  };

  /// Mean of the individual percentages, so a 10-mark quiz and a 100-mark
  /// paper count equally.
  double get averagePercent {
    final scored = assessments.where((a) => a.maximumMarks > 0);
    if (scored.isEmpty) return 0;
    return scored.fold<double>(0, (sum, a) => sum + a.percentage) /
        scored.length;
  }
}

/// Semester → internal → test, newest first inside each group.
List<MarksGroup> groupAssessments(List<StudentAssessment> assessments) => [
  for (final kind in StudentAssessmentKind.values)
    if (assessments.any((a) => a.kind == kind))
      MarksGroup(
        kind,
        assessments.where((a) => a.kind == kind).toList()..sort((a, b) {
          final ad = a.assessedOn ?? a.updatedAt;
          final bd = b.assessedOn ?? b.updatedAt;
          if (ad == null && bd == null) return a.title.compareTo(b.title);
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        }),
      ),
];

// ────────────────────────────────── Fees ──────────────────────────────────

class FeeReport {
  const FeeReport({
    required this.hasRecords,
    required this.assigned,
    required this.paid,
    required this.fine,
    required this.waiver,
    this.lastPaymentOn,
    this.lastPaymentAmount,
  });

  /// outstanding = assigned + fine − waiver − paid, never below zero. Prefers
  /// the account ledger when the backend sends one; otherwise rebuilds it from
  /// the assignment, payment and fine records.
  factory FeeReport.fromRecords(List<StudentFeeRecord> records) {
    double num0(Object? value) => switch (value) {
      final num number => number.toDouble(),
      final String text => double.tryParse(text) ?? 0,
      _ => 0,
    };
    final account = records
        .where((row) => row.type == 'student_fee_accounts')
        .firstOrNull;
    final assignments = records.where((row) => row.type == 'fee_assignment');
    final payments = records
        .where((row) => row.type == 'payments')
        .where(
          (row) => !{
            'failed',
            'reversed',
            'void',
          }.contains(row.data['status']?.toString().toLowerCase()),
        )
        .toList();
    final fines = records.where((row) => row.type == 'fines_penalties');
    final assigned = account == null
        ? assignments.fold<double>(
            0,
            (sum, row) => sum + num0(row.data['amountPerStudent']),
          )
        : num0(account.data['totalAssigned']);
    final paidFromRecords = payments.fold<double>(
      0,
      (sum, row) => sum + num0(row.data['amount']),
    );
    final paid = account == null
        ? paidFromRecords
        : num0(
            account.data['paid'],
          ).clamp(paidFromRecords, double.infinity).toDouble();
    final waiver = num0(account?.data['discountWaiver']);
    final fine = account == null
        ? fines.fold<double>(
            0,
            (sum, row) =>
                sum + num0(row.data['amount']) - num0(row.data['waivedAmount']),
          )
        : num0(account.data['fine']);

    DateTime? lastOn;
    double? lastAmount;
    for (final row in payments) {
      final on = DateTime.tryParse('${row.data['paymentDate'] ?? ''}');
      if (on == null) continue;
      if (lastOn == null || on.isAfter(lastOn)) {
        lastOn = on;
        lastAmount = num0(row.data['amount']);
      }
    }
    return FeeReport(
      hasRecords: records.isNotEmpty,
      assigned: assigned,
      paid: paid,
      fine: fine,
      waiver: waiver,
      lastPaymentOn: lastOn,
      lastPaymentAmount: lastAmount,
    );
  }

  final bool hasRecords;
  final double assigned;
  final double paid;
  final double fine;
  final double waiver;
  final DateTime? lastPaymentOn;
  final double? lastPaymentAmount;

  double get outstanding =>
      (assigned + fine - waiver - paid).clamp(0, double.infinity).toDouble();

  /// Rounding noise under a rupee is not a debt.
  bool get isSettled => outstanding < 1;
}

// ──────────────────────────────── Library ─────────────────────────────────

class LibraryReport {
  const LibraryReport({
    required this.onLoan,
    required this.overdue,
    required this.totalFine,
    required this.pendingRequests,
    this.nextDueAt,
    this.nextDueTitle,
  });

  factory LibraryReport.fromLoans(List<LibraryLoan> loans) {
    // `approved` is the lending API's word for a book in the student's hands.
    final issued = loans.where((l) => l.status == 'approved').toList();
    final dated = issued.where((l) => l.dueAt != null).toList()
      ..sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    return LibraryReport(
      onLoan: issued.length,
      overdue: issued.where((l) => l.overdueDays > 0).length,
      totalFine: loans
          .where((l) => l.status != 'rejected')
          .fold<double>(0, (sum, l) => sum + l.fineAmount),
      pendingRequests: loans.where((l) => l.status == 'requested').length,
      nextDueAt: dated.firstOrNull?.dueAt,
      nextDueTitle: dated.firstOrNull?.bookTitle,
    );
  }

  final int onLoan;
  final int overdue;
  final double totalFine;
  final int pendingRequests;
  final DateTime? nextDueAt;
  final String? nextDueTitle;
}

// ──────────────────────────────── Canteen ─────────────────────────────────

class ShopBalance {
  const ShopBalance({
    required this.shopKey,
    required this.name,
    required this.balance,
  });

  final String shopKey;
  final String name;
  final double balance;
}

class CanteenReport {
  const CanteenReport({
    required this.balances,
    required this.monthSpend,
    required this.monthOrders,
  });

  /// One balance per shop. Wallets are not interchangeable between counters,
  /// so adding them up would describe money the student cannot actually spend
  /// anywhere.
  factory CanteenReport.fromStore(CanteenStore store, DateTime now) {
    bool thisMonth(DateTime d) {
      final local = d.toLocal();
      return local.year == now.year && local.month == now.month;
    }

    String nameFor(String key) {
      final shop = store.shops.where((s) => s.shopKey == key).firstOrNull;
      if (shop != null && shop.isCounter) {
        // A category's own balance is credit only it accepts.
        final parent = store.shops
            .where((s) => s.shopKey == shop.parentShopKey)
            .firstOrNull;
        if (parent != null) return '${parent.name} · ${shop.name} only';
      }
      if (shop != null && shop.name.trim().isNotEmpty) return shop.name;
      if (MenuStore.values.any((s) => s.apiValue == key)) {
        return MenuStoreLabel.parse(key).label;
      }
      return key.isEmpty ? 'Canteen' : key[0].toUpperCase() + key.substring(1);
    }

    final balances = [
      for (final entry in store.walletBalances.entries)
        ShopBalance(
          shopKey: entry.key,
          name: nameFor(entry.key),
          balance: entry.value,
        ),
    ]..sort((a, b) => a.name.compareTo(b.name));
    return CanteenReport(
      balances: balances,
      monthSpend: store.walletTransactions
          .where(
            (t) =>
                t.type == WalletTransactionType.debit && thisMonth(t.createdAt),
          )
          .fold<double>(0, (sum, t) => sum + t.amount.abs()),
      monthOrders: store.orders
          .where(
            (o) =>
                thisMonth(o.createdAt) &&
                o.status != CanteenOrderStatus.rejected &&
                o.status != CanteenOrderStatus.cancelled,
          )
          .length,
    );
  }

  final List<ShopBalance> balances;
  final double monthSpend;
  final int monthOrders;
}

// ──────────────────────────────── Gatepass ────────────────────────────────

class GatepassReport {
  const GatepassReport({
    required this.recentPasses,
    required this.approved,
    required this.pending,
    required this.rejected,
    this.activePass,
    this.lastMovement,
  });

  /// "Recent" is the last six months — about one term. The API has no term
  /// boundaries to count against.
  factory GatepassReport.fromStore(GatepassStore store, DateTime now) {
    final since = now.subtract(const Duration(days: 183));
    final recent = store.requests
        .where((r) => r.submittedAt.isAfter(since))
        .toList();
    final active =
        store.requests
            .where(
              (r) =>
                  r.status == ApprovalStatus.approved &&
                  (r.qrPayload?.trim().isNotEmpty ?? false) &&
                  r.returnAt.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.returnAt.compareTo(b.returnAt));
    final movements = [...store.movements]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return GatepassReport(
      recentPasses: recent.length,
      approved: recent
          .where(
            (r) =>
                r.status == ApprovalStatus.approved ||
                r.status == ApprovalStatus.completed,
          )
          .length,
      pending: recent.where((r) => r.status == ApprovalStatus.pending).length,
      rejected: recent.where((r) => r.status == ApprovalStatus.rejected).length,
      activePass: active.firstOrNull,
      lastMovement: movements.firstOrNull,
    );
  }

  final int recentPasses;
  final int approved;
  final int pending;
  final int rejected;
  final GatepassRequest? activePass;
  final GateMovement? lastMovement;
}

// ───────────────────────────────── Hostel ─────────────────────────────────

/// Only the room assignment. The hostel overview's due amount, check-in time
/// and presence fields are not backed by real data and are deliberately left
/// out.
class HostelReport {
  const HostelReport({
    required this.hostelName,
    required this.blockName,
    required this.roomNumber,
  });

  final String hostelName;
  final String blockName;
  final String roomNumber;
}

// ──────────────────────────────── Sources ─────────────────────────────────

typedef ReportLoader<T> = Future<T> Function();

/// Where each report section gets its data. A null loader means this build
/// has no way to read that data (a mock build, or no backend configured), and
/// the section says so instead of inventing figures.
class StudentReportSources {
  const StudentReportSources({
    this.attendance,
    this.marks,
    this.fees,
    this.library,
    this.canteen,
    this.gatepass,
    this.hostel,
  });

  const StudentReportSources.unavailable()
    : attendance = null,
      marks = null,
      fees = null,
      library = null,
      canteen = null,
      gatepass = null,
      hostel = null;

  /// Live repositories, authorised by the app's own token provider.
  factory StudentReportSources.backend({
    required String baseUrl,
    required AccessTokenProvider accessTokenProvider,
    required UserSession session,
    String attendanceSubject = 'me',
    DateTime Function() clock = DateTime.now,
  }) {
    return StudentReportSources(
      attendance: () async => AttendanceReport.fromSummary(
        await AttendanceRepository(
          baseUrl: baseUrl,
          accessTokenProvider: accessTokenProvider,
        ).summary(attendanceSubject),
      ),
      marks: () => BackendStudentAssessmentsRepository(
        baseUrl: baseUrl,
        accessTokenProvider: accessTokenProvider,
      ).loadAssessments(),
      fees: () async => FeeReport.fromRecords(
        await TuitionFeeRepository(
          baseUrl: baseUrl,
          accessTokenProvider: accessTokenProvider,
        ).load(),
      ),
      library: () async => LibraryReport.fromLoans(
        await LibraryLendingRepository(
          baseUrl: baseUrl,
          accessTokenProvider: accessTokenProvider,
        ).loans(),
      ),
      canteen: () async => CanteenReport.fromStore(
        await BackendCanteenRepository(
          baseUrl: baseUrl,
          accessTokenProvider: accessTokenProvider,
        ).loadStore(),
        clock(),
      ),
      gatepass: () async => GatepassReport.fromStore(
        await BackendGatepassRepository(
          baseUrl: baseUrl,
          accessTokenProvider: accessTokenProvider,
          studentName: session.displayName,
          email: session.email,
          rollNumber: session.idNumber ?? '',
          department: session.departmentOrWard ?? '',
          // A report never activates today's pass, so it never asks for GPS.
          positionProvider: () async =>
              throw Exception('Reports do not use location'),
        ).loadStore(),
        clock(),
      ),
      hostel: () async {
        final residency = (await BackendHostelRepository(
          baseUrl: baseUrl,
          accessTokenProvider: accessTokenProvider,
          studentName: session.displayName,
          studentCode: session.idNumber ?? '',
        ).loadStore()).activeResidency;
        if (residency == null) return null;
        return HostelReport(
          hostelName: residency.hostelName,
          blockName: residency.blockName,
          roomNumber: residency.roomNumber,
        );
      },
    );
  }

  final ReportLoader<AttendanceReport>? attendance;
  final ReportLoader<List<StudentAssessment>>? marks;
  final ReportLoader<FeeReport>? fees;
  final ReportLoader<LibraryReport>? library;
  final ReportLoader<CanteenReport>? canteen;
  final ReportLoader<GatepassReport>? gatepass;
  final ReportLoader<HostelReport?>? hostel;
}
