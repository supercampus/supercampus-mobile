import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';
import '../data/mock_timetable_repository.dart';
import '../data/timetable_models.dart';
import 'widgets/substitution_modal.dart';
import 'widgets/timetable_config_form.dart';

class AllocatorDashboardScreen extends StatefulWidget {
  const AllocatorDashboardScreen({
    super.key,
    required this.session,
    required this.repository,
  });

  final UserSession session;
  final MockTimetableRepository repository;

  @override
  State<AllocatorDashboardScreen> createState() =>
      _AllocatorDashboardScreenState();
}

class _AllocatorDashboardScreenState extends State<AllocatorDashboardScreen> {
  int _currentNavIndex = 0; // 0: Dashboard, 1: Master Timetable, 2: Substitutions, 3: Configuration
  String _selectedClass = 'CS-3A';
  final String _selectedDay = 'Monday';

  List<TimetableEntry>? _aiPreviewEntries;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: isDesktop
          ? Row(
              children: [
                _buildSidebar(context),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: _buildMainBody(context)),
              ],
            )
          : _buildMainBody(context),
      bottomNavigationBar: isDesktop ? null : _buildBottomNavBar(context),
    );
  }

  // Responsive Sidebar Navigation (Desktop / Tablet)
  Widget _buildSidebar(BuildContext context) {
    final disruptions = widget.repository.getDisruptionAlerts();
    final activeDisruptions = disruptions.where((d) => !d.isResolved).length;
    final subs = widget.repository.getSubstitutions();
    final pendingSubs = subs.where((s) => s.status == 'Pending').length;

    return Container(
      width: 240,
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00695C).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.table_chart,
                    color: Color(0xFF00695C),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Allocator Portal',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'SuperCampus Operations',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _sidebarTile(
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard,
                  label: 'Dashboard',
                  subtitle: 'Current Day Analysis',
                ),
                _sidebarTile(
                  index: 1,
                  icon: Icons.calendar_view_week_outlined,
                  activeIcon: Icons.calendar_view_week,
                  label: 'Master Timetable',
                  subtitle: 'Calendar Matrix View',
                ),
                _sidebarTile(
                  index: 2,
                  icon: Icons.swap_horiz_outlined,
                  activeIcon: Icons.swap_horiz,
                  label: 'Substitutions',
                  subtitle: 'Leave & Auto-Suggest',
                  badgeCount: activeDisruptions + pendingSubs,
                ),
                _sidebarTile(
                  index: 3,
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings,
                  label: 'Configuration',
                  subtitle: 'Settings & Resources',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sidebarTile({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String subtitle,
    int badgeCount = 0,
  }) {
    final isSelected = _currentNavIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF00695C).withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          isSelected ? activeIcon : icon,
          color: isSelected ? const Color(0xFF00695C) : AppColors.ink,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF00695C) : AppColors.ink,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
        trailing: badgeCount > 0
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: () => setState(() => _currentNavIndex = index),
      ),
    );
  }

  // Responsive Bottom Navigation Bar (Mobile)
  Widget _buildBottomNavBar(BuildContext context) {
    final disruptions = widget.repository.getDisruptionAlerts();
    final activeDisruptions = disruptions.where((d) => !d.isResolved).length;
    final subs = widget.repository.getSubstitutions();
    final pendingSubs = subs.where((s) => s.status == 'Pending').length;
    final totalBadge = activeDisruptions + pendingSubs;

    return BottomNavigationBar(
      currentIndex: _currentNavIndex,
      onTap: (idx) => setState(() => _currentNavIndex = idx),
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF00695C),
      unselectedItemColor: Colors.grey.shade600,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined),
          activeIcon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.calendar_view_week_outlined),
          activeIcon: Icon(Icons.calendar_view_week),
          label: 'Master Matrix',
        ),
        BottomNavigationBarItem(
          icon: Badge(
            isLabelVisible: totalBadge > 0,
            label: Text('$totalBadge'),
            child: const Icon(Icons.swap_horiz_outlined),
          ),
          activeIcon: Badge(
            isLabelVisible: totalBadge > 0,
            label: Text('$totalBadge'),
            child: const Icon(Icons.swap_horiz),
          ),
          label: 'Substitutions',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.settings_outlined),
          activeIcon: Icon(Icons.settings),
          label: 'Configure',
        ),
      ],
    );
  }

  // Main Body Container
  Widget _buildMainBody(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: switch (_currentNavIndex) {
            0 => _buildView1Dashboard(context),
            1 => _buildView2MasterTimetable(context),
            2 => _buildView3Substitutions(context),
            3 => _buildView4Configuration(context),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // VIEW 1: DASHBOARD (Current Day Analysis)
  // ===========================================================================
  Widget _buildView1Dashboard(BuildContext context) {
    final availableClasses = widget.repository.getAvailableClasses();
    final todayEntries = widget.repository
        .getEntriesForClass(_selectedClass)
        .where((e) => e.dayOfWeek == _selectedDay)
        .toList();
    todayEntries.sort((a, b) => a.periodIndex.compareTo(b.periodIndex));

    final disruptions = widget.repository
        .getDisruptionAlerts()
        .where((d) => d.className == _selectedClass && !d.isResolved)
        .toList();

    final approvedSubs = widget.repository
        .getSubstitutions()
        .where((s) => s.className == _selectedClass && s.status == 'Approved')
        .toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Class Selector & Current Day Header
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s Schedule Analysis',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Live operational monitoring for $_selectedDay',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Selected Class: ',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedClass,
                      items: availableClasses
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                c,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedClass = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Prominent Actionable Shortcut Banner (Disruption Alert)
        if (disruptions.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade700, Colors.deepOrange.shade800],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${disruptions.length} Disruption Alert(s) Detected!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Faculty absent for period(s): ${disruptions.map((d) => "P${d.periodIndex} (${d.absentFacultyName})").join(", ")}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.deepOrange.shade900,
                    ),
                    onPressed: () => setState(() => _currentNavIndex = 2),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text(
                      'Review & Approve Substitutions',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Metrics Row
        LayoutBuilder(
          builder: (context, constraints) {
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _dashboardStatCard(
                  title: 'Today\'s Total Periods',
                  value: '${todayEntries.length} Slots',
                  icon: Icons.calendar_today,
                  color: AppColors.primary,
                  width: constraints.maxWidth > 600
                      ? (constraints.maxWidth - 36) / 4
                      : (constraints.maxWidth - 12) / 2,
                ),
                _dashboardStatCard(
                  title: 'Active Disruptions',
                  value: '${disruptions.length} Periods',
                  icon: Icons.warning_amber_rounded,
                  color: disruptions.isNotEmpty ? Colors.red : Colors.green,
                  width: constraints.maxWidth > 600
                      ? (constraints.maxWidth - 36) / 4
                      : (constraints.maxWidth - 12) / 2,
                ),
                _dashboardStatCard(
                  title: 'Substitutions Active',
                  value: '${approvedSubs.length} Approved',
                  icon: Icons.swap_horiz,
                  color: Colors.amber.shade900,
                  width: constraints.maxWidth > 600
                      ? (constraints.maxWidth - 36) / 4
                      : (constraints.maxWidth - 12) / 2,
                ),
                _dashboardStatCard(
                  title: 'Schedule Health',
                  value: disruptions.isEmpty ? '100% Intact' : 'Needs Action',
                  icon: Icons.health_and_safety_outlined,
                  color: disruptions.isEmpty
                      ? const Color(0xFF2E7D32)
                      : Colors.orange,
                  width: constraints.maxWidth > 600
                      ? (constraints.maxWidth - 36) / 4
                      : (constraints.maxWidth - 12) / 2,
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 20),

        // Today's Live Schedule Timeline
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Live Day Plan for Class $_selectedClass',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Chip(
                      label: Text(_selectedDay),
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.1),
                      labelStyle: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (todayEntries.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    alignment: Alignment.center,
                    child: const Text(
                      'No classes scheduled for today.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                else
                  ...todayEntries.map((entry) {
                    final isCompromised = disruptions
                        .any((d) => d.periodIndex == entry.periodIndex);
                    final sub = approvedSubs.firstWhere(
                      (s) =>
                          s.timeSlot == entry.timeSlot &&
                          s.dayOfWeek == entry.dayOfWeek,
                      orElse: () => FacultySubstitution(
                        id: '',
                        date: DateTime.now(),
                        originalFaculty: '',
                        substituteFaculty: '',
                        className: '',
                        subjectCode: '',
                        subjectName: '',
                        timeSlot: '',
                        dayOfWeek: '',
                        reason: '',
                      ),
                    );

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isCompromised
                            ? Colors.red.shade50
                            : (sub.id.isNotEmpty
                                ? Colors.amber.shade50
                                : Colors.grey.shade50),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isCompromised
                              ? Colors.red.shade300
                              : (sub.id.isNotEmpty
                                  ? Colors.amber.shade300
                                  : Colors.grey.shade200),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: entry.categoryColor
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'P${entry.periodIndex} • ${entry.timeSlot}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: entry.categoryColor,
                                      ),
                                    ),
                                  ),
                                  if (entry.isLab)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.purple.shade50,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'LAB',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.purple.shade800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              if (isCompromised)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'FACULTY ABSENT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              else if (sub.id.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade900,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'SUBSTITUTED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${entry.subjectCode} - ${entry.subjectName}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  size: 16, color: AppColors.muted),
                              const SizedBox(width: 4),
                              Text(
                                sub.id.isNotEmpty
                                    ? 'Substitute: ${sub.substituteFaculty} (replacing ${entry.facultyName})'
                                    : 'Faculty: ${entry.facultyName}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: sub.id.isNotEmpty
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: sub.id.isNotEmpty
                                      ? const Color(0xFF00695C)
                                      : AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dashboardStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // VIEW 2: MASTER TIMETABLE (Calendar Matrix View)
  // ===========================================================================
  Widget _buildView2MasterTimetable(BuildContext context) {
    final availableClasses = widget.repository.getAvailableClasses();
    final config = widget.repository.getConfig();
    final entries = widget.repository.getEntriesForClass(_selectedClass);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Class Selection Bar & Generator Button
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Master Timetable Matrix',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  'Weekly calendar matrix for class scheduling (No Room fields)',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.purple.shade700,
                  ),
                  onPressed: () => _onGenerateTimetablePressed(context),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate Timetable'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00695C),
                  ),
                  onPressed: () => _showManualEntryDialog(context, null),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Period'),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Class Selection Chips Row
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text(
                  'Select Class Matrix: ',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: availableClasses.map((cls) {
                        final isSelected = cls == _selectedClass;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('Class $cls'),
                            selected: isSelected,
                            selectedColor: const Color(0xFF00695C),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.ink,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            onSelected: (_) =>
                                setState(() => _selectedClass = cls),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        if (_aiPreviewEntries != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.purple.shade300),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'AI Candidate Timetable Preview Ready',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () =>
                          setState(() => _aiPreviewEntries = null),
                      child: const Text('Discard'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                      ),
                      onPressed: () {
                        for (final e in _aiPreviewEntries!) {
                          widget.repository.addEntry(e);
                        }
                        setState(() => _aiPreviewEntries = null);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('AI Candidate applied to master grid!'),
                            backgroundColor: Color(0xFF2E7D32),
                          ),
                        );
                      },
                      child: const Text('Apply Candidate to Master Grid'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Calendar Matrix Grid Layout
        _buildMasterCalendarMatrix(context, entries, config),
      ],
    );
  }

  Widget _buildMasterCalendarMatrix(
    BuildContext context,
    List<TimetableEntry> entries,
    TimetableConfig config,
  ) {
    final days = config.workingDays;
    final slotInfos = _generateTimeSlots(config);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 16,
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF0F4F8)),
            columns: [
              const DataColumn(
                label: Text('Working Day',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ...slotInfos.map((slot) {
                return DataColumn(
                  label: Text(
                    slot.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: slot.isBreak
                          ? (slot.breakType == 'lunch'
                              ? Colors.deepOrange
                              : Colors.amber.shade900)
                          : Colors.black,
                    ),
                  ),
                );
              }),
            ],
            rows: days.map((day) {
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      day,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF00695C),
                      ),
                    ),
                  ),
                  ...slotInfos.map((slot) {
                    if (slot.isBreak) {
                      return DataCell(
                        Container(
                          width: 90,
                          height: 54,
                          color: slot.breakType == 'lunch'
                              ? Colors.orange.shade50
                              : Colors.amber.shade50,
                          alignment: Alignment.center,
                          child: Text(
                            slot.breakType == 'lunch' ? '🍱 LUNCH' : '☕ TEA BREAK',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: slot.breakType == 'lunch'
                                  ? Colors.deepOrange
                                  : Colors.amber.shade900,
                            ),
                          ),
                        ),
                      );
                    }

                    final periodNum = slot.periodIndex;
                    TimetableEntry? matching;
                    for (final e in entries) {
                      if (e.dayOfWeek == day && e.periodIndex == periodNum) {
                        matching = e;
                        break;
                      }
                    }

                    if (matching == null) {
                      return DataCell(
                        InkWell(
                          onTap: () => _showManualEntryDialog(
                            context,
                            null,
                            initialDay: day,
                            initialPeriod: periodNum,
                          ),
                          child: Container(
                            width: 120,
                            height: 54,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.grey.shade200,
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, size: 14, color: AppColors.muted),
                                SizedBox(width: 2),
                                Text(
                                  'Assign',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }

                    final entry = matching;
                    return DataCell(
                      InkWell(
                        onTap: () => _showManualEntryDialog(context, entry),
                        child: Container(
                          width: 120,
                          height: 54,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                          decoration: BoxDecoration(
                            color: entry.categoryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: entry.categoryColor.withValues(alpha: 0.4),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${entry.subjectCode}: ${entry.subjectName}',
                                  maxLines: 2,
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: entry.categoryColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Staff: ${entry.facultyName}',
                                  maxLines: 2,
                                  softWrap: true,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // VIEW 3: SUBSTITUTIONS VIEW
  // ===========================================================================
  Widget _buildView3Substitutions(BuildContext context) {
    final disruptions = widget.repository.getDisruptionAlerts();
    final substitutions = widget.repository.getSubstitutions();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Substitutions & Live Leave Tracker',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Text(
                  'Manage absent staff and auto-suggested replacements',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00695C),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => SubstitutionModal(
                    className: _selectedClass,
                    onRequestSubmitted: (sub) {
                      setState(() {
                        widget.repository.requestSubstitution(sub);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Custom substitution created!'),
                          backgroundColor: Color(0xFF00695C),
                        ),
                      );
                    },
                  ),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('Request Substitution'),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Live Disruption Alerts & Smart Auto-Suggestions Section
        const Text(
          'Live Disruption Alerts & Smart Auto-Suggestions',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        if (disruptions.where((d) => !d.isResolved).isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
                SizedBox(width: 10),
                Text(
                  'No active faculty leave disruptions pending review.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          )
        else
          ...disruptions.where((d) => !d.isResolved).map((disruption) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.orange.shade400, width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.person_off_outlined,
                              color: Colors.orange.shade900),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${disruption.absentFacultyName} on Leave',
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Affected Class: ${disruption.className} • ${disruption.subjectName} (${disruption.subjectCode}) at ${disruption.timeSlot}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Smart Qualified Substitute Suggestions:',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: disruption.suggestedSubstitutes.map((subName) {
                        return ActionChip(
                          avatar: const Icon(Icons.person_add,
                              size: 16, color: Color(0xFF00695C)),
                          label: Text('Approve $subName'),
                          backgroundColor: const Color(0xFFE0F2F1),
                          onPressed: () {
                            setState(() {
                              widget.repository.resolveDisruptionAlert(
                                  disruption.id, subName);
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Approved $subName for ${disruption.className} ${disruption.subjectCode}! Live schedule updated.'),
                                backgroundColor: const Color(0xFF00695C),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          }),

        const SizedBox(height: 24),

        // Approved & Pending Substitutions Log Table
        const Text(
          'All Institution Substitutions Log',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        ...substitutions.map((sub) {
          final isPending = sub.status == 'Pending';
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Class ${sub.className}: ${sub.subjectCode} - ${sub.subjectName}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(sub.status),
                        backgroundColor: isPending
                            ? Colors.amber.shade100
                            : Colors.green.shade50,
                        labelStyle: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPending
                              ? Colors.amber.shade900
                              : const Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${sub.dayOfWeek} (${sub.timeSlot}) • Absent: ${sub.originalFaculty} ➔ Substitute: ${sub.substituteFaculty}',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  if (isPending) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              widget.repository.rejectSubstitution(sub.id);
                            });
                          },
                          child: const Text('Reject'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00695C),
                          ),
                          onPressed: () {
                            setState(() {
                              widget.repository.approveSubstitution(sub.id);
                            });
                          },
                          child: const Text('Approve'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  // ===========================================================================
  // VIEW 4: CONFIGURATION VIEW
  // ===========================================================================
  Widget _buildView4Configuration(BuildContext context) {
    final config = widget.repository.getConfig();
    final facultyList = widget.repository.getFacultyList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Timetable Configuration & Resource Mapping',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const Text(
          'Global institutional settings and staff/subject mappings',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 20),

        // Global Settings Form Component
        TimetableConfigForm(
          config: config,
          onSaveConfig: (newCfg) {
            setState(() {
              widget.repository.updateConfig(newCfg);
              _selectedClass = newCfg.batchSection;
            });
          },
        ),

        const SizedBox(height: 24),

        // Resource Mapping (Staff Roster & Leave Status)
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Faculty Resource Mapping & Status Roster',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    Chip(
                      label: Text('${facultyList.length} Teachers'),
                      backgroundColor: Colors.blue.shade50,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...facultyList.map((fac) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: fac.onLeave
                          ? Colors.orange.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: fac.onLeave
                            ? Colors.orange.shade200
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: fac.onLeave
                              ? Colors.orange.shade100
                              : AppColors.primary.withValues(alpha: 0.1),
                          child: Icon(
                            fac.onLeave ? Icons.person_off : Icons.person,
                            color: fac.onLeave
                                ? Colors.orange.shade900
                                : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fac.name,
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                'Dept: ${fac.department} • Subjects: ${fac.subjectsHandled.join(", ")}',
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
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
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: fac.onLeave
                                ? Colors.orange.shade100
                                : Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            fac.onLeave ? 'ON LEAVE' : 'AVAILABLE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: fac.onLeave
                                  ? Colors.orange.shade900
                                  : const Color(0xFF2E7D32),
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
        ),

        const SizedBox(height: 24),

        // Faculty & Subject Workload Quotas Manager (Document Parsing + Manual Entry)
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Faculty Subject & Weekly Period Quotas',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const Text(
                          'Minimum required weekly period metrics per faculty member (used for AI schedule generation)',
                          style: TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showDocumentUploadModal(context),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Parse Document / CSV'),
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00695C),
                          ),
                          onPressed: () => _showAddQuotaDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Quota'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...widget.repository.getFacultyQuotas().map((quota) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00695C).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.school, color: Color(0xFF00695C), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${quota.facultyName} • ${quota.subjectCode}',
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                '${quota.subjectName} (${quota.department}) ${quota.isLab ? "• LAB" : ""}',
                                maxLines: 2,
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          label: Text('${quota.minWeeklyPeriods} Pds/Wk'),
                          backgroundColor: const Color(0xFFE0F2F1),
                          labelStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00695C),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF00695C)),
                              onPressed: () => _showEditQuotaDialog(context, quota),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  widget.repository.deleteFacultyQuota(quota.id);
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Manual Add / Edit Period Entry Dialog
  void _showManualEntryDialog(
    BuildContext context,
    TimetableEntry? entry, {
    String? initialDay,
    int? initialPeriod,
  }) {
    final isEdit = entry != null;
    final subjectCodeCtrl =
        TextEditingController(text: entry?.subjectCode ?? 'CS301');
    final subjectNameCtrl =
        TextEditingController(text: entry?.subjectName ?? 'Database Systems');
    final facultyCtrl = TextEditingController(
        text: entry?.facultyName ?? 'Prof. Sarah Jenkins');
    final timeSlotCtrl =
        TextEditingController(text: entry?.timeSlot ?? '08:30 - 09:20 AM');
    final periodCtrl = TextEditingController(
        text: (entry?.periodIndex ?? initialPeriod ?? 1).toString());
    bool isLab = entry?.isLab ?? false;
    String day = entry?.dayOfWeek ?? initialDay ?? _selectedDay;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isEdit ? Icons.edit : Icons.add_circle_outline,
                  color: const Color(0xFF00695C),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Period Slot' : 'Assign Subject & Staff',
                    softWrap: true,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: subjectCodeCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Subject Code'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: subjectNameCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Subject Name'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: facultyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Assigned Staff (Faculty)',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: day,
                          decoration: const InputDecoration(labelText: 'Day'),
                          items: [
                            'Monday',
                            'Tuesday',
                            'Wednesday',
                            'Thursday',
                            'Friday'
                          ]
                              .map((d) =>
                                  DropdownMenuItem(value: d, child: Text(d)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setDlgState(() => day = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: periodCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Period #'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: timeSlotCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Time Slot (e.g. 08:30 - 09:20 AM)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    title: const Text('Practical Lab Session'),
                    value: isLab,
                    onChanged: (val) => setDlgState(() => isLab = val ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              if (isEdit)
                TextButton(
                  onPressed: () {
                    setState(() {
                      widget.repository.deleteEntry(entry.id);
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Period slot removed.')),
                    );
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                ),
                onPressed: () {
                  final newEntry = TimetableEntry(
                    id: entry?.id ??
                        'ENT-${DateTime.now().millisecondsSinceEpoch % 10000}',
                    subjectCode: subjectCodeCtrl.text.trim(),
                    subjectName: subjectNameCtrl.text.trim(),
                    facultyId: 'FAC-101',
                    facultyName: facultyCtrl.text.trim(),
                    className: _selectedClass,
                    dayOfWeek: day,
                    timeSlot: timeSlotCtrl.text.trim(),
                    periodIndex: int.tryParse(periodCtrl.text) ?? 1,
                    isLab: isLab,
                    categoryColorValue: isLab ? 0xFF00ACC1 : 0xFF1E88E5,
                  );

                  setState(() {
                    if (isEdit) {
                      widget.repository.updateEntry(newEntry);
                    } else {
                      widget.repository.addEntry(newEntry);
                    }
                  });

                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEdit
                          ? 'Period slot updated.'
                          : 'New period slot added to $_selectedClass.'),
                      backgroundColor: const Color(0xFF00695C),
                    ),
                  );
                },
                child: Text(isEdit ? 'Save Changes' : 'Assign Period'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onGenerateTimetablePressed(BuildContext context) {
    final quotas = widget.repository.getFacultyQuotas();
    final config = widget.repository.getConfig();

    if (quotas.isEmpty || config.periodsPerDay == 0 || config.periodDurationMinutes == 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Expanded(
                child: Text('Configuration Incomplete', softWrap: true),
              ),
            ],
          ),
          content: const Text(
            'Faculty roster, period duration, or minimum weekly period quotas are missing. Please complete the setup in Configuration View before auto-generating matrix schedules.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF00695C),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _currentNavIndex = 3);
              },
              icon: const Icon(Icons.settings),
              label: const Text('Go to Configuration'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.purple),
            SizedBox(width: 8),
            Expanded(
              child: Text('Review Metrics & Auto-Generate', softWrap: true),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Auto-generating timetable matrix for Class $_selectedClass based on configured faculty quotas:',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Column(
                    children: quotas.map((q) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${q.facultyName} — ${q.subjectName} (${q.subjectCode})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${q.minWeeklyPeriods} Pds/Wk',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: AppColors.muted),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Note: Manually assigned/pinned periods will be preserved during matrix generation.',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final config = widget.repository.getConfig();
              final candidate = widget.repository.generateAiCandidate(config);
              setState(() {
                _aiPreviewEntries = candidate;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'AI Candidate schedule generated! Review & apply to master grid below.'),
                  backgroundColor: Colors.purple,
                ),
              );
            },
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Confirm & Generate'),
          ),
        ],
      ),
    );
  }

  void _showDocumentUploadModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.upload_file, color: Color(0xFF00695C)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Smart Document / Image Parsing',
                    softWrap: true,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Upload Curriculum Matrix (PDF, CSV, Doc, or Scanned Image) to auto-extract Faculty, Subjects, and Weekly Period Quotas.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00695C).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF00695C).withValues(alpha: 0.3),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.cloud_upload_outlined,
                            size: 40, color: Color(0xFF00695C)),
                        const SizedBox(height: 8),
                        const Text(
                          'Drag & Drop or Select File to Parse',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Chip(
                              label: const Text('CS_Faculty_Workload_Matrix_2026.csv'),
                              avatar: const Icon(Icons.description, size: 14),
                            ),
                            Chip(
                              label: const Text('Faculty_Workload.pdf'),
                              avatar: const Icon(Icons.picture_as_pdf, size: 14),
                            ),
                            Chip(
                              label: const Text('Scanned_Curriculum.png'),
                              avatar: const Icon(Icons.image, size: 14),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                ),
                onPressed: () {
                  final extracted = [
                    const FacultySubjectQuota(
                      id: 'EXT-201',
                      facultyName: 'Dr. Marcus Vance',
                      department: 'Computer Science',
                      subjectCode: 'CS306',
                      subjectName: 'AI & Machine Learning',
                      minWeeklyPeriods: 4,
                    ),
                    const FacultySubjectQuota(
                      id: 'EXT-202',
                      facultyName: 'Prof. Donald Knuth',
                      department: 'Computer Science',
                      subjectCode: 'CS304',
                      subjectName: 'Software Engineering',
                      minWeeklyPeriods: 3,
                    ),
                  ];
                  widget.repository.importFacultyQuotas(extracted);
                  setState(() {});
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Successfully extracted & imported 2 Faculty Quotas from document!'),
                      backgroundColor: Color(0xFF00695C),
                    ),
                  );
                },
                icon: const Icon(Icons.auto_fix_high),
                label: const Text('Simulate Parsing & Import'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddQuotaDialog(BuildContext context) {
    final facultyCtrl = TextEditingController(text: 'Prof. Alan Turing');
    final deptCtrl = TextEditingController(text: 'Computer Science');
    final codeCtrl = TextEditingController(text: 'CS307');
    final nameCtrl = TextEditingController(text: 'Compiler Design');
    final periodsCtrl = TextEditingController(text: '3');
    bool isLab = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_circle_outline, color: Color(0xFF00695C)),
                SizedBox(width: 8),
                Text('Add Faculty Subject Quota'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: facultyCtrl,
                    decoration: const InputDecoration(labelText: 'Faculty Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: deptCtrl,
                    decoration: const InputDecoration(labelText: 'Department'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Subject Code'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: periodsCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Min Pds / Wk'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Subject Name'),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    title: const Text('Is Practical Lab Session'),
                    value: isLab,
                    onChanged: (val) => setDlgState(() => isLab = val ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                ),
                onPressed: () {
                  final newQuota = FacultySubjectQuota(
                    id: 'QUO-${DateTime.now().millisecondsSinceEpoch % 10000}',
                    facultyName: facultyCtrl.text.trim(),
                    department: deptCtrl.text.trim(),
                    subjectCode: codeCtrl.text.trim(),
                    subjectName: nameCtrl.text.trim(),
                    minWeeklyPeriods: int.tryParse(periodsCtrl.text) ?? 3,
                    isLab: isLab,
                  );
                  setState(() {
                    widget.repository.addFacultyQuota(newQuota);
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Faculty workload quota added!'),
                      backgroundColor: Color(0xFF00695C),
                    ),
                  );
                },
                child: const Text('Save Quota'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditQuotaDialog(BuildContext context, FacultySubjectQuota quota) {
    final facultyCtrl = TextEditingController(text: quota.facultyName);
    final deptCtrl = TextEditingController(text: quota.department);
    final codeCtrl = TextEditingController(text: quota.subjectCode);
    final nameCtrl = TextEditingController(text: quota.subjectName);
    final periodsCtrl = TextEditingController(text: quota.minWeeklyPeriods.toString());
    bool isLab = quota.isLab;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit_outlined, color: Color(0xFF00695C)),
                SizedBox(width: 8),
                Text('Edit Faculty Quota'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: facultyCtrl,
                    decoration: const InputDecoration(labelText: 'Faculty Name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: deptCtrl,
                    decoration: const InputDecoration(labelText: 'Department'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codeCtrl,
                          decoration:
                              const InputDecoration(labelText: 'Subject Code'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: periodsCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Min Pds / Wk'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Subject Name'),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    title: const Text('Is Practical Lab Session'),
                    value: isLab,
                    onChanged: (val) => setDlgState(() => isLab = val ?? false),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00695C),
                ),
                onPressed: () {
                  final updatedQuota = FacultySubjectQuota(
                    id: quota.id,
                    facultyName: facultyCtrl.text.trim(),
                    department: deptCtrl.text.trim(),
                    subjectCode: codeCtrl.text.trim(),
                    subjectName: nameCtrl.text.trim(),
                    minWeeklyPeriods: int.tryParse(periodsCtrl.text) ?? 3,
                    isLab: isLab,
                  );
                  setState(() {
                    widget.repository.updateFacultyQuota(updatedQuota);
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Faculty workload quota updated!'),
                      backgroundColor: Color(0xFF00695C),
                    ),
                  );
                },
                child: const Text('Save Changes'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SlotInfo {
  const _SlotInfo({
    required this.label,
    required this.isBreak,
    required this.breakType,
    required this.periodIndex,
  });

  final String label;
  final bool isBreak;
  final String breakType; // 'tea' | 'lunch' | ''
  final int periodIndex;
}

List<_SlotInfo> _generateTimeSlots(TimetableConfig config) {
  final slots = <_SlotInfo>[];
  var currentMinutes = 8 * 60 + 30; // 08:30 AM in minutes

  String formatTime(int mins) {
    final h = (mins ~/ 60) % 24;
    final m = mins % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h % 12 == 0 ? 12 : h % 12;
    final mStr = m.toString().padLeft(2, '0');
    final hStr = displayH.toString().padLeft(2, '0');
    return '$hStr:$mStr $period';
  }

  for (int p = 1; p <= config.periodsPerDay; p++) {
    final startStr = formatTime(currentMinutes);
    final endMinutes = currentMinutes + config.periodDurationMinutes;
    final endStr = formatTime(endMinutes);

    slots.add(_SlotInfo(
      label: 'P$p\n$startStr - $endStr',
      isBreak: false,
      breakType: '',
      periodIndex: p,
    ));

    currentMinutes = endMinutes;

    if (p == config.teaBreakPosition) {
      final breakStartStr = formatTime(currentMinutes);
      final breakEndMinutes = currentMinutes + config.teaBreakDurationMinutes;
      final breakEndStr = formatTime(breakEndMinutes);
      slots.add(_SlotInfo(
        label: 'TEA BREAK\n$breakStartStr - $breakEndStr',
        isBreak: true,
        breakType: 'tea',
        periodIndex: 0,
      ));
      currentMinutes = breakEndMinutes;
    }

    if (p == config.lunchBreakPosition) {
      final breakStartStr = formatTime(currentMinutes);
      final breakEndMinutes = currentMinutes + config.lunchBreakDurationMinutes;
      final breakEndStr = formatTime(breakEndMinutes);
      slots.add(_SlotInfo(
        label: 'LUNCH BREAK\n$breakStartStr - $breakEndStr',
        isBreak: true,
        breakType: 'lunch',
        periodIndex: 0,
      ));
      currentMinutes = breakEndMinutes;
    }
  }

  return slots;
}
