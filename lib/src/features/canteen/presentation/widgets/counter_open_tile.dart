import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Whether the counter is taking orders, at the head of its queue.
///
/// Work / Shop lives in the profile; opening and closing the counter is part
/// of running the queue, so it sits with it.
class CounterOpenTile extends StatelessWidget {
  const CounterOpenTile({
    super.key,
    required this.open,
    required this.onChanged,
  });

  final bool open;

  /// Null while a change is in flight.
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: p.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(
              open ? Icons.storefront_rounded : Icons.storefront_outlined,
              color: open ? p.success : p.inkTertiary,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    open ? 'Counter open' : 'Counter closed',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    open ? 'Taking new orders' : 'Not taking new orders',
                    style: TextStyle(fontSize: 12, color: p.inkSecondary),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              key: const ValueKey('counter-open-switch'),
              value: open,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
