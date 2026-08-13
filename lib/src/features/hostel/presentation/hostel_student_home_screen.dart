import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/hostel_models.dart';

class HostelStudentHomeScreen extends StatelessWidget {
  const HostelStudentHomeScreen({
    super.key,
    required this.store,
    required this.onApplyAccommodation,
    required this.onOpenOutpass,
    required this.onOpenMess,
    required this.onOpenComplaints,
    required this.onOpenRoomChange,
    this.onOpenVisitors,
    required this.onOpenVacateClearance,
  });

  final HostelStore store;
  final VoidCallback onApplyAccommodation;
  final VoidCallback onOpenOutpass;
  final VoidCallback onOpenMess;
  final VoidCallback onOpenComplaints;
  final VoidCallback onOpenRoomChange;
  final VoidCallback? onOpenVisitors;
  final VoidCallback onOpenVacateClearance;

  @override
  Widget build(BuildContext context) {
    final residency = store.activeResidency;

    if (residency == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Hostel Residency')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.night_shelter_outlined,
                    size: 64,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No Active Hostel Residency',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'You currently do not have an active hostel bed allotment for Academic Year 2026-27.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onApplyAccommodation,
                  icon: const Icon(Icons.add_home_outlined),
                  label: const Text('Apply for Accommodation'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Active Residency Header Card
          _buildResidencyCard(context, residency),
          const SizedBox(height: 20),

          // Outpass Status Banner if active
          _buildOutpassBanner(context),

          const SizedBox(height: 20),

          // Quick Action Tools Grid
          Text(
            'Hostel Operations & Services',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          _buildActionsGrid(context),

          const SizedBox(height: 24),

          // Mess Meal Passes Section
          _buildMessSection(context),

          const SizedBox(height: 24),

          // Recent Gate Movements Feed
          _buildMovementHistory(context),
        ],
      ),
    );
  }

  Widget _buildResidencyCard(BuildContext context, HostelResidency residency) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B4931), Color(0xFF2E7D52)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      residency.residencyStatus.label.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // Presence Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: residency.presenceStatus.color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      residency.presenceStatus.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            residency.hostelName,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Room ${residency.roomNumber} · ${residency.bedCode}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resident Student',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  Text(
                    residency.studentName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Hostel Dues',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  Text(
                    residency.dueAmount == 0
                        ? '₹0 Due'
                        : '₹${residency.dueAmount.toStringAsFixed(0)} Due',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOutpassBanner(BuildContext context) {
    final activeOutpass = store.outpasses.firstWhere(
      (o) => o.status == OutpassStatus.approved || o.status == OutpassStatus.active,
      orElse: () => store.outpasses.first,
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.qr_code_2, color: Colors.amber.shade900),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Approved Outpass (${activeOutpass.id})',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900,
                  ),
                ),
                Text(
                  'Return by ${activeOutpass.expectedReturnAt.hour}:${activeOutpass.expectedReturnAt.minute.toString().padLeft(2, '0')} PM · ${activeOutpass.destination}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: onOpenOutpass,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.amber.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: const Icon(Icons.qr_code, size: 16),
            label: const Text('Show QR', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsGrid(BuildContext context) {
    final items = [
      _ActionItem(
        title: 'Leave / Outpass',
        subtitle: 'Apply exit pass & QR',
        icon: Icons.output_rounded,
        color: const Color(0xFF2455A4),
        onTap: onOpenOutpass,
      ),
      _ActionItem(
        title: 'Mess Meals',
        subtitle: '3 Daily meal QR tokens',
        icon: Icons.restaurant_menu_rounded,
        color: const Color(0xFFD97706),
        onTap: onOpenMess,
      ),
      _ActionItem(
        title: 'Report Problem',
        subtitle: 'Maintenance complaints',
        icon: Icons.build_outlined,
        color: const Color(0xFFDC2626),
        onTap: onOpenComplaints,
      ),
      _ActionItem(
        title: 'Room Change',
        subtitle: 'Request bed transfer',
        icon: Icons.swap_horiz_rounded,
        color: const Color(0xFF7C3AED),
        onTap: onOpenRoomChange,
      ),
      _ActionItem(
        title: 'Vacate & Clearance',
        subtitle: '7-Point clearance check',
        icon: Icons.assignment_turned_in_outlined,
        color: const Color(0xFF4B5563),
        onTap: onOpenVacateClearance,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.6,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.05),
          child: InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item.icon, color: item.color, size: 20),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessSection(BuildContext context) {
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
              const Row(
                children: [
                  Icon(Icons.flatware, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Today\'s Mess Meal QR Tokens',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              TextButton(
                onPressed: onOpenMess,
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: store.messTokens.map((t) {
              final isUsed = t.status == MealTokenStatus.used;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isUsed
                        ? Colors.grey.shade100
                        : AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isUsed ? Colors.grey.shade300 : AppColors.primary,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        t.mealType.label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isUsed ? AppColors.muted : AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Icon(
                        isUsed ? Icons.check_circle : Icons.qr_code_2,
                        color: isUsed ? Colors.green : AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isUsed ? 'REDEEMED' : 'READY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isUsed ? Colors.green : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementHistory(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Gate Movement Log',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: store.movements.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final m = store.movements[index];
              final isExit = m.movementType == 'EXIT';
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isExit
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  child: Icon(
                    isExit ? Icons.north_east : Icons.south_west,
                    color: isExit ? Colors.orange.shade800 : Colors.green.shade800,
                  ),
                ),
                title: Text(
                  '${m.movementType} · ${m.gateName}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  'Method: ${m.method} ${m.outpassId != null ? "(${m.outpassId})" : ""}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  '${m.timestamp.hour}:${m.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.muted,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ActionItem {
  const _ActionItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}
