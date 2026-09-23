import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/module_catalog.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../attendance/data/attendance_repository.dart';
import '../../../authentication/data/auth_repository.dart';
import '../../../canteen/data/backend_canteen_repository.dart';
import '../../../canteen/data/canteen_models.dart';
import '../../../gatepass/data/backend_gatepass_repository.dart';
import '../../../gatepass/data/gatepass_models.dart';
import '../../../library/data/backend_library_repository.dart';
import '../../../library/data/library_models.dart';

class StudentReportsAnalyticsScreen extends StatefulWidget {
  const StudentReportsAnalyticsScreen({
    super.key,
    required this.session,
    this.isParent = false,
    this.onOpenModule,
  });

  final UserSession session;
  final bool isParent;
  final ValueChanged<String>? onOpenModule;

  @override
  State<StudentReportsAnalyticsScreen> createState() =>
      _StudentReportsAnalyticsScreenState();
}

class _StudentReportsAnalyticsScreenState
    extends State<StudentReportsAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  static const _backendBaseUrl = String.fromEnvironment(
    'SUPERCAMPUS_API_BASE_URL',
    defaultValue: 'https://api.supercampus.ai',
  );

  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  // Real data across overall services
  Map<String, dynamic>? _attendanceSummary;
  CanteenStore? _canteenStore;
  GatepassStore? _gatepassStore;
  List<LibraryVisitPass> _libraryBookings = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadOverallServicesData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOverallServicesData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final token = widget.session.jwtToken;
    final claims = widget.session.parseJwtClaims();
    final studentId = claims['sub']?.toString() ?? 'me';

    try {
      // 1. Attendance service summary
      Map<String, dynamic>? attendance;
      try {
        final attendanceRepo = AttendanceRepository(
          baseUrl: _backendBaseUrl,
          accessToken: token,
        );
        attendance = await attendanceRepo.summary(
          studentId.isNotEmpty ? studentId : 'me',
        );
      } catch (e) {
        debugPrint('Attendance summary load notice: $e');
      }

      // 2. Canteen & wallet service
      CanteenStore? canteenStore;
      try {
        final canteenRepo = BackendCanteenRepository(
          baseUrl: _backendBaseUrl,
          accessToken: token,
        );
        canteenStore = await canteenRepo.loadStore();
      } catch (e) {
        debugPrint('Canteen store load notice: $e');
      }

      // 3. Gatepass / outpass service
      GatepassStore? gatepassStore;
      try {
        final gatepassRepo = BackendGatepassRepository(
          baseUrl: _backendBaseUrl,
          accessToken: token,
          studentName: widget.session.displayName,
          email: widget.session.email,
          rollNumber: widget.session.idNumber ?? '',
          department: widget.session.departmentOrWard ?? '',
          positionProvider: () async => throw Exception(
            'Analytics overview does not need GPS',
          ),
        );
        gatepassStore = await gatepassRepo.loadStore();
      } catch (e) {
        debugPrint('Gatepass store load notice: $e');
      }

      // 4. Library service
      List<LibraryVisitPass> libraryBookings = [];
      try {
        final libraryRepo = BackendLibraryRepository(
          baseUrl: _backendBaseUrl,
          accessTokenProvider: ({bool forceRefresh = false}) async =>
              token ?? '',
        );
        libraryBookings = await libraryRepo.loadBookings();
      } catch (e) {
        debugPrint('Library bookings load notice: $e');
      }

      if (mounted) {
        setState(() {
          _attendanceSummary = attendance;
          _canteenStore = canteenStore;
          _gatepassStore = gatepassStore;
          _libraryBookings = libraryBookings;
          _isLoading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to load services analytics: $err';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return const Center(child: ThinkingOrbLoading(size: 80));
    }

    if (_errorMessage != null &&
        _attendanceSummary == null &&
        _canteenStore == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadOverallServicesData,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth <= 750;

        return RefreshIndicator(
          onRefresh: _loadOverallServicesData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(isMobile ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(isMobile, isDark),
                const SizedBox(height: 16),
                _buildOverallServicesKpis(isMobile, isDark),
                const SizedBox(height: 20),
                _buildServiceNavigationTabs(isMobile, isDark),
                const SizedBox(height: 16),
                _buildTabContent(isMobile, isDark),
                const SizedBox(height: 20),
                _buildExportReportsCard(context, isDark),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCard(bool isMobile, bool isDark) {
    final session = widget.session;
    final name = widget.isParent
        ? '${session.displayName} (Ward)'
        : session.displayName;
    final rollNo = session.idNumber ?? 'Student';
    final dept = session.departmentOrWard;
    final sec = session.sectionId;

    final subtitleParts = <String>[
      'Roll: $rollNo',
      if (dept != null && dept.isNotEmpty) dept,
      if (sec != null && sec.isNotEmpty) 'Section $sec',
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222226) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C30) : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              _initialsOf(name),
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'Live Portal Services',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitleParts.join(' • '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Refresh live data',
            onPressed: _loadOverallServicesData,
            icon: const Icon(Icons.refresh_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallServicesKpis(bool isMobile, bool isDark) {
    // 1. Attendance calculation
    final att = _attendanceSummary;
    final attTotal = (att?['totalClasses'] as num?)?.toInt() ?? 0;
    final attAttended = (att?['attendedClasses'] as num?)?.toInt() ?? 0;
    final attPct = (att?['percentage'] as num?)?.toDouble() ??
        (attTotal > 0 ? (attAttended / attTotal * 100) : 0.0);

    // 2. Canteen calculation
    final walletBal = _walletBalance(_canteenStore);
    final totalOrders = _canteenStore?.orders.length ?? 0;
    final totalSpent = _canteenStore?.orders.fold<double>(
          0.0,
          (sum, o) => sum + o.total,
        ) ??
        0.0;

    // 3. Gatepass calculation
    final passes = _gatepassStore?.requests ?? [];
    final approvedPasses =
        passes.where((r) => r.status == ApprovalStatus.approved).length;

    // 4. Library calculation
    final libraryBookingsCount = _libraryBookings.length;

    final kpis = [
      {
        'title': 'Attendance Rate',
        'value': attTotal > 0 ? '${attPct.toStringAsFixed(1)}%' : 'N/A',
        'sub': attTotal > 0 ? '$attAttended of $attTotal classes' : 'No sessions held',
        'icon': Icons.fact_check_rounded,
        'color': attPct >= 75 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
        'moduleId': ModuleCatalog.attendance,
      },
      {
        'title': 'Canteen Balance',
        'value': '₹${walletBal.toStringAsFixed(2)}',
        'sub': '$totalOrders orders · ₹${totalSpent.toStringAsFixed(0)} spent',
        'icon': Icons.account_balance_wallet_rounded,
        'color': const Color(0xFF6366F1),
        'moduleId': ModuleCatalog.canteen,
      },
      {
        'title': 'Campus Gatepasses',
        'value': '${passes.length} Passes',
        'sub': '$approvedPasses approved & active',
        'icon': Icons.badge_rounded,
        'color': const Color(0xFF0EA5E9),
        'moduleId': ModuleCatalog.gatepass,
      },
      {
        'title': 'Library Bookings',
        'value': '$libraryBookingsCount Bookings',
        'sub': 'Reading hall reservations',
        'icon': Icons.local_library_rounded,
        'color': const Color(0xFF8B5CF6),
        'moduleId': ModuleCatalog.library,
      },
    ];

    if (isMobile) {
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.35,
        children: kpis.map((k) => _buildKpiCard(k, isDark)).toList(),
      );
    }

    return Row(
      children: kpis
          .map(
            (k) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildKpiCard(k, isDark),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildKpiCard(Map<String, dynamic> item, bool isDark) {
    final color = item['color'] as Color;
    final moduleId = item['moduleId'] as String?;

    return Material(
      color: isDark ? const Color(0xFF222226) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: moduleId != null && widget.onOpenModule != null
            ? () => widget.onOpenModule!(moduleId)
            : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2C2C30) : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item['icon'] as IconData, color: color, size: 18),
                  ),
                  if (widget.onOpenModule != null)
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 11,
                      color: isDark ? Colors.white38 : AppColors.muted,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] as String,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['value'] as String,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['sub'] as String,
                    style: const TextStyle(fontSize: 10, color: AppColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceNavigationTabs(bool isMobile, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1F2F6),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: TabBar(
        controller: _tabController,
        isScrollable: isMobile,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C32) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.0 : 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        labelColor: isDark ? Colors.white : AppColors.ink,
        unselectedLabelColor: AppColors.muted,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Attendance'),
          Tab(text: 'Canteen & Wallet'),
          Tab(text: 'Gatepasses'),
          Tab(text: 'Library Activity'),
        ],
      ),
    );
  }

  Widget _buildTabContent(bool isMobile, bool isDark) {
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        switch (_tabController.index) {
          case 0:
            return _buildAttendanceServiceSection(isMobile, isDark);
          case 1:
            return _buildCanteenServiceSection(isMobile, isDark);
          case 2:
            return _buildGatepassServiceSection(isMobile, isDark);
          case 3:
            return _buildLibraryServiceSection(isMobile, isDark);
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  // -------------------------------------------------------------
  // ATTENDANCE TAB
  // -------------------------------------------------------------
  Widget _buildAttendanceServiceSection(bool isMobile, bool isDark) {
    final att = _attendanceSummary;
    final total = (att?['totalClasses'] as num?)?.toInt() ?? 0;
    final attended = (att?['attendedClasses'] as num?)?.toInt() ?? 0;
    final present = (att?['presentClasses'] as num?)?.toInt() ?? 0;
    final absences = (att?['absences'] as num?)?.toInt() ?? 0;
    final onDuty = (att?['onDutyClasses'] as num?)?.toInt() ?? 0;
    final pct = (att?['percentage'] as num?)?.toDouble() ??
        (total > 0 ? (attended / total * 100) : 0.0);

    final bySubject = (att?['bySubject'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final records = (att?['records'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Attendance Overview Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF222226) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2C2C30) : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Overall Attendance Status',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (pct >= 75 ? Colors.green : Colors.orange)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      pct >= 75 ? 'Eligible for Exams' : 'Attendance Shortage Alert',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: pct >= 75 ? Colors.green.shade700 : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: total > 0 ? (pct / 100).clamp(0.0, 1.0) : 0,
                  minHeight: 10,
                  backgroundColor: isDark
                      ? const Color(0xFF333338)
                      : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    pct >= 75 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statItem('Total Classes', '$total', isDark),
                  _statItem('Present', '$present', isDark, color: Colors.green),
                  _statItem('Absent', '$absences', isDark, color: Colors.red),
                  _statItem('On Duty (OD)', '$onDuty', isDark, color: Colors.blue),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Subject Breakdown
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF222226) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2C2C30) : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Subject-wise Attendance',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Calculated from officially submitted attendance sessions',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              const SizedBox(height: 14),
              if (bySubject.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No subject attendance recorded yet',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : AppColors.muted,
                      ),
                    ),
                  ),
                )
              else
                ...bySubject.map((sub) {
                  final sTotal = (sub['totalClasses'] as num?)?.toInt() ?? 0;
                  final sAttended =
                      (sub['attendedClasses'] as num?)?.toInt() ?? 0;
                  final sPct = sTotal > 0 ? (sAttended / sTotal * 100) : 0.0;
                  final code = sub['subjectCode']?.toString() ?? '';
                  final name = sub['subjectName']?.toString() ?? 'Subject';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '$name ($code)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '$sAttended/$sTotal (${sPct.toStringAsFixed(0)}%)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: sPct >= 75
                                    ? Colors.green.shade600
                                    : Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: sTotal > 0 ? (sPct / 100).clamp(0.0, 1.0) : 0,
                            minHeight: 6,
                            backgroundColor: isDark
                                ? const Color(0xFF333338)
                                : Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              sPct >= 75
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Recent Attendance Sessions
        if (records.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF222226) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF2C2C30) : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Class Entries',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                for (final rec in records.take(6)) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _attendanceStatusColor(rec['status']),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rec['subjectName']?.toString() ?? 'Class',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${rec['heldOn']} · ${rec['periodLabel'] ?? 'Regular'} · ${rec['facultyName'] ?? 'Faculty'}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _attendanceStatusColor(rec['status'])
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            (rec['status']?.toString() ?? 'present').toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _attendanceStatusColor(rec['status']),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------
  // CANTEEN & WALLET TAB
  // -------------------------------------------------------------
  Widget _buildCanteenServiceSection(bool isMobile, bool isDark) {
    final store = _canteenStore;
    final orders = store?.orders ?? [];
    final walletBal = _walletBalance(store);
    final txs = store?.walletTransactions ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Balance Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Campus Dining Wallet',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '₹${walletBal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Active orders: ${orders.where((o) => o.status.isActive).length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
              if (widget.onOpenModule != null)
                ElevatedButton.icon(
                  onPressed: () => widget.onOpenModule!(ModuleCatalog.canteen),
                  icon: const Icon(Icons.restaurant_rounded, size: 16),
                  label: const Text('Go to Canteen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4F46E5),
                    elevation: 0,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Recent Orders List
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF222226) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2C2C30) : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent Canteen Orders',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              if (orders.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No orders placed yet',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ),
                )
              else
                for (final order in orders.take(5)) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #${order.displayId}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${order.lines.fold(0, (sum, l) => sum + l.quantity)} items · ${_formatDate(order.createdAt)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${order.total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _orderStatusColor(order.status)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                order.status.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _orderStatusColor(order.status),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Recent Wallet Transactions
        if (txs.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF222226) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF2C2C30) : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Recent Wallet Activity',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                for (final tx in txs.take(5)) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              tx.amount >= 0
                                  ? Icons.add_circle_outline_rounded
                                  : Icons.remove_circle_outline_rounded,
                              size: 16,
                              color: tx.amount >= 0 ? Colors.green : Colors.red,
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx.description.isNotEmpty
                                      ? tx.description
                                      : (tx.amount >= 0 ? 'Top up' : 'Order payment'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _formatDate(tx.createdAt),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          '${tx.amount >= 0 ? '+' : ''}₹${tx.amount.abs().toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: tx.amount >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // -------------------------------------------------------------
  // GATEPASS TAB
  // -------------------------------------------------------------
  Widget _buildGatepassServiceSection(bool isMobile, bool isDark) {
    final passes = _gatepassStore?.requests ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF222226) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2C2C30) : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Campus Outpass / Leave Passes',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  if (widget.onOpenModule != null)
                    TextButton.icon(
                      onPressed: () =>
                          widget.onOpenModule!(ModuleCatalog.gatepass),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Apply Pass'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (passes.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No gatepasses generated yet for this student',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ),
                )
              else
                for (final pass in passes.take(6)) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _passStatusColor(pass.status)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.directions_walk_rounded,
                            size: 18,
                            color: _passStatusColor(pass.status),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pass.destination,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Reason: ${pass.reason} · ${_formatDate(pass.departureAt)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: _passStatusColor(pass.status)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            pass.status.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _passStatusColor(pass.status),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // LIBRARY TAB
  // -------------------------------------------------------------
  Widget _buildLibraryServiceSection(bool isMobile, bool isDark) {
    final bookings = _libraryBookings;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF222226) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2C2C30) : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Library Reading Room & Study Hall',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  if (widget.onOpenModule != null)
                    TextButton.icon(
                      onPressed: () =>
                          widget.onOpenModule!(ModuleCatalog.library),
                      icon: const Icon(Icons.bookmark_add_rounded, size: 16),
                      label: const Text('Reserve Slot'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (bookings.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No reading hall reservations or slot bookings yet',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ),
                )
              else
                for (final b in bookings.take(6)) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.chair_alt_rounded,
                            size: 18,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.zoneName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${_formatDate(b.start)} · ${b.durationMinutes} mins (${_formatTime(b.start)} - ${_formatTime(b.end)})',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            b.status.name.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.deepPurple,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                ],
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // REPORT EXPORT CARD
  // -------------------------------------------------------------
  Widget _buildExportReportsCard(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222226) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C30) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Export Services Reports',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Export official student portal activity reports for records and offline review.',
            style: TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.fact_check_outlined, color: AppColors.primary),
            title: const Text('Attendance Summary Report', style: TextStyle(fontSize: 13)),
            subtitle: const Text('All class attendance logs and subject totals', style: TextStyle(fontSize: 11, color: AppColors.muted)),
            trailing: FilledButton.tonalIcon(
              onPressed: () => _exportAttendanceCsv(context),
              icon: const Icon(Icons.download_rounded, size: 14),
              label: const Text('CSV', style: TextStyle(fontSize: 11)),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.analytics_outlined, color: Colors.indigo),
            title: const Text('Overall Services Activity Statement', style: TextStyle(fontSize: 13)),
            subtitle: const Text('Consolidated statement across attendance, canteen, and passes', style: TextStyle(fontSize: 11, color: AppColors.muted)),
            trailing: FilledButton.tonalIcon(
              onPressed: () => _exportOverallServicesSummary(context),
              icon: const Icon(Icons.download_rounded, size: 14),
              label: const Text('CSV', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportAttendanceCsv(BuildContext context) async {
    final records = (_attendanceSummary?['records'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    final rows = <List<String>>[
      ['Subject', 'Subject Code', 'Date', 'Period', 'Faculty', 'Status'],
      for (final r in records)
        [
          r['subjectName']?.toString() ?? '',
          r['subjectCode']?.toString() ?? '',
          r['heldOn']?.toString() ?? '',
          r['periodLabel']?.toString() ?? '',
          r['facultyName']?.toString() ?? '',
          r['status']?.toString() ?? '',
        ],
    ];

    if (records.isEmpty) {
      rows.add(['No attendance records found', '', '', '', '', '']);
    }

    final csv = rows
        .map((row) => row.map((v) => '"${v.replaceAll('"', '""')}"').join(','))
        .join('\r\n');
    final bytes = Uint8List.fromList(utf8.encode(csv));

    try {
      await FilePicker.saveFile(
        dialogTitle: 'Save Attendance Report',
        fileName: 'SuperCampus_Attendance_${widget.session.idNumber ?? 'Student'}.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: bytes,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance report exported successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download notice: $e')),
        );
      }
    }
  }

  Future<void> _exportOverallServicesSummary(BuildContext context) async {
    final attTotal = (_attendanceSummary?['totalClasses'] as num?)?.toInt() ?? 0;
    final attAttended = (_attendanceSummary?['attendedClasses'] as num?)?.toInt() ?? 0;
    final attPct = (_attendanceSummary?['percentage'] as num?)?.toDouble() ?? 0.0;
    final walletBal = _walletBalance(_canteenStore);
    final totalOrders = _canteenStore?.orders.length ?? 0;
    final totalPasses = _gatepassStore?.requests.length ?? 0;
    final libraryBookings = _libraryBookings.length;

    final rows = <List<String>>[
      ['Service', 'Metric', 'Value'],
      ['Student', 'Name', widget.session.displayName],
      ['Student', 'Roll Number', widget.session.idNumber ?? 'N/A'],
      ['Student', 'Department', widget.session.departmentOrWard ?? 'N/A'],
      ['Attendance', 'Total Classes', '$attTotal'],
      ['Attendance', 'Attended Classes', '$attAttended'],
      ['Attendance', 'Attendance Percentage', '${attPct.toStringAsFixed(2)}%'],
      ['Campus Canteen', 'Wallet Balance', 'INR ${walletBal.toStringAsFixed(2)}'],
      ['Campus Canteen', 'Total Orders Placed', '$totalOrders'],
      ['Campus Gatepass', 'Total Passes Generated', '$totalPasses'],
      ['Library', 'Study Hall Bookings', '$libraryBookings'],
    ];

    final csv = rows
        .map((row) => row.map((v) => '"${v.replaceAll('"', '""')}"').join(','))
        .join('\r\n');
    final bytes = Uint8List.fromList(utf8.encode(csv));

    try {
      await FilePicker.saveFile(
        dialogTitle: 'Save Overall Services Summary',
        fileName: 'SuperCampus_Services_Summary_${widget.session.idNumber ?? 'Student'}.csv',
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        bytes: bytes,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Services summary exported successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download notice: $e')),
        );
      }
    }
  }

  Widget _statItem(String label, String value, bool isDark, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color ?? (isDark ? Colors.white : AppColors.ink),
          ),
        ),
      ],
    );
  }

  Color _attendanceStatusColor(dynamic status) {
    switch (status?.toString().toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'absent':
        return Colors.red;
      case 'od':
      case 'on_duty':
        return Colors.blue;
      case 'leave':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _orderStatusColor(CanteenOrderStatus status) {
    switch (status) {
      case CanteenOrderStatus.completed:
        return Colors.green;
      case CanteenOrderStatus.ready:
        return Colors.blue;
      case CanteenOrderStatus.preparing:
      case CanteenOrderStatus.accepted:
        return Colors.orange;
      case CanteenOrderStatus.pending:
        return Colors.amber.shade800;
      case CanteenOrderStatus.rejected:
      case CanteenOrderStatus.cancelled:
        return Colors.red;
    }
  }

  Color _passStatusColor(ApprovalStatus status) {
    switch (status) {
      case ApprovalStatus.approved:
        return Colors.green;
      case ApprovalStatus.completed:
        return Colors.blue;
      case ApprovalStatus.pending:
        return Colors.orange;
      case ApprovalStatus.rejected:
      case ApprovalStatus.cancelled:
        return Colors.red;
    }
  }

  static String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  double _walletBalance(CanteenStore? store) {
    if (store == null || store.walletBalances.isEmpty) return 0.0;
    return store.walletBalances.values.fold(0.0, (sum, b) => sum + b);
  }

  String _initialsOf(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
