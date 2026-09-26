import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../data/canteen_models.dart';
import 'widgets/canteen_surface.dart';

class StudentCanteenProfileScreen extends StatefulWidget {
  const StudentCanteenProfileScreen({
    super.key,
    required this.store,
    required this.onSignOut,
    this.canUseWorkMode = false,
    this.currentMode = CanteenStaffMode.eat,
    this.onModeChanged,
  });

  final CanteenStore store;
  final VoidCallback onSignOut;
  final bool canUseWorkMode;
  final CanteenStaffMode currentMode;
  final ValueChanged<CanteenStaffMode>? onModeChanged;

  @override
  State<StudentCanteenProfileScreen> createState() =>
      _StudentCanteenProfileScreenState();
}

class _StudentCanteenProfileScreenState
    extends State<StudentCanteenProfileScreen> {
  late CanteenStaffMode _currentMode = widget.currentMode;

  @override
  void didUpdateWidget(StudentCanteenProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentMode != widget.currentMode) {
      _currentMode = widget.currentMode;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.store.user;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & settings'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: CanteenPageBody(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: AppColors.amberSoft,
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 23,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.department,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'MEC Student',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatTile(
                  icon: Icons.tag,
                  label: 'Roll number',
                  value: user.rollNumber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatTile(
                  icon: Icons.apartment_outlined,
                  label: 'Department',
                  value: user.department,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.canUseWorkMode) ...[
            CanteenSurface(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7F0FC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _currentMode == CanteenStaffMode.work
                              ? Icons.storefront_outlined
                              : Icons.restaurant_outlined,
                          size: 20,
                          color: const Color(0xFF2563A9),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Canteen Mode',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _currentMode == CanteenStaffMode.work
                                  ? 'Work mode (managing orders & counter)'
                                  : 'Eat mode (student menu & ordering)',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<CanteenStaffMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: CanteenStaffMode.work,
                          icon: Icon(Icons.work_outline_rounded, size: 16),
                          label: Text(
                            'Work mode',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        ButtonSegment(
                          value: CanteenStaffMode.eat,
                          icon: Icon(Icons.restaurant_outlined, size: 16),
                          label: Text(
                            'Eat mode',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ],
                      selected: {_currentMode},
                      onSelectionChanged: (selection) {
                        final mode = selection.first;
                        setState(() => _currentMode = mode);
                        widget.onModeChanged?.call(mode);
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          for (final setting in const [
            (Icons.history, 'Order history', 'View past completed orders'),
            (
              Icons.lock_outline,
              'Change password',
              'Update your account password',
            ),
            (
              Icons.pin_outlined,
              'Transaction PIN',
              'Change or reset your payment PIN',
            ),
            (
              Icons.notifications_none,
              'Notifications',
              'Manage canteen notifications',
            ),
            (
              Icons.shield_outlined,
              'Privacy & security',
              'Account security settings',
            ),
            (Icons.help_outline, 'Help & support', 'Get help with your orders'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CanteenSurface(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${setting.$2} will open here.')),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE7F0FC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(setting.$1, color: const Color(0xFF2563A9)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            setting.$2,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            setting.$3,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return CanteenSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
