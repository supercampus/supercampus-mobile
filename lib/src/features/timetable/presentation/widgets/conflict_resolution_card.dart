import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/timetable_models.dart';

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
      color: isResolved ? Colors.grey.shade50 : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isResolved
              ? Colors.grey.shade300
              : Colors.red.shade300,
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
                  color: isResolved ? const Color(0xFF2E7D32) : Colors.red,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    conflict.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                          decoration:
                              isResolved ? TextDecoration.lineThrough : null,
                          color: isResolved ? AppColors.muted : AppColors.ink,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isResolved
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isResolved
                          ? Colors.green.shade200
                          : Colors.red.shade200,
                    ),
                  ),
                  child: Text(
                    isResolved ? 'RESOLVED' : '${conflict.severity} SEVERITY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isResolved
                          ? const Color(0xFF2E7D32)
                          : Colors.red.shade800,
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
                color: isResolved ? AppColors.muted : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Conflict Type: ${conflict.type.label}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                if (!isResolved)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00695C),
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
                  const Row(
                    children: [
                      Icon(Icons.done_all, size: 16, color: Color(0xFF2E7D32)),
                      SizedBox(width: 4),
                      Text(
                        'Marked Resolved',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF2E7D32),
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
