import 'package:flutter/material.dart';

class DashboardNavBar extends StatelessWidget {
  const DashboardNavBar({
    super.key,
    required this.selectedId,
    this.onSelect,
  });

  final String selectedId;
  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItem(
                    id: 'acads',
                    icon: Icons.menu_book_rounded,
                    tooltip: 'Academics',
                    isSelected: selectedId == 'acads',
                    onTap: () => onSelect?.call('acads'),
                  ),
                  _NavItem(
                    id: 'gatepass',
                    icon: Icons.badge_outlined,
                    tooltip: 'Gatepass',
                    isSelected: selectedId == 'gatepass',
                    onTap: () => onSelect?.call('gatepass'),
                  ),
                  _NavItem(
                    id: 'wall',
                    icon: Icons.campaign_outlined,
                    tooltip: 'Wall - Announcements & Circulars',
                    isSelected: selectedId == 'wall',
                    onTap: () => onSelect?.call('wall'),
                  ),
                  _NavItem(
                    id: 'analysis',
                    icon: Icons.bar_chart_rounded,
                    tooltip: 'Reports & Analysis',
                    isSelected: selectedId == 'analysis',
                    onTap: () => onSelect?.call('analysis'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.id,
    required this.icon,
    required this.isSelected,
    this.tooltip,
    this.onTap,
  });

  final String id;
  final IconData icon;
  final bool isSelected;
  final String? tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(
        icon,
        size: 24,
        color: isSelected
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
