import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class DashboardNavBar extends StatelessWidget {
  const DashboardNavBar({
    super.key,
    required this.selectedId,
    this.onSelect,
    this.onHome,
  });

  final String selectedId;
  final ValueChanged<String>? onSelect;

  /// Returns to the home screen. Fired by a double tap on any tab.
  final VoidCallback? onHome;

  /// Tabs whose double tap goes home.
  static const _homeOnDoubleTap = {'acads', 'gatepass', 'wall', 'analysis'};
  static const _doubleTapWindow = Duration(milliseconds: 450);

  // Static on purpose: the first tap usually pushes a new page, so the second
  // tap lands on that page's nav bar — a different widget instance.
  static String? _lastTapId;
  static DateTime? _lastTapAt;

  /// Visible for tests: forget the previous tap.
  @visibleForTesting
  static void resetTapMemory() {
    _lastTapId = null;
    _lastTapAt = null;
  }

  void _handleTap(String id) {
    final now = DateTime.now();
    final lastAt = _lastTapAt;
    final isDoubleTap = id == _lastTapId &&
        lastAt != null &&
        now.difference(lastAt) <= _doubleTapWindow;
    _lastTapId = id;
    _lastTapAt = now;
    if (isDoubleTap && _homeOnDoubleTap.contains(id)) {
      resetTapMemory();
      // A bar without onHome is the home screen's own: the first tap already
      // brought the user here (tapping an open module closes it), so the
      // second must not open the module again.
      onHome?.call();
      return;
    }
    onSelect?.call(id);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: context.adaptive(
                    light: const Color(0xFFE5E7EB),
                    dark: p.border,
                  ),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _NavItem(
                    id: 'acads',
                    icon: Icons.menu_book_rounded,
                    tooltip: 'Academics',
                    isSelected: selectedId == 'acads',
                    onTap: () => _handleTap('acads'),
                  ),
                  _NavItem(
                    id: 'gatepass',
                    icon: Icons.badge_outlined,
                    tooltip: 'Gatepass',
                    isSelected: selectedId == 'gatepass',
                    onTap: () => _handleTap('gatepass'),
                  ),
                  _NavItem(
                    id: 'wall',
                    icon: Icons.campaign_outlined,
                    tooltip: 'Wall - Announcements & Circulars',
                    isSelected: selectedId == 'wall',
                    onTap: () => _handleTap('wall'),
                  ),
                  _NavItem(
                    id: 'analysis',
                    icon: Icons.bar_chart_rounded,
                    tooltip: 'Reports & Analysis',
                    isSelected: selectedId == 'analysis',
                    onTap: () => _handleTap('analysis'),
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
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: isSelected
            ? BoxDecoration(
                color: context.adaptive(
                  light: const Color(0xFF7B42F6).withValues(alpha: 0.1),
                  dark: context.palette.brandSoft,
                ),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Icon(
          icon,
          size: 22,
          color: isSelected
              ? context.palette.brandInk
              : context.adaptive(
                  light: const Color(0xFF8E8E93),
                  dark: const Color(0xFF878995),
                ),
        ),
      ),
    );
  }
}
