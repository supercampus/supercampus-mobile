import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/hostel_models.dart';

class HostelOpsDashboardScreen extends StatelessWidget {
  const HostelOpsDashboardScreen({
    super.key,
    required this.store,
    required this.onOpenInventory,
    required this.onOpenOutpasses,
    required this.onOpenComplaints,
    required this.onOpenRoomChanges,
    required this.onOpenClearance,
  });

  final HostelStore store;
  final VoidCallback onOpenInventory;
  final VoidCallback onOpenOutpasses;
  final VoidCallback onOpenComplaints;
  final VoidCallback onOpenRoomChanges;
  final VoidCallback onOpenClearance;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header banner
          const Text(
            'Hostel Operations & Management',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Live occupancy, gate movements, outpass overdue flags and operational queues.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),

          // Operational metrics grid
          _buildMetricsGrid(context),

          const SizedBox(height: 24),

          // Actionable queues
          Text(
            'Operational Queues Needs Attention',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _buildOperationalQueuesList(context),

          const SizedBox(height: 24),

          // Live Hostel Outpasses & Movement Activity
          _buildOutpassQueue(context),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    final metrics = [
      _MetricTile(
        title: 'Active Residents',
        value: '2,843',
        icon: Icons.people_alt_outlined,
        color: AppColors.primary,
      ),
      _MetricTile(
        title: 'Currently Inside',
        value: '2,162',
        icon: Icons.home_rounded,
        color: Colors.green.shade700,
      ),
      _MetricTile(
        title: 'Currently Outside',
        value: '681',
        icon: Icons.directions_walk_rounded,
        color: Colors.orange.shade800,
      ),
      _MetricTile(
        title: 'On Approved Leave',
        value: '184',
        icon: Icons.flight_takeoff_rounded,
        color: Colors.blue.shade700,
      ),
      _MetricTile(
        title: 'Available Beds',
        value: '127',
        icon: Icons.single_bed_outlined,
        color: Colors.teal.shade700,
      ),
      _MetricTile(
        title: 'Open Complaints',
        value: '${store.complaints.length}',
        icon: Icons.error_outline_rounded,
        color: Colors.red.shade700,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.25,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final m = metrics[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(m.icon, color: m.color, size: 20),
              const SizedBox(height: 4),
              Text(
                m.value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: m.color,
                ),
              ),
              Text(
                m.title,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOperationalQueuesList(BuildContext context) {
    final queues = [
      _QueueRow(
        title: 'Students Overdue from Outpass',
        count: '3 Students',
        icon: Icons.timer_off_outlined,
        color: Colors.red.shade800,
        onTap: onOpenOutpasses,
      ),
      _QueueRow(
        title: 'Pending Hostel Applications',
        count: '12 Pending',
        icon: Icons.assignment_outlined,
        color: Colors.amber.shade900,
        onTap: onOpenInventory,
      ),
      _QueueRow(
        title: 'Room Change Requests',
        count: '${store.roomChangeRequests.length} Requests',
        icon: Icons.swap_horiz_rounded,
        color: Colors.purple.shade800,
        onTap: onOpenRoomChanges,
      ),
      _QueueRow(
        title: 'Maintenance Complaints',
        count: '${store.complaints.length} Open',
        icon: Icons.build_outlined,
        color: Colors.deepOrange.shade800,
        onTap: onOpenComplaints,
      ),
      _QueueRow(
        title: 'Pending Hostel Clearances',
        count: '5 Pending',
        icon: Icons.fact_check_outlined,
        color: Colors.indigo.shade800,
        onTap: onOpenClearance,
      ),
    ];

    return Column(
      children: queues.map((q) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: q.color.withValues(alpha: 0.1),
              child: Icon(q.icon, color: q.color, size: 20),
            ),
            title: Text(
              q.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: q.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    q.count,
                    style: TextStyle(
                      color: q.color,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
            onTap: q.onTap,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildOutpassQueue(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Outpass Approvals',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              TextButton(
                onPressed: onOpenOutpasses,
                child: const Text('Manage All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: store.outpasses.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final o = store.outpasses[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '${o.studentName} (${o.studentCode})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: Text(
                  'Destination: ${o.destination}\nLeave: ${o.leavingAt.hour}:${o.leavingAt.minute.toString().padLeft(2, "0")} · Return: ${o.expectedReturnAt.hour}:${o.expectedReturnAt.minute.toString().padLeft(2, "0")}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    o.status.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricTile {
  const _MetricTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
}

class _QueueRow {
  const _QueueRow({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
