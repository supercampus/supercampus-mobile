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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
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
                      label: 'acads',
                      isSelected: selectedId == 'acads',
                    ),
                    _NavItem(
                      id: 'gatepass',
                      label: 'gatepass',
                      isSelected: selectedId == 'gatepass',
                    ),
                    _NavItem(
                      id: 'wallet',
                      label: 'wallet',
                      isSelected: selectedId == 'wallet',
                    ),
                    _NavItem(
                      id: 'analysis',
                      label: 'analysis',
                      isSelected: selectedId == 'analysis',
                    ),
                  ],
                ),
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
    required this.label,
    required this.isSelected,
  });

  final String id;
  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton(
        onPressed: () {},
        style: TextButton.styleFrom(
          foregroundColor: isSelected
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.onSurfaceVariant,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
