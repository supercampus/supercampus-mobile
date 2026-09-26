import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/campus_nav_bar.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/timetable_repository.dart';
import '../data/timetable_models.dart';
import 'timetable_tones.dart';
import 'widgets/daily_period_strip.dart';
import 'widgets/month_calendar_dialog.dart';
import 'widgets/weekly_date_strip.dart';

class FacultyDashboardScreen extends StatefulWidget {
  const FacultyDashboardScreen({
    super.key,
    required this.session,
    required this.repository,
    this.initialSection = 0,
  });

  final UserSession session;
  final TimetableRepository repository;
  final int initialSection;

  @override
  State<FacultyDashboardScreen> createState() => _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState extends State<FacultyDashboardScreen>
    with SingleTickerProviderStateMixin {
  AppPalette get _p => context.palette;

  DateTime _selectedDate = DateTime.now();
  late int _bottomNavIndex; // 0: Schedule, 1: Substitutions Hub
  late TabController _subTabController;

  @override
  void initState() {
    super.initState();
    _bottomNavIndex = widget.initialSection.clamp(0, 1);
    _subTabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _subTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.timetableCanvas,
      // Sections of this page, at the top of it. The bottom of the screen
      // belongs to the one nav bar the module host floats there.
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.calendar_today_outlined),
                    label: Text('My schedule'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.swap_horiz_outlined),
                    label: Text('Substitutions'),
                  ),
                ],
                selected: {_bottomNavIndex},
                showSelectedIcon: false,
                onSelectionChanged: (value) =>
                    setState(() => _bottomNavIndex = value.first),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom:
                    CampusNavBar.heightFor(context) +
                    MediaQuery.paddingOf(context).bottom,
              ),
              child: _bottomNavIndex == 0
                  ? _buildScheduleView(context)
                  : _buildSubstitutionsHub(context),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom:
              CampusNavBar.heightFor(context) +
              MediaQuery.paddingOf(context).bottom,
        ),
        child: FloatingActionButton(
          shape: const CircleBorder(),
          backgroundColor: _p.brand,
          onPressed: () => _showRequestSubstitutionModal(context),
          tooltip: 'Request Substitution',
          child: const Icon(Icons.swap_calls, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. MINIMAL DAILY SCHEDULE VIEW (FACULTY)
  // ===========================================================================
  Widget _buildScheduleView(BuildContext context) {
    final config = widget.repository.getConfig();
    final selectedDayStr = DateFormat('EEEE').format(_selectedDate);

    // Get faculty schedule entries for today
    final facultyName = widget.session.displayName;
    final facultyUserId =
        widget.session.parseJwtClaims()['sub']?.toString() ??
        widget.session.staffId;
    final allFacultyEntries = widget.repository.getEntriesForFaculty(
      facultyName,
      facultyId: facultyUserId,
    );
    final dayEntries = allFacultyEntries
        .where((e) => e.dayOfWeek.toLowerCase() == selectedDayStr.toLowerCase())
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Faculty Workload Schedule',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${widget.session.displayName} • Operational View',
                  style: TextStyle(fontSize: 12, color: _p.inkSecondary),
                ),
              ],
            ),
            IconButton.filledTonal(
              onPressed: () async {
                final date = await showDialog<DateTime>(
                  context: context,
                  builder: (ctx) =>
                      MonthCalendarDialog(selectedDate: _selectedDate),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                }
              },
              icon: const Icon(Icons.calendar_month_outlined),
            ),
          ],
        ),
        const SizedBox(height: 12),
        WeeklyDateStrip(
          selectedDate: _selectedDate,
          onDateSelected: (date) => setState(() => _selectedDate = date),
        ),
        const SizedBox(height: 20),

        DailyPeriodStrip(
          periodsPerDay: config.periodsPerDay,
          entries: dayEntries,
          audience: TimetableAudience.staff,
        ),
      ],
    );
  }

  Widget _buildFacultyPeriodCard({
    required BuildContext context,
    required int periodIndex,
    required String timeSlot,
    TimetableEntry? entry,
    FacultySubstitution? subOut,
    FacultySubstitution? subIn,
  }) {
    final isFree = entry == null && subIn == null;
    final isSubstitutedOut = subOut != null;
    final isSubstitutedIn = subIn != null;

    if (isFree) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        color: context.grey(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: context.grey(300), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: context.grey(200),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Period $periodIndex • $timeSlot',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.grey(700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No Class Assigned',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: context.grey(600),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: context.grey(200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Free Period',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.grey(500),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final targetClass = isSubstitutedIn
        ? subIn.className
        : (entry?.className ?? 'CS-3A');
    final subjectName = isSubstitutedIn
        ? '${subIn.subjectCode} - ${subIn.subjectName}'
        : '${entry?.subjectCode} - ${entry?.subjectName}';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: isSubstitutedIn
          ? context.adaptive(
              light: Colors.amber.shade50.withValues(alpha: 0.3),
              dark: const Color(0x14FFC107),
            )
          : _p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSubstitutedOut
              ? Colors.amber.shade400
              : isSubstitutedIn
              ? Colors.amber.shade600
              : _p.brandInk.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: BorderSide(
              color: isSubstitutedOut
                  ? Colors.amber.shade700
                  : isSubstitutedIn
                  ? Colors.amber.shade800
                  : _p.brandInk,
              width: 5,
            ),
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _p.brandInk.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Period $periodIndex • $timeSlot',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _p.brandInk,
                          ),
                        ),
                      ),
                      if (isSubstitutedOut)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: subOut.status == 'Approved'
                                ? Colors.amber.shade100.tintOn(context)
                                : Colors.blue.shade50.tintOn(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: subOut.status == 'Approved'
                                  ? Colors.amber.shade400
                                  : Colors.blue.shade300.tintOn(
                                      context,
                                      alpha: .45,
                                    ),
                            ),
                          ),
                          child: Text(
                            subOut.status == 'Approved'
                                ? 'Substituted'
                                : 'Request Pending',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: subOut.status == 'Approved'
                                  ? Colors.amber.shade900.inkOn(context)
                                  : Colors.blue.shade800.inkOn(context),
                            ),
                          ),
                        )
                      else if (isSubstitutedIn)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100.tintOn(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.shade600),
                          ),
                          child: Text(
                            'Assigned Proxy',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900.inkOn(context),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50.tintOn(context),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green.shade200.tintOn(
                                context,
                                alpha: .45,
                              ),
                            ),
                          ),
                          child: Text(
                            'Scheduled',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.green.inkOn(context),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // PRIMARY TITLE FOCUS: CLASS / SECTION
                  Text(
                    'Class $targetClass',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _p.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Padding(
                    padding: const EdgeInsets.only(right: 36),
                    child: Text(
                      subjectName,
                      style: TextStyle(
                        fontSize: 13,
                        color: _p.inkSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Substitution Badging in Faculty Schedule
                  if (isSubstitutedOut)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50.tintOn(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.shade200.tintOn(
                            context,
                            alpha: .45,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.swap_horiz,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              children: [
                                Text(
                                  widget.session.displayName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.inkOn(context),
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_right_alt,
                                  size: 14,
                                  color: _p.inkSecondary,
                                ),
                                Text(
                                  subOut.substituteFaculty,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900.inkOn(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (isSubstitutedIn)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50.tintOn(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.shade300.tintOn(
                            context,
                            alpha: .45,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shield_outlined,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 4,
                              children: [
                                Text(
                                  subIn.originalFaculty,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.red.inkOn(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_right_alt,
                                  size: 14,
                                  color: _p.inkSecondary,
                                ),
                                Text(
                                  '${widget.session.displayName} (Proxy)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade900.inkOn(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Circular action button in bottom right corner
            if (!isSubstitutedOut && entry != null)
              Positioned(
                bottom: 12,
                right: 12,
                child: Tooltip(
                  message: 'Request Substitution',
                  child: Material(
                    color: _p.brandInk.withValues(alpha: 0.12),
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _showRequestSubstitutionModal(
                        context,
                        entry: entry,
                        timeSlot: timeSlot,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.swap_calls,
                          size: 20,
                          color: _p.brandInk,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. DEDICATED FACULTY 'SUBSTITUTIONS' HUB PAGE
  // ===========================================================================
  Widget _buildSubstitutionsHub(BuildContext context) {
    return Column(
      children: [
        Container(
          color: _p.surface,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Faculty Substitutions Hub',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Manage coverage requests, peer invites, and active proxies.',
                    style: TextStyle(fontSize: 12, color: _p.inkSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _subTabController,
                labelColor: _p.brandInk,
                unselectedLabelColor: _p.inkSecondary,
                indicatorColor: _p.brandInk,
                tabs: const [
                  Tab(text: 'My Requests'),
                  Tab(text: 'Incoming Invites'),
                  Tab(text: 'Active Proxies'),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabController,
            children: [
              _buildTabMyRequests(),
              _buildTabIncomingInvites(),
              _buildTabActiveProxies(),
            ],
          ),
        ),
      ],
    );
  }

  // Tab 1: My Requests (Live feed of outgoing requests created by user)
  Widget _buildTabMyRequests() {
    final subs = widget.repository
        .getSubstitutions()
        .where(
          (s) =>
              s.originalFaculty.toLowerCase() ==
              widget.session.displayName.toLowerCase(),
        )
        .toList();

    if (subs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.outbox_outlined, size: 48, color: context.grey(400)),
            const SizedBox(height: 12),
            Text(
              'No outgoing substitution requests.',
              style: TextStyle(color: _p.inkSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: subs.length,
      itemBuilder: (ctx, i) {
        final item = subs[i];
        final isApproved = item.status == 'Approved';
        final isRejected = item.status == 'Rejected';
        final isCancelled = item.status == 'Cancelled';
        final isPending = item.status == 'Pending';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${item.className} • ${item.subjectName}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isApproved
                            ? Colors.green.shade50.tintOn(context)
                            : isRejected
                            ? Colors.red.shade50.tintOn(context)
                            : isCancelled
                            ? context.grey(200)
                            : Colors.amber.shade50.tintOn(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isApproved
                              ? Colors.green.shade300.tintOn(
                                  context,
                                  alpha: .45,
                                )
                              : isRejected
                              ? Colors.red.shade300.tintOn(context, alpha: .45)
                              : isCancelled
                              ? context.grey(400)
                              : Colors.amber.shade300.tintOn(
                                  context,
                                  alpha: .45,
                                ),
                        ),
                      ),
                      child: Text(
                        isPending ? 'Pending Peer Response' : item.status,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isApproved
                              ? Colors.green.shade800.inkOn(context)
                              : isRejected
                              ? Colors.red.shade800.inkOn(context)
                              : isCancelled
                              ? context.grey(700)
                              : Colors.amber.shade900.inkOn(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            item.triggerType ==
                                SubstitutionTriggerType.facultyInitiated
                            ? Colors.purple.shade50.tintOn(context)
                            : Colors.orange.shade50.tintOn(context),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color:
                              item.triggerType ==
                                  SubstitutionTriggerType.facultyInitiated
                              ? Colors.purple.shade200.tintOn(
                                  context,
                                  alpha: .45,
                                )
                              : Colors.orange.shade200.tintOn(
                                  context,
                                  alpha: .45,
                                ),
                        ),
                      ),
                      child: Text(
                        item.triggerType.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color:
                              item.triggerType ==
                                  SubstitutionTriggerType.facultyInitiated
                              ? Colors.purple.shade800.inkOn(context)
                              : Colors.orange.shade900.inkOn(context),
                        ),
                      ),
                    ),
                    if (item.isPoolBroadcast) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50.tintOn(context),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.blue.shade200.tintOn(
                              context,
                              alpha: .45,
                            ),
                          ),
                        ),
                        child: Text(
                          'Pool Broadcast',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.inkOn(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Slot: ${item.dayOfWeek}, ${item.timeSlot}',
                  style: const TextStyle(fontSize: 12),
                ),
                Text(
                  'Proxy Assignee: ${item.substituteFaculty}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade900.inkOn(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.reason.isNotEmpty)
                  Text(
                    'Reason: ${item.reason}',
                    style: TextStyle(fontSize: 11, color: _p.inkSecondary),
                  ),
                if (item.note.isNotEmpty)
                  Text(
                    'Note: "${item.note}"',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: context.grey(500),
                    ),
                  ),

                // Cancel Request Action Button
                if (isPending) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        setState(
                          () => widget.repository.cancelSubstitution(item.id),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Substitution request cancelled.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.cancel_outlined, size: 14),
                      label: const Text(
                        'Cancel Request',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // Tab 2: Incoming Invites (Cards showing incoming substitution requests with Accept / Decline action buttons)
  Widget _buildTabIncomingInvites() {
    final myName = widget.session.displayName.toLowerCase();
    final invites = widget.repository
        .getSubstitutions()
        .where(
          (s) =>
              (s.substituteFaculty.toLowerCase() == myName ||
                  (s.isPoolBroadcast &&
                      s.originalFaculty.toLowerCase() != myName)) &&
              s.status == 'Pending',
        )
        .toList();

    if (invites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: context.grey(400)),
            const SizedBox(height: 12),
            Text(
              'No incoming substitution invites.',
              style: TextStyle(color: _p.inkSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invites.length,
      itemBuilder: (ctx, i) {
        final item = invites[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Class ${item.className}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100.tintOn(context),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.isPoolBroadcast ? 'Pool Invite' : 'Direct Invite',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900.inkOn(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            item.triggerType ==
                                SubstitutionTriggerType.facultyInitiated
                            ? Colors.purple.shade50.tintOn(context)
                            : Colors.orange.shade50.tintOn(context),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color:
                              item.triggerType ==
                                  SubstitutionTriggerType.facultyInitiated
                              ? Colors.purple.shade200.tintOn(
                                  context,
                                  alpha: .45,
                                )
                              : Colors.orange.shade200.tintOn(
                                  context,
                                  alpha: .45,
                                ),
                        ),
                      ),
                      child: Text(
                        item.triggerType.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color:
                              item.triggerType ==
                                  SubstitutionTriggerType.facultyInitiated
                              ? Colors.purple.shade800.inkOn(context)
                              : Colors.orange.shade900.inkOn(context),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Original Faculty: ${item.originalFaculty}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.red.inkOn(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${item.subjectCode} - ${item.subjectName}',
                  style: TextStyle(fontSize: 13, color: _p.inkSecondary),
                ),
                Text(
                  '${item.dayOfWeek} • ${item.timeSlot}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.reason.isNotEmpty)
                  Text(
                    'Metadata: ${item.reason}',
                    style: TextStyle(fontSize: 11, color: _p.inkSecondary),
                  ),
                if (item.note.isNotEmpty)
                  Text(
                    'Note: "${item.note}"',
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: context.grey(500),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () {
                        setState(
                          () => widget.repository.rejectSubstitution(item.id),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Substitution invite declined.'),
                          ),
                        );
                      },
                      child: const Text('Decline'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _p.brand,
                        foregroundColor: _p.onBrand,
                      ),
                      onPressed: () {
                        setState(() {
                          // Assign user as proxy if it was a pool broadcast
                          if (item.isPoolBroadcast) {
                            widget.repository.approveSubstitution(item.id);
                          } else {
                            widget.repository.approveSubstitution(item.id);
                          }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Substitution invite accepted! You are assigned as proxy.',
                            ),
                          ),
                        );
                      },
                      child: const Text('Accept'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Tab 3: Active Proxies (Summary view of all confirmed proxy duties for the week)
  Widget _buildTabActiveProxies() {
    final activeProxies = widget.repository
        .getSubstitutions()
        .where(
          (s) =>
              (s.substituteFaculty.toLowerCase() ==
                      widget.session.displayName.toLowerCase() ||
                  s.originalFaculty.toLowerCase() ==
                      widget.session.displayName.toLowerCase()) &&
              s.status == 'Approved',
        )
        .toList();

    if (activeProxies.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 48, color: context.grey(400)),
            const SizedBox(height: 12),
            Text(
              'No active proxy duties for this week.',
              style: TextStyle(color: _p.inkSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activeProxies.length,
      itemBuilder: (ctx, i) {
        final item = activeProxies[i];
        final isProxyDuty =
            item.substituteFaculty.toLowerCase() ==
            widget.session.displayName.toLowerCase();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(14),
            leading: CircleAvatar(
              backgroundColor: isProxyDuty
                  ? Colors.amber.shade100.tintOn(context)
                  : Colors.red.shade50.tintOn(context),
              child: Icon(
                isProxyDuty ? Icons.shield : Icons.swap_horiz,
                color: isProxyDuty
                    ? Colors.amber.shade900.inkOn(context)
                    : Colors.red.inkOn(context),
              ),
            ),
            title: Text(
              isProxyDuty
                  ? 'Proxy Duty: Class ${item.className}'
                  : 'Surrendered Class: ${item.className}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${item.subjectName}\n${item.dayOfWeek} • ${item.timeSlot}\n${isProxyDuty ? "Covering for: ${item.originalFaculty}" : "Covered by: ${item.substituteFaculty}"}',
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple.shade50.tintOn(context),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.triggerType.label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade800.inkOn(context),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Request Sheet / Modal Flow
  void _showRequestSubstitutionModal(
    BuildContext context, {
    TimetableEntry? entry,
    String? timeSlot,
  }) {
    DateTime modalSelectedDate = _selectedDate;
    String selectedCategory = 'Syllabus Coverage / Extra Class';
    String selectedFaculty = 'Prof. Donald Knuth';
    bool isPoolBroadcast = false;
    String selectedSlot = timeSlot ?? '08:30 - 09:20 AM';
    String selectedClass = entry?.className ?? 'CS-3A';
    String selectedSubject = entry != null
        ? '${entry.subjectCode} - ${entry.subjectName}'
        : 'CS301 - Database Systems';
    final noteController = TextEditingController();

    final categories = [
      'Syllabus Coverage / Extra Class',
      'Department Work',
      'Personal Emergency',
      'Unplanned Event',
    ];

    final availableFaculty = [
      'Prof. Donald Knuth',
      'Prof. Sarah Jenkins',
      'Prof. Grace Hopper',
      'Dr. Marcus Vance',
      'Prof. Barbara Liskov',
    ];

    final timeSlotsList = [
      '08:30 - 09:20 AM',
      '09:30 - 10:20 AM',
      '10:20 - 11:10 AM',
      '11:30 - 12:20 PM',
      '02:00 - 02:50 PM',
      '02:50 - 03:40 PM',
    ];

    final classesList = ['CS-3A', 'CS-3B', 'ECE-2A', 'ME-2B'];

    final subjectsList = [
      'CS301 - Database Systems',
      'CS302 - Operating Systems',
      'CS303 - Computer Networks',
      'CS304 - Software Engineering',
      'CS306 - AI & Machine Learning',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isFromCard = entry != null && timeSlot != null;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Request Substitution',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50.tintOn(context),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'FACULTY_INITIATED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.inkOn(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Period Picker (If opened from top CTA; pre-filled if from card)
                  if (!isFromCard) ...[
                    const Text(
                      'Target Date & Period Slot',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: modalSelectedDate,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 7),
                                ),
                                lastDate: DateTime.now().add(
                                  const Duration(days: 60),
                                ),
                              );
                              if (d != null)
                                setModalState(() => modalSelectedDate = d);
                            },
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              DateFormat(
                                'EEE, MMM d',
                              ).format(modalSelectedDate),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedSlot,
                            items: timeSlotsList
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s,
                                    child: Text(
                                      s,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setModalState(() => selectedSlot = val!),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Class / Section',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                initialValue: selectedClass,
                                items: classesList
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setModalState(() => selectedClass = val!),
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Subject Name',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              DropdownButtonFormField<String>(
                                initialValue: selectedSubject,
                                items: subjectsList
                                    .map(
                                      (sub) => DropdownMenuItem(
                                        value: sub,
                                        child: Text(
                                          sub,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setModalState(() => selectedSubject = val!),
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50.tintOn(context),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.inkOn(context),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pre-filled for Class ${entry.className} (${entry.subjectCode}) • ${DateFormat('EEEE').format(modalSelectedDate)}, $selectedSlot',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade900.inkOn(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Reason Categories
                  const Text(
                    'Reason Category',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (val) =>
                        setModalState(() => selectedCategory = val!),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Assignee Selection Mode (Direct Assignment vs Pool Broadcast)
                  const Text(
                    'Assignee Selection',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Direct Assignment'),
                        icon: Icon(Icons.person),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Pool Broadcast'),
                        icon: Icon(Icons.groups),
                      ),
                    ],
                    selected: {isPoolBroadcast},
                    onSelectionChanged: (val) =>
                        setModalState(() => isPoolBroadcast = val.first),
                  ),
                  const SizedBox(height: 10),

                  if (!isPoolBroadcast) ...[
                    Text(
                      'Select Target Peer Faculty',
                      style: TextStyle(fontSize: 12, color: _p.inkSecondary),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: selectedFaculty,
                      items: availableFaculty
                          .map(
                            (f) => DropdownMenuItem(value: f, child: Text(f)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setModalState(() => selectedFaculty = val!),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50.tintOn(context),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.shade300.tintOn(
                            context,
                            alpha: .45,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.campaign, color: Colors.amber, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Request will be broadcasted to all available department faculty for this slot.',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.adaptive(
                                  light: Colors.black87,
                                  dark: const Color(0xFFD9DAE0),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Note Field
                  const Text(
                    'Optional Note / Extra Context',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText:
                          'e.g., Covering Chapter 4 ahead of mid-term exams...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _p.brand,
                        foregroundColor: _p.onBrand,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        final parts = selectedSubject.split(' - ');
                        final subCode = parts.isNotEmpty ? parts[0] : 'CS301';
                        final subName = parts.length > 1
                            ? parts[1]
                            : selectedSubject;

                        final newSub = FacultySubstitution(
                          id: 'SUB-${DateTime.now().millisecondsSinceEpoch}',
                          date: modalSelectedDate,
                          originalFaculty: widget.session.displayName,
                          substituteFaculty: isPoolBroadcast
                              ? 'Pool Broadcast (Dept Faculty)'
                              : selectedFaculty,
                          className: selectedClass,
                          subjectCode: subCode,
                          subjectName: subName,
                          timeSlot: selectedSlot,
                          dayOfWeek: DateFormat(
                            'EEEE',
                          ).format(modalSelectedDate),
                          reason: selectedCategory,
                          status: 'Pending',
                          triggerType: SubstitutionTriggerType.facultyInitiated,
                          isPoolBroadcast: isPoolBroadcast,
                          note: noteController.text.trim(),
                        );

                        widget.repository.requestSubstitution(newSub);
                        Navigator.pop(ctx);
                        setState(() {});

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Substitution request sent! (${isPoolBroadcast ? "Broadcast to Pool" : "Notified $selectedFaculty"} & Allocator Alerted)',
                            ),
                            backgroundColor: _p.brand,
                          ),
                        );
                      },
                      child: const Text('Submit Request'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
