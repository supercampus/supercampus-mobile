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
      return _NoResidencyView(onApply: onApplyAccommodation);
    }

    final outpass = _activeOutpass;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _ResidencyCard(residency: residency),
        if (outpass != null) ...[
          const SizedBox(height: 14),
          _ActiveOutpassCard(outpass: outpass, onPressed: onOpenOutpass),
        ],
        const SizedBox(height: 24),
        const _SectionHeader(
          title: 'Services',
          subtitle: 'Everything you need for your hostel stay',
        ),
        const SizedBox(height: 12),
        _ServicesGrid(items: _serviceItems),
        const SizedBox(height: 24),
        _MealOverview(tokens: store.messTokens, onPressed: onOpenMess),
        const SizedBox(height: 24),
        _MovementHistory(movements: store.movements),
      ],
    );
  }

  HostelOutpass? get _activeOutpass {
    for (final outpass in store.outpasses) {
      if (outpass.status == OutpassStatus.approved ||
          outpass.status == OutpassStatus.active) {
        return outpass;
      }
    }
    return null;
  }

  List<_ServiceItem> get _serviceItems => [
    _ServiceItem(
      title: 'Leave & outpass',
      subtitle: 'Apply and show your QR',
      icon: Icons.logout_rounded,
      color: const Color(0xFF2455A4),
      onTap: onOpenOutpass,
    ),
    _ServiceItem(
      title: 'Mess & meals',
      subtitle: 'View today\'s meal tokens',
      icon: Icons.restaurant_rounded,
      color: const Color(0xFFD97706),
      onTap: onOpenMess,
    ),
    _ServiceItem(
      title: 'Report an issue',
      subtitle: 'Request hostel maintenance',
      icon: Icons.handyman_rounded,
      color: const Color(0xFFC2413B),
      onTap: onOpenComplaints,
    ),
    _ServiceItem(
      title: 'Room change',
      subtitle: 'Request a room or bed move',
      icon: Icons.swap_horiz_rounded,
      color: const Color(0xFF7357C8),
      onTap: onOpenRoomChange,
    ),
    if (onOpenVisitors != null)
      _ServiceItem(
        title: 'Visitors',
        subtitle: 'Manage visitor passes',
        icon: Icons.people_alt_outlined,
        color: const Color(0xFF0F8B74),
        onTap: onOpenVisitors!,
      ),
    _ServiceItem(
      title: 'Vacate & clearance',
      subtitle: 'Track your clearance steps',
      icon: Icons.fact_check_outlined,
      color: const Color(0xFF52606D),
      onTap: onOpenVacateClearance,
    ),
  ];
}

class _NoResidencyView extends StatelessWidget {
  const _NoResidencyView({required this.onApply});

  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.night_shelter_outlined,
                size: 48,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No active hostel stay',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Apply for accommodation to access room, mess and hostel services.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onApply,
              icon: const Icon(Icons.add_home_outlined),
              label: const Text('Apply for accommodation'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResidencyCard extends StatelessWidget {
  const _ResidencyCard({required this.residency});

  final HostelResidency residency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.violetGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _GradientBadge(
                    icon: Icons.verified_rounded,
                    label: residency.residencyStatus.label,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _GradientBadge(
                    icon: Icons.circle,
                    label: residency.presenceStatus.label,
                    iconColor: const Color(0xFFB9F6CA),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            residency.hostelName,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Room ${residency.roomNumber}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              height: 1.15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            residency.bedCode,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ResidencyDetail(
                  label: 'RESIDENT',
                  value: residency.studentName,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 16),
              _ResidencyDetail(
                label: 'HOSTEL DUES',
                value: residency.dueAmount == 0
                    ? 'No dues'
                    : '₹${residency.dueAmount.toStringAsFixed(0)} due',
                alignEnd: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GradientBadge extends StatelessWidget {
  const _GradientBadge({
    required this.icon,
    required this.label,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 13),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResidencyDetail extends StatelessWidget {
  const _ResidencyDetail({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 9,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ActiveOutpassCard extends StatelessWidget {
  const _ActiveOutpassCard({required this.outpass, required this.onPressed});

  final HostelOutpass outpass;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final returnTime = TimeOfDay.fromDateTime(
      outpass.expectedReturnAt,
    ).format(context);

    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.qr_code_2_rounded,
                  color: colors.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Active outpass',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            outpass.status.label,
                            style: TextStyle(
                              color: colors.onPrimaryContainer,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${outpass.destination} · Return by $returnTime',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ServicesGrid extends StatelessWidget {
  const _ServicesGrid({required this.items});

  final List<_ServiceItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final width = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _ServiceTile(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.item});

  final _ServiceItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 124),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(item.icon, color: item.color, size: 21),
                ),
                const SizedBox(height: 12),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MealOverview extends StatelessWidget {
  const _MealOverview({required this.tokens, required this.onPressed});

  final List<MessMealToken> tokens;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final readyCount = tokens
        .where((token) => token.status == MealTokenStatus.unused)
        .length;

    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  color: colors.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s meal passes',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tokens.isEmpty
                          ? 'No meal passes available'
                          : '$readyCount of ${tokens.length} ready to use',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _MovementHistory extends StatelessWidget {
  const _MovementHistory({required this.movements});

  final List<HostelMovement> movements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final visibleMovements = movements.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'Recent movement',
          subtitle: 'Your latest hostel gate activity',
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: visibleMovements.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'No recent gate movements',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (
                      var index = 0;
                      index < visibleMovements.length;
                      index++
                    ) ...[
                      _MovementTile(movement: visibleMovements[index]),
                      if (index < visibleMovements.length - 1)
                        Divider(height: 1, color: colors.outlineVariant),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.movement});

  final HostelMovement movement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isExit = movement.movementType == 'EXIT';
    final time = TimeOfDay.fromDateTime(movement.timestamp).format(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isExit ? colors.tertiaryContainer : colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          isExit ? Icons.north_east_rounded : Icons.south_west_rounded,
          color: isExit
              ? colors.onTertiaryContainer
              : colors.onPrimaryContainer,
          size: 20,
        ),
      ),
      title: Text(
        isExit ? 'Checked out' : 'Checked in',
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        movement.gateName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall,
      ),
      trailing: Text(
        time,
        style: theme.textTheme.labelMedium?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ServiceItem {
  const _ServiceItem({
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
