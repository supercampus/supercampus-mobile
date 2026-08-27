import 'package:flutter/material.dart';

/// A deliberately quiet home header. Search and AI shortcuts live inside the
/// relevant modules instead of competing with the user's daily information.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.onAlertsTap,
    this.hasAlerts = false,
  });

  final VoidCallback onAlertsTap;

  /// Shows the dot on the bell.
  final bool hasAlerts;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 2),
      child: Align(
        alignment: Alignment.centerRight,
        child: _Bell(onTap: onAlertsTap, showDot: hasAlerts),
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
