import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';

class ModuleHomeScreen extends StatelessWidget {
  const ModuleHomeScreen({
    super.key,
    required this.session,
    required this.onOpenCanteen,
    required this.onOpenGatepass,
    required this.onSignOut,
    this.onSwitchRole,
  });

  final StudentSession session;
  final VoidCallback onOpenCanteen;
  final VoidCallback onOpenGatepass;
  final VoidCallback onSignOut;
  final ValueChanged<UserRole>? onSwitchRole;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SuperCampus Student Portal'),
        actions: [
          if (onSwitchRole != null)
            PopupMenuButton<UserRole>(
              tooltip: 'Switch Portal Role',
              icon: const Icon(Icons.swap_horiz),
              onSelected: onSwitchRole,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  enabled: false,
                  child: Text('Switch Role (Demo mode):'),
                ),
                ...UserRole.values.map(
                  (r) => PopupMenuItem(
                    value: r,
                    child: Row(
                      children: [
                        Icon(
                          r == session.role
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          size: 16,
                          color: r == session.role
                              ? AppColors.primary
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(r.label),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: onSignOut,
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              children: [
                Text(
                  'Good ${_dayPart()}, ${_firstName(session.displayName)}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose a campus service',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 28),
                _ModuleTile(
                  title: 'Canteen',
                  subtitle: 'Browse the menu, pay and track pickup orders',
                  icon: Icons.restaurant_outlined,
                  color: AppColors.primary,
                  status: 'Open now',
                  onTap: onOpenCanteen,
                ),
                const SizedBox(height: 12),
                _ModuleTile(
                  title: 'Gatepass',
                  subtitle: 'Outpasses, campus access and visitor invitations',
                  icon: Icons.badge_outlined,
                  color: const Color(0xFF2455A4),
                  status: 'On campus',
                  onTap: onOpenGatepass,
                ),
                const SizedBox(height: 28),
                Text(
                  'Coming next',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Expanded(
                      child: _SmallModule(
                        label: 'Tuition fee',
                        icon: Icons.account_balance_outlined,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _SmallModule(
                        label: 'Academics',
                        icon: Icons.school_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _dayPart() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  String _firstName(String name) => name.split(' ').first;
}

class _ModuleTile extends StatelessWidget {
  const _ModuleTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.status,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(subtitle),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallModule extends StatelessWidget {
  const _SmallModule({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 94,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.muted),
          const Spacer(),
          Text(label, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
