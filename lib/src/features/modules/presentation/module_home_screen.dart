import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../authentication/data/auth_repository.dart';

class ModuleHomeScreen extends StatelessWidget {
  const ModuleHomeScreen({
    super.key,
    required this.session,
    this.onOpenCanteen,
    this.onOpenGatepass,
    this.onOpenTimetable,
    this.onOpenAttendance,
    required this.onSignOut,
  });

  final UserSession session;
  final VoidCallback? onOpenCanteen;
  final VoidCallback? onOpenGatepass;
  final VoidCallback? onOpenTimetable;
  final VoidCallback? onOpenAttendance;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final brandPrimary = Theme.of(context).colorScheme.primary;
    final brandSecondary = Theme.of(context).colorScheme.secondary;
    final role = session.role;
    final portalTitle = switch (role) {
      UserRole.staff => 'SuperCampus Faculty Portal',
      UserRole.timetableAllocator => 'SuperCampus Admin Portal',
      UserRole.admin => 'SuperCampus Administrator Portal',
      UserRole.security => 'SuperCampus Security Portal',
      UserRole.parent => 'SuperCampus Parent Portal',
      _ => 'SuperCampus Student Portal',
    };

    final showAttendance = role == UserRole.student || role == UserRole.staff;
    final showTimetable =
        role == UserRole.student ||
        role == UserRole.staff ||
        role == UserRole.timetableAllocator ||
        role == UserRole.admin;
    final showCanteen = role == UserRole.student || role == UserRole.staff;
    final showGatepass =
        role == UserRole.student ||
        role == UserRole.security ||
        role == UserRole.parent;

    return Scaffold(
      appBar: AppBar(
        title: Text(portalTitle),
        actions: [
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
                  'Choose a campus service module',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),

                if (showAttendance && onOpenAttendance != null) ...[
                  _ModuleTile(
                    title: role == UserRole.student
                        ? 'Student Attendance'
                        : 'Faculty Attendance Module',
                    subtitle:
                        'Digital swipe attendance, student rosters and leave approvals',
                    icon: Icons.badge_outlined,
                    color: brandPrimary,
                    status: 'Active',
                    onTap: onOpenAttendance ?? () {},
                  ),
                  const SizedBox(height: 12),
                ],

                if (showTimetable && onOpenTimetable != null) ...[
                  _ModuleTile(
                    title: 'Timetable Management',
                    subtitle:
                        'Class schedules, daily teaching periods, and faculty updates',
                    icon: Icons.table_chart_outlined,
                    color: brandSecondary,
                    status: 'Active',
                    onTap: onOpenTimetable ?? () {},
                  ),
                  const SizedBox(height: 12),
                ],

                if (showCanteen && onOpenCanteen != null) ...[
                  _ModuleTile(
                    title: 'Canteen',
                    subtitle: 'Browse the menu, pay and track pickup orders',
                    icon: Icons.restaurant_outlined,
                    color: brandPrimary,
                    status: 'Open now',
                    onTap: onOpenCanteen!,
                  ),
                  const SizedBox(height: 12),
                ],

                if (showGatepass && onOpenGatepass != null) ...[
                  _ModuleTile(
                    title: 'Gatepass',
                    subtitle:
                        'Outpasses, campus access and visitor invitations',
                    icon: Icons.badge_outlined,
                    color: brandSecondary,
                    status: 'Active',
                    onTap: onOpenGatepass!,
                  ),
                  const SizedBox(height: 28),
                ],

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
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Theme.of(context).dividerColor),
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
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
