import 'package:flutter/material.dart';


/// Sparkle · search · bell, the strip that sits above everything on the home
/// screen. The search field is a button rather than a live [TextField] — the
/// query is typed in the sheet it opens, so the strip never has to give up
/// its height to a keyboard.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({
    super.key,
    required this.onSparkleTap,
    required this.onSearchTap,
    required this.onAlertsTap,
    this.hasAlerts = false,
    this.hint = 'search anything',
  });

  final VoidCallback onSparkleTap;
  final VoidCallback onSearchTap;
  final VoidCallback onAlertsTap;

  /// Shows the dot on the bell.
  final bool hasAlerts;

  final String hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _Sparkle(onTap: onSparkleTap),
          const SizedBox(width: 12),
          Expanded(
            child: _SearchField(hint: hint, onTap: onSearchTap),
          ),
          const SizedBox(width: 8),
          _Bell(onTap: onAlertsTap, showDot: hasAlerts),
        ],
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('home-insights'),
      tooltip: 'What matters now',
      onPressed: onTap,
      icon: const Icon(Icons.auto_awesome, size: 26),
      color: Theme.of(context).colorScheme.primary,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        key: const ValueKey('home-search'),
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
              Icon(
                Icons.search,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
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
