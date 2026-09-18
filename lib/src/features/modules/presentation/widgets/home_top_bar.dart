import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.displayName,
    required this.onAlertsTap,
    required this.onSettingsTap,
    this.hasAlerts = false,
    this.photoUrl,
  });

  final String displayName;
  final VoidCallback onAlertsTap;
  final VoidCallback onSettingsTap;
  final bool hasAlerts;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _Bell(onTap: onAlertsTap, showDot: hasAlerts),
          GestureDetector(
            onTap: onSettingsTap,
            child: CircleAvatar(
              radius: 22,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
              child: photoUrl == null
                  ? const Icon(Icons.person, size: 24, color: Colors.grey)
                  : null,
            ),
          ),
        ],
      ),
    );
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
          icon: const Icon(Icons.notifications, size: 26),
          color: Theme.of(context).colorScheme.onSurface,
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
