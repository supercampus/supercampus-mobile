import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/timetable_models.dart';
import '../timetable_tones.dart';

class ConflictResolutionCard extends StatelessWidget {
  const ConflictResolutionCard({
    super.key,
    required this.conflict,
    required this.onResolve,
  });

  final ConflictItem conflict;
  final VoidCallback onResolve;

  @override
  Widget build(BuildContext context) {
    final isResolved = conflict.isResolved;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: isResolved ? context.grey(50) : context.palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isResolved
              ? context.grey(300)
              : Colors.red.shade300.tintOn(context, alpha: .45),
          width: isResolved ? 1 : 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isResolved ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: isResolved
                      ? const Color(0xFF2E7D32).inkOn(context)
                      : Colors.red.inkOn(context),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    conflict.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      decoration: isResolved
                          ? TextDecoration.lineThrough
                          : null,
                      color: isResolved
                          ? context.palette.inkSecondary
                          : context.palette.ink,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isResolved
                        ? Colors.green.shade50.tintOn(context)
                        : Colors.red.shade50.tintOn(context),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isResolved
                          ? Colors.green.shade200.tintOn(context, alpha: .45)
                          : Colors.red.shade200.tintOn(context, alpha: .45),
                    ),
                  ),
                  child: Text(
                    isResolved ? 'RESOLVED' : '${conflict.severity} SEVERITY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isResolved
                          ? const Color(0xFF2E7D32).inkOn(context)
                          : Colors.red.shade800.inkOn(context),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              conflict.description,
              style: TextStyle(
                fontSize: 13,
                color: isResolved
                    ? context.palette.inkSecondary
                    : context.adaptive(
                        light: Colors.black87,
                        dark: const Color(0xFFD9DAE0),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Conflict Type: ${conflict.type.label}',
                  style: TextStyle(
                    fontSize: 11,
                    color: context.palette.inkSecondary,
                  ),
                ),
                if (!isResolved)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: context.palette.brand,
                      foregroundColor: context.palette.onBrand,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                    ),
                    onPressed: onResolve,
                    icon: const Icon(Icons.build_outlined, size: 16),
                    label: const Text('Resolve Conflict'),
                  )
                else
                  Row(
                    children: [
                      Icon(
                        Icons.done_all,
                        size: 16,
                        color: const Color(0xFF2E7D32).inkOn(context),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Marked Resolved',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF2E7D32).inkOn(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
