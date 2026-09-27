import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/access/effective_permissions.dart';
import '../../../../core/access/module_catalog.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../academics/data/student_assessments_repository.dart';
import '../../../authentication/data/auth_repository.dart';
import '../../../gatepass/data/gatepass_models.dart';
import '../../data/student_report_data.dart';

/// The student's report: academics first, campus services last.
///
/// Every section loads on its own, in parallel, so one slow or failing
/// service never hides the others. A section whose module the user may not
/// see is not shown at all; a section this build cannot read (no backend, a
/// mock build) says so plainly instead of showing invented numbers.
class StudentReportsAnalyticsScreen extends StatefulWidget {
  const StudentReportsAnalyticsScreen({
    super.key,
    required this.session,
    this.isParent = false,
    this.onOpenModule,
    this.baseUrl,
    this.accessTokenProvider,
    this.permissions,
    this.sources,
    this.clock = DateTime.now,
  });

  final UserSession session;
  final bool isParent;
  final ValueChanged<String>? onOpenModule;

  /// Backend the report reads from. With [accessTokenProvider] it builds the
  /// live repositories; either being null leaves every section unavailable.
  final String? baseUrl;
  final AccessTokenProvider? accessTokenProvider;

  /// Decides which sections exist. Null shows every section (hosts that have
  /// no permission set, such as the examination shell in older builds).
  final EffectivePermissions? permissions;

  /// Overrides the data sources — used by tests and previews.
  final StudentReportSources? sources;
  final DateTime Function() clock;

  @override
  State<StudentReportsAnalyticsScreen> createState() =>
      _StudentReportsAnalyticsScreenState();
}

/// One section's load state. Data survives a failed refresh so a flaky
/// network never blanks out figures the student was already reading.
class _Slot<T> {
  bool loading = false;
  bool hasData = false;
  T? data;
  Object? error;

  /// The server refused this data for this account (HTTP 403). The section is
  /// hidden, the same as a module the user cannot see, rather than shown as a
  /// failure with a Retry that can never succeed.
  bool forbidden = false;
}

/// Whether [error] is a permission refusal. Repositories surface either the
/// HTTP status ("Library request failed (403).") or the API's own 403 message
/// ("This session cannot access the requested tenant or resource").
bool _isAccessDenied(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('(403)') ||
      text.contains(' 403') ||
      text.contains('forbidden') ||
      text.contains('cannot access') ||
      text.contains('not allowed') ||
      text.contains('not permitted') ||
      text.contains('permission');
}

class _StudentReportsAnalyticsScreenState
    extends State<StudentReportsAnalyticsScreen> {
  late StudentReportSources _sources;

  final _attendance = _Slot<AttendanceReport>();
  final _marks = _Slot<List<StudentAssessment>>();
  final _fees = _Slot<FeeReport>();
  final _library = _Slot<LibraryReport>();
  final _canteen = _Slot<CanteenReport>();
  final _gatepass = _Slot<GatepassReport>();
  final _hostel = _Slot<HostelReport?>();

  DateTime? _updatedAt;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _sources = _resolveSources();
    unawaited(_loadAll());
  }

  StudentReportSources _resolveSources() {
    final override = widget.sources;
    if (override != null) return override;
    final baseUrl = widget.baseUrl?.trim() ?? '';
    final tokens = widget.accessTokenProvider;
    if (baseUrl.isEmpty || tokens == null) {
      return const StudentReportSources.unavailable();
    }
    // Parents read their ward's attendance by the id in their token, as the
    // examination shell always has; students read their own.
    final subject = widget.isParent
        ? (widget.session.parseJwtClaims()['sub']?.toString() ?? 'me')
        : 'me';
    return StudentReportSources.backend(
      baseUrl: baseUrl,
      accessTokenProvider: tokens,
      session: widget.session,
      attendanceSubject: subject.isEmpty ? 'me' : subject,
      clock: widget.clock,
    );
  }

  bool _can(String moduleId) =>
      widget.permissions?.canSeeModule(moduleId) ?? true;

  bool get _showAttendance =>
      _can(ModuleCatalog.attendance) && !_attendance.forbidden;
  bool get _showMarks =>
      (_can(ModuleCatalog.academics) || _can(ModuleCatalog.examination)) &&
      !_marks.forbidden;
  bool get _showFees => _can(ModuleCatalog.tuitionFee) && !_fees.forbidden;
  bool get _showLibrary => _can(ModuleCatalog.library) && !_library.forbidden;
  bool get _showCanteen => _can(ModuleCatalog.canteen) && !_canteen.forbidden;
  bool get _showGatepass =>
      _can(ModuleCatalog.gatepass) && !_gatepass.forbidden;
  bool get _showHostel => _can(ModuleCatalog.hostel) && !_hostel.forbidden;

  Future<void> _loadAll() async {
    setState(() => _refreshing = true);
    final results = await Future.wait<bool>([
      if (_showAttendance) _load(_attendance, _sources.attendance),
      if (_showMarks) _load(_marks, _sources.marks),
      if (_showFees) _load(_fees, _sources.fees),
      if (_showLibrary) _load(_library, _sources.library),
      if (_showCanteen) _load(_canteen, _sources.canteen),
      if (_showGatepass) _load(_gatepass, _sources.gatepass),
      if (_showHostel) _load(_hostel, _sources.hostel),
    ]);
    if (!mounted) return;
    setState(() {
      _refreshing = false;
      if (results.any((ok) => ok)) _updatedAt = widget.clock();
    });
  }

  /// Returns whether fresh data arrived.
  Future<bool> _load<T>(_Slot<T> slot, ReportLoader<T>? loader) async {
    if (loader == null) return false;
    setState(() {
      slot.loading = true;
      slot.error = null;
    });
    try {
      final data = await loader();
      if (!mounted) return true;
      setState(() {
        slot
          ..data = data
          ..hasData = true
          ..loading = false;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        slot
          ..error = error
          ..forbidden = _isAccessDenied(error)
          ..loading = false;
      });
      return false;
    }
  }

  void _open(String moduleId) => widget.onOpenModule?.call(moduleId);

  ValueChanged<String>? get _opener =>
      widget.onOpenModule == null ? null : _open;

  @override
  Widget build(BuildContext context) {
    final showServices = _showCanteen || _showGatepass || _showHostel;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 680;
        final gutter = wide ? 24.0 : 16.0;
        final feesCard = _showFees
            ? _FeesSection(
                slot: _fees,
                available: _sources.fees != null,
                onRetry: () => _load(_fees, _sources.fees),
                onOpen: _opener,
              )
            : null;
        final libraryCard = _showLibrary
            ? _LibrarySection(
                slot: _library,
                available: _sources.library != null,
                onRetry: () => _load(_library, _sources.library),
                onOpen: _opener,
              )
            : null;

        final children = <Widget>[
          _ReportHeader(
            session: widget.session,
            isParent: widget.isParent,
            updatedAt: _updatedAt,
            refreshing: _refreshing,
          ),
          if (_showAttendance) ...[
            const SizedBox(height: 24),
            _AttendanceSection(
              slot: _attendance,
              available: _sources.attendance != null,
              onRetry: () => _load(_attendance, _sources.attendance),
              onOpen: _opener,
            ),
          ],
          if (_showMarks) ...[
            const SizedBox(height: 28),
            _MarksSection(
              slot: _marks,
              available: _sources.marks != null,
              onRetry: () => _load(_marks, _sources.marks),
            ),
          ],
          if (feesCard != null || libraryCard != null) ...[
            const SizedBox(height: 28),
            if (wide && feesCard != null && libraryCard != null)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: feesCard),
                  const SizedBox(width: 16),
                  Expanded(child: libraryCard),
                ],
              )
            else ...[
              ?feesCard,
              if (feesCard != null && libraryCard != null)
                const SizedBox(height: 28),
              ?libraryCard,
            ],
          ],
          if (showServices) ...[
            const SizedBox(height: 28),
            _ServicesSection(
              canteen: _showCanteen ? _canteen : null,
              gatepass: _showGatepass ? _gatepass : null,
              hostel: _showHostel ? _hostel : null,
              sources: _sources,
              onRetryCanteen: () => _load(_canteen, _sources.canteen),
              onRetryGatepass: () => _load(_gatepass, _sources.gatepass),
              onRetryHostel: () => _load(_hostel, _sources.hostel),
              onOpen: _opener,
            ),
          ],
          const SizedBox(height: 28),
          _ExportSection(
            attendanceReady: _attendance.hasData,
            onExportAttendance: () => _exportAttendanceCsv(context),
            onExportStatement: () => _exportStatementCsv(context),
          ),
          const SizedBox(height: 32),
        ];

        return RefreshIndicator(
          onRefresh: _loadAll,
          child: ListView(
            key: const Key('student-report-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 16),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────── Export ───────────────────────────────

  Future<void> _exportAttendanceCsv(BuildContext context) async {
    final report = _attendance.data;
    final rows = <List<String>>[
      ['Subject', 'Subject Code', 'Date', 'Period', 'Faculty', 'Status'],
      for (final r in report?.records ?? const <AttendancePeriod>[])
        [
          r.subjectName ?? '',
          r.subjectCode ?? '',
          r.heldOn,
          r.periodLabel ?? '',
          r.facultyName ?? '',
          r.rawStatus,
        ],
      if (report == null || report.records.isEmpty)
        ['No attendance records found', '', '', '', '', ''],
      if (report != null && report.subjects.isNotEmpty) ...[
        ['', '', '', '', '', ''],
        ['Subject', 'Subject Code', 'Attended', 'Total', 'Percentage', ''],
        for (final s in report.subjectsByRisk)
          [
            s.name,
            s.code,
            '${s.attended}',
            '${s.total}',
            '${s.percent.toStringAsFixed(1)}%',
            '',
          ],
      ],
    ];
    await _saveCsv(
      context,
      rows,
      dialogTitle: 'Save attendance report',
      fileName: 'SuperCampus_Attendance_${_fileTag()}.csv',
      success: 'Attendance report exported',
    );
  }

  Future<void> _exportStatementCsv(BuildContext context) async {
    String money(double v) => 'INR ${v.toStringAsFixed(2)}';
    final att = _attendance.data;
    final marks = _marks.data;
    final fees = _fees.data;
    final library = _library.data;
    final canteen = _canteen.data;
    final gatepass = _gatepass.data;
    final hostel = _hostel.data;
    final rows = <List<String>>[
      ['Section', 'Metric', 'Value'],
      ['Student', 'Name', widget.session.displayName],
      ['Student', 'Roll Number', widget.session.idNumber ?? 'N/A'],
      ['Student', 'Department', widget.session.departmentOrWard ?? 'N/A'],
      if (att != null) ...[
        ['Attendance', 'Total Classes', '${att.total}'],
        ['Attendance', 'Attended Classes', '${att.attended}'],
        ['Attendance', 'Percentage', '${att.percent.toStringAsFixed(2)}%'],
        [
          'Attendance',
          'Present / Absent / OD / Leave',
          '${att.present} / ${att.absent} / ${att.onDuty} / ${att.leave}',
        ],
      ],
      if (marks != null)
        for (final group in groupAssessments(marks))
          [
            'Marks',
            '${group.label} average (${group.assessments.length})',
            '${group.averagePercent.toStringAsFixed(1)}%',
          ],
      if (fees != null) ...[
        ['Fees', 'Outstanding', money(fees.outstanding)],
        ['Fees', 'Paid', money(fees.paid)],
        if (fees.lastPaymentOn != null)
          [
            'Fees',
            'Last Payment',
            DateFormat('yyyy-MM-dd').format(fees.lastPaymentOn!),
          ],
      ],
      if (library != null) ...[
        ['Library', 'Books on Loan', '${library.onLoan}'],
        ['Library', 'Overdue', '${library.overdue}'],
        ['Library', 'Fines', money(library.totalFine)],
      ],
      if (canteen != null) ...[
        for (final shop in canteen.balances)
          ['Canteen', '${shop.name} wallet', money(shop.balance)],
        ['Canteen', 'Spent this month', money(canteen.monthSpend)],
        ['Canteen', 'Orders this month', '${canteen.monthOrders}'],
      ],
      if (gatepass != null) ...[
        ['Gatepass', 'Passes (last 6 months)', '${gatepass.recentPasses}'],
        [
          'Gatepass',
          'Active pass',
          gatepass.activePass == null
              ? 'None'
              : gatepass.activePass!.destination,
        ],
      ],
      if (hostel != null)
        [
          'Hostel',
          'Room',
          '${hostel.hostelName} · ${hostel.blockName} · ${hostel.roomNumber}',
        ],
    ];
    await _saveCsv(
      context,
      rows,
      dialogTitle: 'Save overall statement',
      fileName: 'SuperCampus_Statement_${_fileTag()}.csv',
      success: 'Statement exported',
    );
  }

  String _fileTag() {
    final id = widget.session.idNumber?.trim() ?? '';
    return id.isEmpty
        ? 'Student'
        : id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  Future<void> _saveCsv(
    BuildContext context,
    List<List<String>> rows, {
    required String dialogTitle,
    required String fileName,
    required String success,
  }) async {
    final csv = rows
        .map((row) => row.map((v) => '"${v.replaceAll('"', '""')}"').join(','))
        .join('\r\n');
    final bytes = Uint8List.fromList(utf8.encode(csv));
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final saved = await FilePicker.saveFile(
        dialogTitle: dialogTitle,
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: bytes,
      );
      // Null is a cancel on native platforms; the web always returns null
      // after starting the download.
      if (saved == null && !kIsWeb) return;
      messenger?.showSnackBar(SnackBar(content: Text(success)));
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(content: Text("Couldn't save the file. Try again.")),
      );
    }
  }
}

// ═══════════════════════════════ Building blocks ═══════════════════════════════

enum _Tone { success, warning, danger, info, neutral, brand }

extension on _Tone {
  Color fg(BuildContext context) {
    final p = context.palette;
    return switch (this) {
      _Tone.success => p.success,
      _Tone.warning => p.warning,
      _Tone.danger => p.danger,
      _Tone.info => p.info,
      _Tone.neutral => p.inkSecondary,
      _Tone.brand => p.brandInk,
    };
  }

  Color bg(BuildContext context) {
    final p = context.palette;
    return switch (this) {
      _Tone.success => p.successSoft,
      _Tone.warning => p.warningSoft,
      _Tone.danger => p.dangerSoft,
      _Tone.info => p.infoSoft,
      _Tone.neutral => p.surfaceMuted,
      _Tone.brand => p.brandSoft,
    };
  }
}

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

Duration _motion(BuildContext context, int ms) =>
    _reduceMotion(context) ? Duration.zero : Duration(milliseconds: ms);

final _rupees = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);
final _rupeesExact = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);
final _day = DateFormat('d MMM yyyy');
final _dayShort = DateFormat('d MMM');
final _time = DateFormat('h:mm a');

String _money(double v) =>
    v == v.roundToDouble() ? _rupees.format(v) : _rupeesExact.format(v);

String _plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';

String _fmtPercent(double v) =>
    v == v.roundToDouble() ? '${v.toInt()}%' : '${v.toStringAsFixed(1)}%';

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final radius = BorderRadius.circular(20);
    // The surface is a Material so rows inside it keep their ink feedback.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: context.isDarkTheme
            ? null
            : [
                BoxShadow(
                  color: p.shadow,
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: p.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: p.border),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.icon, this.action, this.onAction});

  final String title;
  final IconData? icon;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: p.brandInk),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: p.ink,
                ),
              ),
            ),
          ),
          if (action != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: p.brandInk,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(44, 36),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Picks skeleton / error / unavailable / content for one section's slot and
/// cross-fades between them (instantly under reduced motion).
class _SlotView<T> extends StatelessWidget {
  const _SlotView({
    required this.slot,
    required this.available,
    required this.label,
    required this.onRetry,
    required this.builder,
    this.skeletonHeight = 96,
  });

  final _Slot<T> slot;
  final bool available;
  final String label;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T data) builder;
  final double skeletonHeight;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (!available) {
      child = _Notice(
        key: const ValueKey('unavailable'),
        icon: Icons.cloud_off_outlined,
        text:
            '${label[0].toUpperCase()}${label.substring(1)} is not available in this build.',
      );
    } else if (slot.hasData) {
      child = KeyedSubtree(
        key: const ValueKey('data'),
        child: builder(context, slot.data as T),
      );
    } else if (slot.error != null) {
      child = _ErrorNotice(
        key: const ValueKey('error'),
        text: "Couldn't load $label.",
        onRetry: onRetry,
      );
    } else {
      child = Semantics(
        key: const ValueKey('loading'),
        label: 'Loading $label',
        child: SkeletonBox(height: skeletonHeight),
      );
    }
    return AnimatedSwitcher(
      duration: _motion(context, 220),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previous, ?current],
      ),
      child: child,
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: p.inkTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: p.inkSecondary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({super.key, required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Icon(Icons.error_outline_rounded, size: 20, color: p.danger),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 14, color: p.ink, height: 1.35),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          style: TextButton.styleFrom(
            foregroundColor: p.brandInk,
            minimumSize: const Size(44, 40),
          ),
          child: const Text(
            'Retry',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final fg = tone.fg(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: tone.bg(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A thin bar with a tick at the 75% line.
class _ThresholdBar extends StatelessWidget {
  const _ThresholdBar({required this.fraction, required this.tone});

  static const height = 6.0;
  final double fraction;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return SizedBox(
          height: height + 4,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Container(
                height: height,
                decoration: BoxDecoration(
                  color: p.surfaceMuted,
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
              AnimatedContainer(
                duration: _motion(context, 450),
                curve: Curves.easeOutCubic,
                width: w * fraction.clamp(0.0, 1.0),
                height: height,
                decoration: BoxDecoration(
                  color: tone.fg(context),
                  borderRadius: BorderRadius.circular(height),
                ),
              ),
              Positioned(
                left: w * kRequiredAttendanceFraction - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: p.inkTertiary),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════ Header ═══════════════════════════════════

class _ReportHeader extends StatelessWidget {
  const _ReportHeader({
    required this.session,
    required this.isParent,
    required this.updatedAt,
    required this.refreshing,
  });

  final UserSession session;
  final bool isParent;
  final DateTime? updatedAt;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = session.displayName.trim().isEmpty
        ? 'Student'
        : session.displayName.trim();
    final initials = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    final details = [
      if ((session.idNumber ?? '').trim().isNotEmpty) session.idNumber!.trim(),
      if ((session.departmentOrWard ?? '').trim().isNotEmpty)
        isParent
            ? 'Ward: ${session.departmentOrWard!.trim()}'
            : session.departmentOrWard!.trim(),
    ].join(' · ');
    final photo = session.photoUrl?.trim() ?? '';
    final String status;
    if (refreshing && updatedAt == null) {
      status = 'Loading your report…';
    } else if (refreshing) {
      status = 'Updating…';
    } else if (updatedAt != null) {
      status = 'Updated ${_time.format(updatedAt!)}';
    } else {
      status = 'Pull down to refresh';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: p.brandSoft,
            foregroundImage: photo.startsWith('http')
                ? NetworkImage(photo)
                : null,
            child: Text(
              initials.isEmpty ? '?' : initials,
              style: TextStyle(
                color: p.brandInk,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: p.ink,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: p.inkSecondary),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  status,
                  key: const Key('report-updated'),
                  style: TextStyle(fontSize: 12, color: p.inkTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════ Attendance ═════════════════════════════════

({String label, IconData icon, _Tone tone}) _standingStyle(
  AttendanceStanding s,
) => switch (s) {
  AttendanceStanding.safe => (
    label: 'Safe',
    icon: Icons.check_circle_rounded,
    tone: _Tone.success,
  ),
  AttendanceStanding.close => (
    label: 'Close to 75%',
    icon: Icons.error_outline_rounded,
    tone: _Tone.warning,
  ),
  AttendanceStanding.below => (
    label: 'Below 75%',
    icon: Icons.warning_rounded,
    tone: _Tone.danger,
  ),
  AttendanceStanding.none => (
    label: 'No classes yet',
    icon: Icons.schedule_rounded,
    tone: _Tone.neutral,
  ),
};

String attendanceActionLine(AttendanceReport r) {
  if (r.total == 0) return 'Attendance will appear once classes are marked.';
  if (r.standing == AttendanceStanding.below) {
    final n = r.needed;
    return n == 1
        ? 'Attend the next class to reach 75%'
        : 'Attend the next $n classes to reach 75%';
  }
  final m = r.canMiss;
  return switch (m) {
    0 => "Don't miss your next class",
    1 => 'You can miss 1 more class',
    _ => 'You can miss $m more classes',
  };
}

class _AttendanceSection extends StatelessWidget {
  const _AttendanceSection({
    required this.slot,
    required this.available,
    required this.onRetry,
    required this.onOpen,
  });

  final _Slot<AttendanceReport> slot;
  final bool available;
  final VoidCallback onRetry;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('report-attendance'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          'Attendance',
          icon: Icons.fact_check_outlined,
          action: 'Open',
          onAction: onOpen == null
              ? null
              : () => onOpen!(ModuleCatalog.attendance),
        ),
        _Card(
          child: _SlotView<AttendanceReport>(
            slot: slot,
            available: available,
            label: 'attendance',
            onRetry: onRetry,
            skeletonHeight: 180,
            builder: (context, r) => _AttendanceBody(report: r),
          ),
        ),
      ],
    );
  }
}

class _AttendanceBody extends StatefulWidget {
  const _AttendanceBody({required this.report});

  final AttendanceReport report;

  @override
  State<_AttendanceBody> createState() => _AttendanceBodyState();
}

class _AttendanceBodyState extends State<_AttendanceBody> {
  static const _collapsedSubjects = 5;
  bool _allSubjects = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = widget.report;
    final style = _standingStyle(r.standing);
    final subjects = r.subjectsByRisk;
    final shown = _allSubjects
        ? subjects
        : subjects.take(_collapsedSubjects).toList();
    final recent = r.recent();

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusPill(icon: style.icon, label: style.label, tone: style.tone),
        const SizedBox(height: 10),
        Text(
          attendanceActionLine(r),
          key: const Key('attendance-action'),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            height: 1.3,
            letterSpacing: -0.2,
            color: p.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          r.total == 0
              ? 'No classes recorded'
              : '${r.attended} of ${_plural(r.total, 'class', 'classes')} attended',
          style: TextStyle(fontSize: 13, color: p.inkSecondary),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final ring = _AttendanceRing(
              report: r,
              tone: style.tone,
              size: c.maxWidth < 300 ? 96 : 116,
            );
            if (c.maxWidth < 260) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [ring, const SizedBox(height: 12), summary],
              );
            }
            return Row(
              children: [
                ring,
                const SizedBox(width: 18),
                Expanded(child: summary),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _CountTile(label: 'Present', value: r.present, tone: _Tone.success),
            _CountTile(label: 'Absent', value: r.absent, tone: _Tone.danger),
            _CountTile(label: 'On duty', value: r.onDuty, tone: _Tone.info),
            _CountTile(
              label: 'Leave',
              value: r.leave,
              tone: _Tone.warning,
              last: true,
            ),
          ],
        ),
        if (subjects.isNotEmpty) ...[
          const SizedBox(height: 18),
          Divider(height: 1, color: p.divider),
          const SizedBox(height: 14),
          Text(
            'By subject · lowest first',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: p.inkSecondary,
            ),
          ),
          const SizedBox(height: 4),
          for (final s in shown) _SubjectRow(subject: s),
          if (subjects.length > _collapsedSubjects)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _allSubjects = !_allSubjects),
                style: TextButton.styleFrom(
                  foregroundColor: p.brandInk,
                  padding: EdgeInsets.zero,
                ),
                child: Text(
                  _allSubjects
                      ? 'Show fewer'
                      : 'Show all ${subjects.length} subjects',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 14),
          Divider(height: 1, color: p.divider),
          const SizedBox(height: 14),
          Text(
            'Recent classes · oldest to newest',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: p.inkSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final period in recent) _PeriodChip(period: period),
            ],
          ),
        ],
      ],
    );
  }
}

class _AttendanceRing extends StatelessWidget {
  const _AttendanceRing({
    required this.report,
    required this.tone,
    required this.size,
  });

  final AttendanceReport report;
  final _Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final target = report.total == 0 ? 0.0 : report.fraction.clamp(0.0, 1.0);
    return Semantics(
      label: report.total == 0
          ? 'No attendance recorded'
          : 'Attendance ${report.percent.round()} percent. ${_standingStyle(report.standing).label}.',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: target),
        duration: _motion(context, 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _RingPainter(
              value: value,
              threshold: kRequiredAttendanceFraction,
              track: p.surfaceMuted,
              fill: tone.fg(context),
              tick: p.ink,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    child: Text(
                      report.total == 0
                          ? '—'
                          : _fmtPercent(
                              double.parse(report.percent.toStringAsFixed(1)),
                            ),
                      key: const Key('attendance-percent'),
                      style: TextStyle(
                        fontSize: size * 0.22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        color: p.ink,
                      ),
                    ),
                  ),
                  Text(
                    'attended',
                    style: TextStyle(fontSize: 10.5, color: p.inkTertiary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.threshold,
    required this.track,
    required this.fill,
    required this.tick,
  });

  final double value;
  final double threshold;
  final Color track;
  final Color fill;
  final Color tick;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2 + 2);
    const start = -math.pi / 2;
    canvas.drawArc(
      arcRect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (value > 0) {
      canvas.drawArc(
        arcRect,
        start,
        math.pi * 2 * value,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = fill,
      );
    }
    // The 75% line, drawn across the ring so it reads as a target.
    final angle = start + math.pi * 2 * threshold;
    final c = rect.center;
    final rOuter = arcRect.width / 2 + stroke / 2 + 1;
    final rInner = arcRect.width / 2 - stroke / 2 - 1;
    canvas.drawLine(
      c + Offset(math.cos(angle), math.sin(angle)) * rInner,
      c + Offset(math.cos(angle), math.sin(angle)) * rOuter,
      Paint()
        ..color = tick
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.fill != fill ||
      old.track != track ||
      old.tick != tick;
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.label,
    required this.value,
    required this.tone,
    this.last = false,
  });

  final String label;
  final int value;
  final _Tone tone;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Container(
        margin: EdgeInsets.only(right: last ? 0 : 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: p.surfaceSunken,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 14,
              height: 3,
              decoration: BoxDecoration(
                color: tone.fg(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: TextStyle(fontSize: 11.5, color: p.inkSecondary),
            ),
            const SizedBox(height: 4),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: p.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectRow extends StatelessWidget {
  const _SubjectRow({required this.subject});

  final SubjectAttendance subject;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = subject;
    final standing = attendanceStanding(s.attended, s.total);
    final tone = _standingStyle(standing).tone;
    final String note;
    if (s.total == 0) {
      note = 'No classes yet';
    } else if (s.isBelow) {
      note = 'needs ${_plural(s.needed, 'class', 'classes')}';
    } else {
      note = s.canMiss == 0 ? "don't miss the next" : 'can miss ${s.canMiss}';
    }
    return Padding(
      key: ValueKey('subject-${s.code}-${s.name}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: s.name),
                      if (s.code.isNotEmpty && s.code != s.name)
                        TextSpan(
                          text: '  ${s.code}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: p.inkTertiary,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (s.isBelow) ...[
                Icon(Icons.warning_rounded, size: 15, color: p.danger),
                const SizedBox(width: 3),
              ],
              Text(
                s.total == 0 ? '—' : '${s.percent.round()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: s.isBelow ? p.danger : p.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _ThresholdBar(fraction: s.total == 0 ? 0 : s.fraction, tone: tone),
          const SizedBox(height: 4),
          Text(
            '${s.attended}/${s.total} classes · $note',
            style: TextStyle(
              fontSize: 12,
              color: s.isBelow ? p.danger : p.inkSecondary,
              fontWeight: s.isBelow ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.period});

  final AttendancePeriod period;

  @override
  Widget build(BuildContext context) {
    final (letter, word, tone) = switch (period.mark) {
      AttendanceMark.present => ('P', 'Present', _Tone.success),
      AttendanceMark.absent => ('A', 'Absent', _Tone.danger),
      AttendanceMark.onDuty => ('OD', 'On duty', _Tone.info),
      AttendanceMark.leave => ('L', 'Leave', _Tone.warning),
      AttendanceMark.other => (
        '–',
        period.rawStatus.isEmpty ? 'Unmarked' : period.rawStatus,
        _Tone.neutral,
      ),
    };
    final description = [
      word,
      if (period.subjectName != null) period.subjectName!,
      period.heldOn,
      if (period.periodLabel != null) period.periodLabel!,
    ].join(' · ');
    return Tooltip(
      message: description,
      child: Semantics(
        label: description,
        excludeSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: tone.bg(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            letter,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w700,
              color: tone.fg(context),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════ Marks ═══════════════════════════════════

class _MarksSection extends StatelessWidget {
  const _MarksSection({
    required this.slot,
    required this.available,
    required this.onRetry,
  });

  final _Slot<List<StudentAssessment>> slot;
  final bool available;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('report-marks'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Marks', icon: Icons.school_outlined),
        _Card(
          child: _SlotView<List<StudentAssessment>>(
            slot: slot,
            available: available,
            label: 'marks',
            onRetry: onRetry,
            builder: (context, list) {
              if (list.isEmpty) {
                return const _Notice(
                  icon: Icons.hourglass_empty_rounded,
                  text: 'No marks published yet.',
                );
              }
              final groups = groupAssessments(list);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < groups.length; i++) ...[
                    if (i > 0) ...[
                      const SizedBox(height: 10),
                      Divider(height: 1, color: context.palette.divider),
                      const SizedBox(height: 12),
                    ],
                    _MarksGroupView(group: groups[i]),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MarksGroupView extends StatefulWidget {
  const _MarksGroupView({required this.group});

  final MarksGroup group;

  @override
  State<_MarksGroupView> createState() => _MarksGroupViewState();
}

class _MarksGroupViewState extends State<_MarksGroupView> {
  static const _collapsed = 4;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final g = widget.group;
    final rows = _all ? g.assessments : g.assessments.take(_collapsed).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                g.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
            ),
            Text(
              'Average ${g.averagePercent.round()}%',
              key: ValueKey('marks-average-${g.kind.name}'),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: p.brandInk,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        for (final a in rows) _AssessmentRow(assessment: a),
        if (g.assessments.length > _collapsed)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _all = !_all),
              style: TextButton.styleFrom(
                foregroundColor: p.brandInk,
                padding: EdgeInsets.zero,
              ),
              child: Text(
                _all ? 'Show fewer' : 'Show all ${g.assessments.length}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }
}

class _AssessmentRow extends StatelessWidget {
  const _AssessmentRow({required this.assessment});

  final StudentAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final a = assessment;
    String num(double v) =>
        v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
    final meta = [
      if (a.subjectCode != null) a.subjectCode!,
      if (a.semester != null) 'Sem ${a.semester}',
      if (a.assessedOn != null) _dayShort.format(a.assessedOn!.toLocal()),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: p.ink,
                  ),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: p.inkTertiary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${num(a.marksObtained)} / ${num(a.maximumMarks)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
              ),
              Text(
                '${a.percentage.round()}%',
                style: TextStyle(fontSize: 12, color: p.inkSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════ Fees ═══════════════════════════════════

class _FeesSection extends StatelessWidget {
  const _FeesSection({
    required this.slot,
    required this.available,
    required this.onRetry,
    required this.onOpen,
  });

  final _Slot<FeeReport> slot;
  final bool available;
  final VoidCallback onRetry;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      key: const Key('report-fees'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          'Fees',
          icon: Icons.account_balance_outlined,
          action: 'Open',
          onAction: onOpen == null
              ? null
              : () => onOpen!(ModuleCatalog.tuitionFee),
        ),
        _Card(
          child: _SlotView<FeeReport>(
            slot: slot,
            available: available,
            label: 'fees',
            onRetry: onRetry,
            builder: (context, f) {
              if (!f.hasRecords) {
                return const _Notice(
                  icon: Icons.receipt_long_outlined,
                  text: 'No fee records yet.',
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (f.isSettled)
                    const _StatusPill(
                      icon: Icons.check_circle_rounded,
                      label: 'All paid',
                      tone: _Tone.success,
                    )
                  else
                    const _StatusPill(
                      icon: Icons.schedule_rounded,
                      label: 'Payment due',
                      tone: _Tone.warning,
                    ),
                  const SizedBox(height: 10),
                  Text(
                    f.isSettled ? _money(0) : _money(f.outstanding),
                    key: const Key('fees-outstanding'),
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: p.ink,
                    ),
                  ),
                  Text(
                    'Outstanding',
                    style: TextStyle(fontSize: 13, color: p.inkSecondary),
                  ),
                  const SizedBox(height: 12),
                  _KeyValue(label: 'Paid so far', value: _money(f.paid)),
                  _KeyValue(
                    label: 'Last payment',
                    value: f.lastPaymentOn == null
                        ? 'None yet'
                        : '${_day.format(f.lastPaymentOn!.toLocal())}'
                              '${f.lastPaymentAmount == null ? '' : ' · ${_money(f.lastPaymentAmount!)}'}',
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({
    super.key,
    required this.label,
    required this.value,
    this.tone,
  });

  final String label;
  final String value;
  final _Tone? tone;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: p.inkSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: tone?.fg(context) ?? p.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════ Library ══════════════════════════════════

class _LibrarySection extends StatelessWidget {
  const _LibrarySection({
    required this.slot,
    required this.available,
    required this.onRetry,
    required this.onOpen,
  });

  final _Slot<LibraryReport> slot;
  final bool available;
  final VoidCallback onRetry;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      key: const Key('report-library'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          'Library',
          icon: Icons.menu_book_outlined,
          action: 'Open',
          onAction: onOpen == null
              ? null
              : () => onOpen!(ModuleCatalog.library),
        ),
        _Card(
          child: _SlotView<LibraryReport>(
            slot: slot,
            available: available,
            label: 'library loans',
            onRetry: onRetry,
            builder: (context, l) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (l.overdue > 0)
                    _StatusPill(
                      icon: Icons.warning_rounded,
                      label: '${l.overdue} overdue',
                      tone: _Tone.danger,
                    )
                  else
                    _StatusPill(
                      icon: Icons.check_circle_rounded,
                      label: l.onLoan == 0 ? 'Nothing borrowed' : 'On time',
                      tone: l.onLoan == 0 ? _Tone.neutral : _Tone.success,
                    ),
                  const SizedBox(height: 10),
                  Text(
                    '${l.onLoan}',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                      color: p.ink,
                    ),
                  ),
                  Text(
                    l.onLoan == 1 ? 'Book on loan' : 'Books on loan',
                    style: TextStyle(fontSize: 13, color: p.inkSecondary),
                  ),
                  const SizedBox(height: 12),
                  _KeyValue(
                    label: 'Next due',
                    value: l.nextDueAt == null
                        ? '—'
                        : '${_day.format(l.nextDueAt!)}${l.nextDueTitle == null ? '' : ' · ${l.nextDueTitle}'}',
                  ),
                  _KeyValue(
                    label: 'Fines',
                    value: l.totalFine <= 0 ? 'None' : _money(l.totalFine),
                    tone: l.totalFine > 0 ? _Tone.danger : null,
                  ),
                  if (l.pendingRequests > 0)
                    _KeyValue(
                      label: 'Requests waiting',
                      value: '${l.pendingRequests}',
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════ Services ═════════════════════════════════

class _ServicesSection extends StatelessWidget {
  const _ServicesSection({
    required this.canteen,
    required this.gatepass,
    required this.hostel,
    required this.sources,
    required this.onRetryCanteen,
    required this.onRetryGatepass,
    required this.onRetryHostel,
    required this.onOpen,
  });

  final _Slot<CanteenReport>? canteen;
  final _Slot<GatepassReport>? gatepass;
  final _Slot<HostelReport?>? hostel;
  final StudentReportSources sources;
  final VoidCallback onRetryCanteen;
  final VoidCallback onRetryGatepass;
  final VoidCallback onRetryHostel;
  final ValueChanged<String>? onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // A student with no room is not a hosteller: the row simply isn't there.
    final hostelVisible =
        hostel != null &&
        sources.hostel != null &&
        !(hostel!.hasData && hostel!.data == null);
    final blocks = <Widget>[
      if (canteen != null)
        _ServiceBlock(
          key: const Key('report-canteen'),
          icon: Icons.restaurant_outlined,
          title: 'Canteen wallet',
          onOpen: onOpen == null ? null : () => onOpen!(ModuleCatalog.canteen),
          child: _SlotView<CanteenReport>(
            slot: canteen!,
            available: sources.canteen != null,
            label: 'canteen',
            onRetry: onRetryCanteen,
            skeletonHeight: 48,
            builder: (context, c) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (c.balances.isEmpty)
                  Text(
                    'No wallet yet',
                    style: TextStyle(fontSize: 14, color: p.inkSecondary),
                  )
                else
                  for (final shop in c.balances)
                    _KeyValue(
                      key: ValueKey('wallet-${shop.shopKey}'),
                      label: shop.name,
                      value: _rupeesExact.format(shop.balance),
                    ),
                const SizedBox(height: 2),
                Text(
                  'This month: ${_money(c.monthSpend)} spent · ${_plural(c.monthOrders, 'order')}',
                  style: TextStyle(fontSize: 12.5, color: p.inkTertiary),
                ),
              ],
            ),
          ),
        ),
      if (gatepass != null)
        _ServiceBlock(
          key: const Key('report-gatepass'),
          icon: Icons.badge_outlined,
          title: 'Gatepass',
          onOpen: onOpen == null ? null : () => onOpen!(ModuleCatalog.gatepass),
          child: _SlotView<GatepassReport>(
            slot: gatepass!,
            available: sources.gatepass != null,
            label: 'gatepass',
            onRetry: onRetryGatepass,
            skeletonHeight: 48,
            builder: (context, g) {
              final active = g.activePass;
              final move = g.lastMovement;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _KeyValue(
                    label: 'Active pass',
                    value: active == null
                        ? 'None'
                        : 'Until ${_dayShort.format(active.returnAt.toLocal())}, ${_time.format(active.returnAt.toLocal())}',
                    tone: active == null ? null : _Tone.success,
                  ),
                  _KeyValue(
                    label: 'Last 6 months',
                    value: g.recentPasses == 0
                        ? 'No passes'
                        : '${_plural(g.recentPasses, 'pass', 'passes')}'
                              '${g.pending > 0 ? ' · ${g.pending} pending' : ''}',
                  ),
                  _KeyValue(
                    label: 'Last gate',
                    value: move == null
                        ? '—'
                        : '${move.direction == MovementDirection.exit ? 'Out' : 'In'}'
                              '${move.gate.trim().isEmpty ? '' : ' · ${move.gate}'}'
                              ' · ${_dayShort.format(move.recordedAt.toLocal())}, ${_time.format(move.recordedAt.toLocal())}',
                  ),
                ],
              );
            },
          ),
        ),
      if (hostelVisible)
        _ServiceBlock(
          key: const Key('report-hostel'),
          icon: Icons.apartment_outlined,
          title: 'Hostel',
          onOpen: onOpen == null ? null : () => onOpen!(ModuleCatalog.hostel),
          child: _SlotView<HostelReport?>(
            slot: hostel!,
            available: true,
            label: 'hostel',
            onRetry: onRetryHostel,
            skeletonHeight: 40,
            builder: (context, h) => Text(
              [
                h!.hostelName,
                if (h.blockName.trim().isNotEmpty) h.blockName,
                if (h.roomNumber.trim().isNotEmpty) 'Room ${h.roomNumber}',
              ].where((s) => s.trim().isNotEmpty).join(' · '),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
          ),
        ),
    ];
    if (blocks.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('report-services'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Campus services', icon: Icons.storefront_outlined),
        _Card(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < blocks.length; i++) ...[
                if (i > 0) Divider(height: 1, color: p.divider),
                blocks[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceBlock extends StatelessWidget {
  const _ServiceBlock({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.onOpen,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: p.brandSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: p.brandInk),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: p.ink,
                  ),
                ),
              ),
              if (onOpen != null)
                IconButton(
                  tooltip: 'Open $title',
                  onPressed: onOpen,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.chevron_right_rounded, color: p.inkTertiary),
                ),
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

// ══════════════════════════════════ Export ══════════════════════════════════

class _ExportSection extends StatelessWidget {
  const _ExportSection({
    required this.attendanceReady,
    required this.onExportAttendance,
    required this.onExportStatement,
  });

  final bool attendanceReady;
  final VoidCallback onExportAttendance;
  final VoidCallback onExportStatement;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget row({
      required Key key,
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback? onTap,
    }) {
      return ListTile(
        key: key,
        contentPadding: EdgeInsets.zero,
        enabled: onTap != null,
        onTap: onTap,
        leading: Icon(icon, color: onTap == null ? p.inkDisabled : p.brandInk),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: onTap == null ? p.inkDisabled : p.ink,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12.5, color: p.inkSecondary),
        ),
        trailing: Icon(
          Icons.download_rounded,
          size: 20,
          color: onTap == null ? p.inkDisabled : p.inkTertiary,
        ),
      );
    }

    return Column(
      key: const Key('report-export'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle('Export', icon: Icons.ios_share_rounded),
        _Card(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Column(
            children: [
              row(
                key: const Key('export-attendance'),
                icon: Icons.fact_check_outlined,
                title: 'Attendance report',
                subtitle: attendanceReady
                    ? 'Every class and subject totals · CSV'
                    : 'Available once attendance loads',
                onTap: attendanceReady ? onExportAttendance : null,
              ),
              Divider(height: 1, color: p.divider),
              row(
                key: const Key('export-statement'),
                icon: Icons.summarize_outlined,
                title: 'Overall statement',
                subtitle: 'Everything on this page · CSV',
                onTap: onExportStatement,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
