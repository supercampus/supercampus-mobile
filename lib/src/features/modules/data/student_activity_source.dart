import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';
import '../../authentication/data/auth_repository.dart';
import '../../canteen/data/backend_canteen_repository.dart';
import '../../canteen/data/canteen_models.dart';
import '../../gatepass/data/backend_gatepass_repository.dart';
import '../../gatepass/data/gatepass_models.dart';
import '../../gatepass/data/gatepass_repository.dart';
import '../../library/data/backend_library_repository.dart';
import '../../library/data/library_models.dart';
import '../../timetable/data/backend_timetable_repository.dart';
import '../../timetable/data/timetable_models.dart';
import '../../../screens/tuition_fee/tuition_fee_repository.dart';
import 'glance_source.dart';
import '../presentation/today_glance.dart';

/// Builds the learner home feed from the same live repositories as each module.
/// A failed optional service contributes no card instead of taking down Home.
class BackendStudentActivitySource implements StudentActivitySource {
  const BackendStudentActivitySource({
    required this.baseUrl,
    required this.accessTokenProvider,
    required this.session,
    required this.permissions,
  });

  final String baseUrl;
  final AccessTokenProvider accessTokenProvider;
  final UserSession session;
  final EffectivePermissions permissions;

  @override
  Future<List<StudentActivity>> load() async {
    final loaders = <Future<List<StudentActivity>>>[
      if (permissions.canSeeModule(ModuleCatalog.timetable)) _timetable(),
      if (permissions.canSeeModule(ModuleCatalog.canteen)) _canteen(),
      if (permissions.canSeeModule(ModuleCatalog.gatepass)) _gatepass(),
      if (permissions.canSeeModule(ModuleCatalog.library)) _library(),
      if (permissions.canSeeModule(ModuleCatalog.tuitionFee)) _fees(),
    ];
    final groups = await Future.wait(loaders);
    final activities = groups.expand((group) => group).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return activities;
  }

  Future<List<StudentActivity>> _canteen() async {
    try {
      final store = await BackendCanteenRepository(
        baseUrl: baseUrl,
        accessTokenProvider: accessTokenProvider,
      ).loadStore();
      final active =
          store.orders.where((order) => order.status.isActive).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (active.isEmpty) return const [];
      final order = active.first;
      final title = switch (order.status) {
        CanteenOrderStatus.pending => 'Order waiting for confirmation',
        CanteenOrderStatus.accepted => 'Order accepted',
        CanteenOrderStatus.preparing => 'Order is being prepared',
        CanteenOrderStatus.ready => 'Order ready for pickup',
        _ => 'Order ${order.status.label.toLowerCase()}',
      };
      final progress = switch (order.status) {
        CanteenOrderStatus.pending => .12,
        CanteenOrderStatus.accepted => .32,
        CanteenOrderStatus.preparing => .58,
        CanteenOrderStatus.ready => .92,
        _ => 1.0,
      };
      return [
        StudentActivity(
          id: 'canteen-${order.id}',
          kind: StudentActivityKind.canteen,
          title: title,
          supporting:
              '${order.itemCount} item${order.itemCount == 1 ? '' : 's'} · ₹${order.total.toStringAsFixed(order.total.truncateToDouble() == order.total ? 0 : 2)} · Order ${order.displayId}',
          moduleId: ModuleCatalog.canteen,
          priority: 10,
          statusLabel: order.status.label,
          progress: progress,
        ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<List<StudentActivity>> _gatepass() async {
    try {
      final store = await BackendGatepassRepository(
        baseUrl: baseUrl,
        accessTokenProvider: accessTokenProvider,
        studentName: session.displayName,
        email: session.email,
        rollNumber: session.idNumber ?? '',
        department: session.departmentOrWard ?? '',
        // Home only needs the overview. Avoid requesting GPS or minting a
        // daily access pass while quietly refreshing the activity feed.
        positionProvider: () async => throw const GatepassException(
          'Background status refresh does not activate a daily pass.',
        ),
      ).loadStore();
      final requests =
          store.requests
              .where(
                (request) =>
                    request.status == ApprovalStatus.pending ||
                    request.status == ApprovalStatus.approved,
              )
              .toList()
            ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
      if (requests.isEmpty) return const [];
      final request = requests.first;
      final isPending = request.status == ApprovalStatus.pending;
      return [
        StudentActivity(
          id: 'gatepass-${request.id}',
          kind: StudentActivityKind.gatepass,
          title: isPending ? 'Gatepass awaiting approval' : 'Gatepass approved',
          supporting:
              '${request.destination} · ${_dateTime(request.departureAt)}',
          moduleId: ModuleCatalog.gatepass,
          priority: 20,
          statusLabel: request.status.label,
          progress: isPending ? .38 : 1,
        ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<List<StudentActivity>> _library() async {
    try {
      final bookings = await BackendLibraryRepository(
        baseUrl: baseUrl,
        accessTokenProvider: accessTokenProvider,
      ).loadBookings();
      final relevant =
          bookings
              .where(
                (booking) => const {
                  LibraryPassStatus.pending,
                  LibraryPassStatus.approved,
                  LibraryPassStatus.upcoming,
                  LibraryPassStatus.active,
                  LibraryPassStatus.inside,
                }.contains(booking.status),
              )
              .toList()
            ..sort((a, b) => a.start.compareTo(b.start));
      if (relevant.isEmpty) return const [];
      final booking = relevant.first;
      final now = DateTime.now();
      final elapsed = now.difference(booking.start).inSeconds;
      final duration = booking.end.difference(booking.start).inSeconds;
      final progress = duration <= 0
          ? 0.0
          : (elapsed / duration).clamp(0.0, 1.0);
      final active =
          booking.status == LibraryPassStatus.active ||
          booking.status == LibraryPassStatus.inside;
      return [
        StudentActivity(
          id: 'library-${booking.id}',
          kind: StudentActivityKind.library,
          title: active ? 'Library slot in progress' : 'Upcoming library slot',
          supporting:
              '${_time(booking.start)}–${_time(booking.end)} · ${booking.durationMinutes} minutes · ${booking.zoneName}',
          moduleId: ModuleCatalog.library,
          priority: active ? 5 : 30,
          statusLabel: booking.status.label,
          progress: progress,
        ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<List<StudentActivity>> _fees() async {
    try {
      final records = await TuitionFeeRepository(
        baseUrl: baseUrl,
        accessTokenProvider: accessTokenProvider,
      ).load();
      final account = records
          .where((row) => row.type == 'student_fee_accounts')
          .firstOrNull;
      final assignments = records.where((row) => row.type == 'fee_assignment');
      final payments = records.where((row) => row.type == 'payments');
      final fines = records.where((row) => row.type == 'fines_penalties');
      final assigned = account == null
          ? assignments.fold<double>(
              0,
              (sum, row) => sum + _number(row.data['amountPerStudent']),
            )
          : _number(account.data['totalAssigned']);
      final paidFromRecords = payments
          .where(
            (row) => !{
              'failed',
              'reversed',
              'void',
            }.contains(row.data['status']?.toString().toLowerCase()),
          )
          .fold<double>(0, (sum, row) => sum + _number(row.data['amount']));
      final paid = account == null
          ? paidFromRecords
          : _number(
              account.data['paid'],
            ).clamp(paidFromRecords, double.infinity);
      final waiver = _number(account?.data['discountWaiver']);
      final fine = account == null
          ? fines.fold<double>(
              0,
              (sum, row) =>
                  sum +
                  _number(row.data['amount']) -
                  _number(row.data['waivedAmount']),
            )
          : _number(account.data['fine']);
      final outstanding = (assigned + fine - waiver - paid).clamp(
        0,
        double.infinity,
      );
      if (outstanding < 1) return const [];
      final total = (assigned + fine - waiver).clamp(0, double.infinity);
      return [
        StudentActivity(
          id: 'fees-outstanding',
          kind: StudentActivityKind.fees,
          title: 'Tuition fee pending',
          supporting:
              '₹${outstanding.toStringAsFixed(0)} outstanding · Tap to review and pay',
          moduleId: ModuleCatalog.tuitionFee,
          priority: 40,
          statusLabel: 'Payment due',
          progress: total <= 0 ? 0 : (paid / total).clamp(0.0, 1.0),
        ),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<List<StudentActivity>> _timetable() async {
    try {
      final repository = await BackendTimetableRepository.load(
        baseUrl: baseUrl,
        accessTokenProvider: accessTokenProvider,
      );
      final entries = repository.getEntriesForClass(
        session.sectionId ?? session.idNumber ?? '',
      );
      final now = DateTime.now();
      final weekday = weekdayLabelFor(now.weekday);
      final today =
          entries.where((entry) => entry.dayOfWeek == weekday).toList()
            ..sort((a, b) => a.periodIndex.compareTo(b.periodIndex));
      ({TimetableEntry entry, DateTime start, DateTime end})? current;
      ({TimetableEntry entry, DateTime start, DateTime end})? next;
      for (final entry in today) {
        final range = _range(entry.timeSlot, now);
        if (range == null) continue;
        final value = (entry: entry, start: range.$1, end: range.$2);
        if (!now.isBefore(range.$1) && now.isBefore(range.$2)) {
          current = value;
          break;
        }
        if (now.isBefore(range.$1) && next == null) next = value;
      }
      final selected = current ?? next;
      if (selected == null) return const [];
      final isCurrent = current != null;
      final duration = selected.end.difference(selected.start).inSeconds;
      final elapsed = now.difference(selected.start).inSeconds;
      return [
        StudentActivity(
          id: 'class-${selected.entry.id}',
          kind: StudentActivityKind.timetable,
          title: isCurrent
              ? '${selected.entry.subjectName} is in progress'
              : 'Next: ${selected.entry.subjectName}',
          supporting:
              '${selected.entry.timeSlot} · ${selected.entry.facultyName}',
          moduleId: ModuleCatalog.timetable,
          priority: isCurrent ? 0 : 8,
          statusLabel: isCurrent ? 'Now' : 'Next class',
          progress: isCurrent && duration > 0
              ? (elapsed / duration).clamp(0.0, 1.0)
              : 0,
        ),
      ];
    } catch (_) {
      return const [];
    }
  }
}

(DateTime, DateTime)? _range(String value, DateTime day) {
  final parts = value.split(RegExp(r'\s*[-–]\s*'));
  if (parts.length != 2) return null;
  final start = _clock(parts[0], day);
  final end = _clock(parts[1], day);
  return start == null || end == null ? null : (start, end);
}

DateTime? _clock(String value, DateTime day) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return null;
  return DateTime(
    day.year,
    day.month,
    day.day,
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
  );
}

String _time(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour == 0
      ? 12
      : local.hour > 12
      ? local.hour - 12
      : local.hour;
  return '$hour:${local.minute.toString().padLeft(2, '0')} ${local.hour >= 12 ? 'PM' : 'AM'}';
}

String _dateTime(DateTime value) {
  final local = value.toLocal();
  return '${local.day}/${local.month} · ${_time(local)}';
}

double _number(Object? value) => switch (value) {
  final num number => number.toDouble(),
  final String text => double.tryParse(text) ?? 0,
  _ => 0,
};
