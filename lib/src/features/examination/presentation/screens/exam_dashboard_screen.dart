import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/status_lifecycle_widget.dart';

class ExamDashboardScreen extends StatefulWidget {
  const ExamDashboardScreen({super.key, required this.onNavigateToTab});

  final ValueChanged<int> onNavigateToTab;

  @override
  State<ExamDashboardScreen> createState() => _ExamDashboardScreenState();
}

class _ExamDashboardScreenState extends State<ExamDashboardScreen> {
  ExamCanonicalStatus _selectedStatus = ExamCanonicalStatus.conducted;

  // TODO: Fetch dashboard summary KPIs from GET /api/v1/examination/dashboard/stats
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderCard(),
          const SizedBox(height: 16),
          StatusLifecycleWidget(
            currentStatus: _selectedStatus,
            onStatusSelected: (status) =>
                setState(() => _selectedStatus = status),
          ),
          const SizedBox(height: 20),
          const Text(
            'Quick Statistics & KPIs',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          _buildKpiGrid(),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildPendingActionsCard()),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: _buildRecentActivityTimeline()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.assignment, color: Colors.white, size: 36),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SuperCampus Examination System',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Autumn Semester 2026 • End-to-End Assessment Lifecycle',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF1B5E20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => widget.onNavigateToTab(2), // Jump to Scheduling
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: const Text('Schedule Exam'),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid() {
    final kpis = [
      _KpiItem(
        'Active Exams',
        '14',
        'Scheduled & In Progress',
        Icons.event_note,
        Colors.blue,
        2,
      ),
      _KpiItem(
        'Pending Marks Entry',
        '08',
        'Subjects awaiting marks',
        Icons.edit_note,
        Colors.orange,
        5,
      ),
      _KpiItem(
        'Moderation Queue',
        '03',
        'Outliers & grace marks review',
        Icons.fact_check,
        Colors.purple,
        6,
      ),
      _KpiItem(
        'Hall Tickets Issued',
        '1,420',
        'Eligible students verified',
        Icons.qr_code,
        Colors.teal,
        3,
      ),
      _KpiItem(
        'Results Published',
        '92%',
        'Autumn 2026 Batch',
        Icons.verified,
        Colors.green,
        9,
      ),
      _KpiItem(
        'Pending Revaluation',
        '05',
        'Applications under review',
        Icons.find_in_page,
        Colors.amber,
        10,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800
            ? 3
            : (constraints.maxWidth > 500 ? 2 : 1);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: kpis.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 2.3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final item = kpis[index];
            return InkWell(
              onTap: () => widget.onNavigateToTab(item.targetTab),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(item.icon, color: item.color, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.value,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: item.color,
                            ),
                          ),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            item.subtitle,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPendingActionsCard() {
    final actions = [
      _ActionItem(
        'Verify Marks Entry — Data Structures (CS301)',
        'Submitted by Prof. S. Jenkins • 65 Students',
        'High Priority',
        Colors.red,
        5,
      ),
      _ActionItem(
        'Resolve Room Conflict — Hall B (Capacity 60 vs 75)',
        'Exam: CS402 Algorithm Design • Slot 09:30 AM',
        'Critical',
        Colors.deepOrange,
        2,
      ),
      _ActionItem(
        'Review Grace Marks Application — Mechanical Batch A',
        '3 Students within 2 marks range of passing threshold',
        'Medium',
        Colors.orange,
        6,
      ),
      _ActionItem(
        'Approve Autumn 2026 Semester 5 Result Release',
        'Controller Level Approval Pending',
        'Gating Action',
        Colors.blue,
        9,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.pending_actions,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Pending Workflow Actions & Approvals',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const Spacer(),
              Chip(
                label: Text('${actions.length} Actionable'),
                backgroundColor: AppColors.amberSoft,
                side: BorderSide.none,
                labelStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: actions.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final act = actions[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 4,
                ),
                title: Text(
                  act.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
                subtitle: Text(
                  act.subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: act.badgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        act.badge,
                        style: TextStyle(
                          color: act.badgeColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 14),
                      onPressed: () => widget.onNavigateToTab(act.targetTab),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityTimeline() {
    final activities = [
      _Activity(
        'Hall Tickets generated for 450 CS Students',
        '10 mins ago',
        Icons.qr_code,
        Colors.teal,
      ),
      _Activity(
        'Marks locked for Subject EE201 Electrical Eng',
        '45 mins ago',
        Icons.lock,
        Colors.purple,
      ),
      _Activity(
        'Incident reported in Room 204 during CS101 exam',
        '2 hrs ago',
        Icons.warning_amber,
        Colors.red,
      ),
      _Activity(
        'Schedule Published for End-Sem Autumn 2026',
        'Yesterday',
        Icons.publish,
        Colors.blue,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Text(
                'Recent Exam Log',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const Divider(),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final act = activities[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: act.color.withValues(alpha: 0.15),
                      child: Icon(act.icon, size: 14, color: act.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            act.title,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            act.time,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _KpiItem {
  _KpiItem(
    this.title,
    this.value,
    this.subtitle,
    this.icon,
    this.color,
    this.targetTab,
  );
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final int targetTab;
}

class _ActionItem {
  _ActionItem(
    this.title,
    this.subtitle,
    this.badge,
    this.badgeColor,
    this.targetTab,
  );
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final int targetTab;
}

class _Activity {
  _Activity(this.title, this.time, this.icon, this.color);
  final String title;
  final String time;
  final IconData icon;
  final Color color;
}
