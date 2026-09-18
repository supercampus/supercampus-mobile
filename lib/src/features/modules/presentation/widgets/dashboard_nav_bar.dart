import 'package:flutter/material.dart';

class DashboardNavBar extends StatelessWidget {
  const DashboardNavBar({super.key, required this.selectedId});

  final String selectedId;

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
                    icon: Icons.menu_book_rounded,
                    isSelected: selectedId == 'acads',
                  ),
                  _NavItem(
                    icon: Icons.badge_outlined,
                    isSelected: selectedId == 'gatepass',
                  ),
                  _NavItem(
                    icon: Icons.account_balance_wallet_outlined,
                    isSelected: selectedId == 'wallet',
                  ),
                  _NavItem(
                    icon: Icons.bar_chart_rounded,
                    isSelected: selectedId == 'analysis',
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
    required this.icon,
    required this.isSelected,
  });

  final IconData icon;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {},
      icon: Icon(
        icon,
        size: 24,
        color: isSelected
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
      ),
    );
  }
}
