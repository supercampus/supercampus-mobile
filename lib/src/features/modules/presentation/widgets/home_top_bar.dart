import 'package:flutter/material.dart';

/// A deliberately quiet home header. Search and AI shortcuts live inside the
/// relevant modules instead of competing with the user's daily information.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.displayName,
    required this.onAlertsTap,
    required this.onSettingsTap,
    this.hasAlerts = false,
  });

  final String displayName;
  final VoidCallback onAlertsTap;
  final VoidCallback onSettingsTap;

  /// Shows the dot on the bell.
  final bool hasAlerts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 14, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good ${_dayPart()},',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  _firstName(displayName),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                    height: 1.02,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          _Bell(onTap: onAlertsTap, showDot: hasAlerts),
          IconButton(
            key: const ValueKey('home-settings'),
            tooltip: 'Settings',
            onPressed: onSettingsTap,
            icon: const Icon(Icons.settings_outlined, size: 24),
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          ),
        ],
      ),
    );
  }

  static String _firstName(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    return parts.isEmpty || parts.first.isEmpty ? 'Campus user' : parts.first;
  }

  static String _dayPart() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }
}

class _Bell extends StatelessWidget {
  const _Bell({required this.onTap, required this.showDot});

  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          key: const ValueKey('home-alerts'),
          tooltip: 'Alerts',
          onPressed: onTap,
          icon: const Icon(Icons.notifications_outlined, size: 26),
          color: Theme.of(context).colorScheme.primary,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        ),
        if (showDot)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
