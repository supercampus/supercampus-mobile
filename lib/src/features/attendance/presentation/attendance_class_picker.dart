import 'package:flutter/material.dart';

import '../../../core/motion/app_motion.dart';
import '../../../core/motion/app_springs.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/skeleton_loading.dart';

/// Which class is being marked.
///
/// A section belongs to a student, not to a teacher: staff reach a section by
/// teaching an offering in it, so the class is a choice rather than something
/// read off the session. This stays on screen while marking, because a roster
/// with no class above it is a roster of nobody in particular.
class ClassHeader extends StatelessWidget {
  const ClassHeader({
    super.key,
    required this.chosen,
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final Map<String, dynamic>? chosen;
  final int count;
  final bool expanded;

  /// Null while a session is open — switching class then would discard marks
  /// that were never published.
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = chosen?['subjectName']?.toString() ?? 'Choose a class';
    final section = chosen?['sectionName']?.toString() ?? '';
    final code = chosen?['subjectCode']?.toString() ?? '';
    final period = chosen?['periodLabel']?.toString() ?? '';
    // One class is not a choice, so it is stated rather than offered.
    final switchable = count > 1 && onToggle != null;

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: switchable ? onToggle : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.fact_check_outlined,
                  color: theme.colorScheme.primary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ACTIVE CLASS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subject,
                      // Tracking is size-specific: large text reads too loose
                      // at the default, so it tightens as it grows.
                      style: theme.textTheme.titleLarge?.copyWith(
                        letterSpacing: -0.4,
                        height: 1.1,
                      ),
                    ),
                    if (section.isNotEmpty ||
                        code.isNotEmpty ||
                        period.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          if (section.isNotEmpty)
                            _ClassDetailChip(label: section),
                          if (code.isNotEmpty) _ClassDetailChip(label: code),
                          if (period.isNotEmpty)
                            _ClassDetailChip(label: period, emphasized: true),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (switchable)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Change', style: theme.textTheme.labelLarge),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: prefersReducedMotion(context)
                          ? Duration.zero
                          : AppMotion.fast,
                      curve: AppMotion.curve,
                      child: const Icon(Icons.expand_more),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClassDetailChip extends StatelessWidget {
  const _ClassDetailChip({required this.label, this.emphasized = false});

  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: emphasized
            ? theme.colorScheme.primary.withValues(alpha: 0.11)
            : theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: emphasized
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
          fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    );
  }
}

class ClassOption extends StatelessWidget {
  const ClassOption({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected
          ? theme.colorScheme.secondaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option['subjectName']?.toString() ?? 'Class',
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      option['sectionName']?.toString() ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where the roll stands, in the three numbers that matter.
///
/// A class is present until told otherwise, so the two exceptions are what the
/// teacher is actually tracking; present is derived and stays quiet.
class RollTally extends StatelessWidget {
  const RollTally({
    super.key,
    required this.present,
    required this.absent,
    required this.onDuty,
    required this.onReset,
  });

  final int present;
  final int absent;
  final int onDuty;

  /// Null when nothing has been marked, so there is nothing to undo.
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 14,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Count(value: present, label: 'present'),
              if (absent > 0)
                _Count(
                  value: absent,
                  label: 'absent',
                  color: const Color(0xFFB42318),
                ),
              if (onDuty > 0)
                _Count(value: onDuty, label: 'on duty', color: AppColors.amber),
            ],
          ),
        ),
        if (onReset != null)
          TextButton(onPressed: onReset, child: const Text('Reset')),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label, this.color});

  final int value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: color ?? theme.colorScheme.onSurface,
            ),
          ),
          TextSpan(
            text: ' $label',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Staff with no teaching assignment. Section-scoped access resolves to nothing
/// at all in that case, so the screen has to say why rather than show an empty
/// roster.
class ClassesEmptyState extends StatelessWidget {
  const ClassesEmptyState({super.key, required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (busy) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            SkeletonListRow(height: 72),
            SizedBox(height: 8),
            SkeletonListRow(height: 72),
            SizedBox(height: 8),
            SkeletonListRow(height: 72),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 8),
      child: Column(
        children: [
          Icon(
            Icons.class_outlined,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text('No classes assigned yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Attendance is marked against a class you teach. Once a subject '
            'offering is assigned to you, it appears here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
