import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'canteen_surface.dart';

/// Tells shop staff they have no counter yet, and who can fix it. Stands in
/// for the order queue, which would otherwise look like a quiet day.
class UnassignedCounterNotice extends StatelessWidget {
  const UnassignedCounterNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CanteenSurface(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: Column(
          children: [
            Icon(Icons.storefront_outlined, size: 40, color: p.brandInk),
            const SizedBox(height: 12),
            Text(
              'Not assigned to a counter',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: p.inkSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
