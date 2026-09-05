import 'package:flutter/material.dart';
import '../../../core/widgets/skeleton_loading.dart';

import '../../../core/access/academic_presentation.dart';
import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';
import '../../../core/theme/app_theme.dart';

/// What a person's day is made of.
///
/// Not a role. A student's day is a sequence of things arriving, a teacher's is
/// a list of rolls to take, a head's is a set of exceptions to look at, and a
/// counter's is a queue moving. Those are four different questions, so they get
/// four different answers rather than one grid of tiles with different numbers
/// in it.
enum DayShape {
  /// Nothing granted that has a today.
  none,

  /// Their own day, in the order it happens.
  learner,

  /// The rolls they have to take.
  teaching,

  /// What needs looking at across their reach.
  oversight,

  /// The queue in front of them right now.
  counter,
}

/// Derived from grants and scope, never from a role name — the same rule the
/// rest of the app follows. A tenant can rename or split its roles and this
/// keeps working.
DayShape dayShapeFor(EffectivePermissions permissions) {
  // Someone who can change a menu or move orders runs a counter, whatever the
  // tenant calls them. Checked first because a shop owner holds nothing
  // academic and would otherwise fall through to `none`.
  final runsCounter =
      permissions.can(ModuleCatalog.canteen, 'orders', 'manage') ||
      permissions.can(ModuleCatalog.canteen, 'menu', ModuleActions.create) ||
      permissions.can(ModuleCatalog.canteen, 'menu', ModuleActions.update);
  if (runsCounter) return DayShape.counter;

  // Taking a roll is a section-level act. Wider reach means reviewing rolls
  // rather than taking them, which is a different day.
  final takesRolls =
      permissions.can(
        ModuleCatalog.attendance,
        'session',
        ModuleActions.create,
      ) ||
      permissions.can(ModuleCatalog.attendance, 'roster', ModuleActions.update);
  if (takesRolls &&
      permissions.scopeFor(ModuleCatalog.attendance) ==
          PermissionScope.section) {
    return DayShape.teaching;
  }

  return switch (academicPresentationFor(permissions)) {
    AcademicPresentation.staff => DayShape.oversight,
    AcademicPresentation.learner => DayShape.learner,
    AcademicPresentation.none => DayShape.none,
  };
}

/// The heading each shape carries. Direct and specific, because a name that
/// says what is under it is what makes a screen predictable.
String glanceTitleFor(DayShape shape) => switch (shape) {
  DayShape.learner => '',
  DayShape.teaching => 'Your classes today',
  DayShape.oversight => 'Needs your attention',
  DayShape.counter => 'At the counter',
  DayShape.none => '',
};

/// A short, locale-neutral label for the device's current weekday.
///
/// The timetable currently uses the same English weekday names, so keeping
/// this label in that vocabulary makes the dashboard and schedule agree.
String weekdayLabelFor(int weekday) => switch (weekday) {
  DateTime.monday => 'Monday',
  DateTime.tuesday => 'Tuesday',
  DateTime.wednesday => 'Wednesday',
  DateTime.thursday => 'Thursday',
  DateTime.friday => 'Friday',
  DateTime.saturday => 'Saturday',
  DateTime.sunday => 'Sunday',
  _ => '',
};

/// One class a teacher has to take a roll for.
@immutable
class TodayClass {
  const TodayClass({
    required this.subject,
    required this.section,
    required this.rollTaken,
    this.timetableEntryId = '',
    this.subjectOfferingId = '',
    this.sectionId = '',
    this.periodLabel = '',
  });

  final String subject;
  final String section;
  final bool rollTaken;

  /// Stable allocation keys carried into Attendance when this row is tapped.
  /// Display text is not an identity: the same subject can be taught to more
  /// than one section, and the same section can meet more than once a day.
  final String timetableEntryId;
  final String subjectOfferingId;
  final String sectionId;
  final String periodLabel;
}

/// How many sessions the streak on the learner's Academics card shows.
///
/// Shared with the card that draws it: the strip renders exactly this many
/// marks, so whoever fills it has to supply the same number of most-recent
/// sessions or the ends would not line up.
const attendanceStreakLength = 7;

/// A published attendance result for one class period.
enum AttendanceMark { present, absent, onDuty }

/// A learner's attendance standing.
@immutable
class AttendanceStanding {
  const AttendanceStanding({
    required this.percentage,
    required this.attended,
    required this.total,
    this.streak = const [],
  });

  final int percentage;
  final int attended;
  final int total;

  /// The learner's most recent sessions, oldest first, for the strip on their
  /// Academics card: the latest seven subject rolls, oldest to newest. Null
  /// positions left-pad a history containing fewer than seven rolls.
  final List<AttendanceMark?> streak;

  /// Nothing has been published yet, so a percentage would be a fiction.
  bool get isUnrecorded => total == 0;
}

/// One number on the oversight band.
@immutable
class OversightStat {
  const OversightStat({
    required this.label,
    required this.value,
    required this.moduleId,
    this.urgent = false,
  });

  final String label;
  final String value;
  final String moduleId;

  /// Draws attention only when it is genuinely asking for something.
  final bool urgent;
}

/// The queue in front of a counter.
@immutable
class CounterQueue {
  const CounterQueue({
    required this.waiting,
    required this.preparing,
    required this.ready,
  });

  final int waiting;
  final int preparing;
  final int ready;

  int get total => waiting + preparing + ready;
}

/// Everything the glance is allowed to show, loaded once.
///
/// Every field is nullable or empty by default: a shape with nothing to report
/// says so rather than inventing a number. The dashboard used to render
/// `74%`, `8.42` and `₹18,500` for every account regardless of what was true.
@immutable
class GlanceFacts {
  const GlanceFacts({
    this.standing,
    this.classes = const [],
    this.stats = const [],
    this.queue,
    this.loading = false,
  });

  final AttendanceStanding? standing;
  final List<TodayClass> classes;
  final List<OversightStat> stats;
  final CounterQueue? queue;
  final bool loading;

  static const empty = GlanceFacts();
  static const pending = GlanceFacts(loading: true);
}

/// The day, in the shape the viewer's day actually has.
class TodayGlance extends StatelessWidget {
  const TodayGlance({
    super.key,
    required this.permissions,
    required this.facts,
    required this.onOpenModule,
    this.onOpenClass,
    this.date,
  });

  final EffectivePermissions permissions;
  final GlanceFacts facts;
  final ValueChanged<String> onOpenModule;
  final ValueChanged<TodayClass>? onOpenClass;

  /// The day represented by this dashboard. Production uses the device's
  /// local date; tests and previews may supply a stable value.
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    final shape = dayShapeFor(permissions);
    if (shape == DayShape.none) return const SizedBox.shrink();

    final body = switch (shape) {
      DayShape.learner => _LearnerDay(
        standing: facts.standing,
        loading: facts.loading,
        onOpenModule: onOpenModule,
        permissions: permissions,
      ),
      DayShape.teaching => _TeachingDay(
        classes: facts.classes,
        loading: facts.loading,
        onOpenModule: onOpenModule,
        onOpenClass: onOpenClass,
      ),
      DayShape.oversight => _OversightDay(
        stats: facts.stats,
        loading: facts.loading,
        onOpenModule: onOpenModule,
      ),
      DayShape.counter => _CounterDay(
        queue: facts.queue,
        loading: facts.loading,
        onOpenModule: onOpenModule,
      ),
      DayShape.none => const SizedBox.shrink(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (shape == DayShape.teaching)
          _WeekdayLabel(weekdayLabelFor((date ?? DateTime.now()).weekday)),
        if (glanceTitleFor(shape).isNotEmpty)
          _GlanceLabel(glanceTitleFor(shape)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: body,
        ),
      ],
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
      ),
    ),
  );
}

// ---------------------------------------------------------------- learner --

/// A learner's day reads down, in the order things happen to them — not as a
/// board of statistics about themselves.
class _LearnerDay extends StatelessWidget {
  const _LearnerDay({
    required this.standing,
    required this.loading,
    required this.onOpenModule,
    required this.permissions,
  });

  final AttendanceStanding? standing;
  final bool loading;
  final ValueChanged<String> onOpenModule;
  final EffectivePermissions permissions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (loading) return const _GlanceLoading();

    final rows = <Widget>[];

    if (standing != null) {
      final value = standing!;
      rows.add(
        _DayRow(
          leading: _StandingRing(standing: value),
          headline: value.isUnrecorded
              ? 'No attendance recorded yet'
              : '${value.percentage}% attendance',
          supporting: value.isUnrecorded
              ? 'Your first class of the term has not been marked'
              : '${value.attended} of ${value.total} classes attended',
          onTap: () => onOpenModule(ModuleCatalog.academics),
        ),
      );
    }

    if (permissions.can(
      ModuleCatalog.gatepass,
      'outpass',
      ModuleActions.create,
    )) {
      rows.add(
        _DayRow(
          leading: const _DayIcon(Icons.directions_walk_outlined),
          headline: 'Gatepass',
          supporting: 'Request an outpass or check one you raised',
          onTap: () => onOpenModule(ModuleCatalog.gatepass),
        ),
      );
    }

    if (permissions.can(ModuleCatalog.canteen, 'order', ModuleActions.create)) {
      rows.add(
        _DayRow(
          leading: const _DayIcon(Icons.restaurant_outlined),
          headline: 'Campus shops',
          supporting: 'Order ahead and pick up without queueing',
          onTap: () => onOpenModule(ModuleCatalog.canteen),
        ),
      );
    }

    if (rows.isEmpty) {
      return _GlanceEmpty(
        icon: Icons.wb_sunny_outlined,
        message: 'Nothing needs you right now',
        style: theme.textTheme.bodyMedium,
      );
    }

    return Column(children: rows);
  }
}

class _StandingRing extends StatelessWidget {
  const _StandingRing({required this.standing});

  final AttendanceStanding standing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Below three quarters is the point at which attendance starts to cost a
    // student something, so that is where the colour changes.
    final short = !standing.isUnrecorded && standing.percentage < 75;
    final colour = standing.isUnrecorded
        ? theme.colorScheme.outline
        : short
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: standing.isUnrecorded ? 0 : standing.percentage / 100,
              strokeWidth: 4,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(colour),
            ),
          ),
          Text(
            standing.isUnrecorded ? '—' : '${standing.percentage}',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: colour,
            ),
          ),
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- teaching --

/// A teacher's day is a list of rolls to take, so it is drawn as one: what is
/// done, what is not, and how much is left.
class _TeachingDay extends StatelessWidget {
  const _TeachingDay({
    required this.classes,
    required this.loading,
    required this.onOpenModule,
    required this.onOpenClass,
  });

  final List<TodayClass> classes;
  final bool loading;
  final ValueChanged<String> onOpenModule;
  final ValueChanged<TodayClass>? onOpenClass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (loading) return const _GlanceLoading();

    if (classes.isEmpty) {
      return _GlanceEmpty(
        icon: Icons.class_outlined,
        message: 'No classes assigned to you yet',
        style: theme.textTheme.bodyMedium,
      );
    }

    final taken = classes.where((c) => c.rollTaken).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            taken == classes.length
                ? 'All ${classes.length} rolls taken'
                : '$taken of ${classes.length} rolls taken',
            style: theme.textTheme.titleMedium?.copyWith(letterSpacing: -0.2),
          ),
        ),
        for (final entry in classes)
          _DayRow(
            leading: _RollState(taken: entry.rollTaken),
            headline: entry.subject,
            supporting: entry.section,
            trailing: entry.rollTaken
                ? null
                : Text(
                    'Take roll',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
            onTap: () {
              final openClass = onOpenClass;
              if (openClass != null) {
                openClass(entry);
              } else {
                onOpenModule(ModuleCatalog.attendance);
              }
            },
          ),
      ],
    );
  }
}

class _RollState extends StatelessWidget {
  const _RollState({required this.taken});

  final bool taken;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: taken
                ? theme.colorScheme.primary
                : theme.colorScheme.surfaceContainerHighest,
          ),
          child: Icon(
            taken ? Icons.check_rounded : Icons.radio_button_unchecked,
            size: 16,
            color: taken
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- oversight --

/// Reach means volume, and volume is only interesting where it is out of line.
/// A band of numbers, with the ones asking for something marked.
class _OversightDay extends StatelessWidget {
  const _OversightDay({
    required this.stats,
    required this.loading,
    required this.onOpenModule,
  });

  final List<OversightStat> stats;
  final bool loading;
  final ValueChanged<String> onOpenModule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (loading) return const _GlanceLoading();

    if (stats.isEmpty) {
      return _GlanceEmpty(
        icon: Icons.done_all_outlined,
        message: 'Nothing is waiting on you',
        style: theme.textTheme.bodyMedium,
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final stat in stats)
          _StatChip(stat: stat, onTap: () => onOpenModule(stat.moduleId)),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.stat, required this.onTap});

  final OversightStat stat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = stat.urgent
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    return Material(
      color: stat.urgent
          ? theme.colorScheme.errorContainer.withValues(alpha: 0.45)
          : theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                stat.value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  // Tighter as it grows.
                  letterSpacing: -0.5,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stat.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- counter --

/// A counter cares about one thing: how many are waiting, and how far along.
/// A single strip that can be read from arm's length while serving.
class _CounterDay extends StatelessWidget {
  const _CounterDay({
    required this.queue,
    required this.loading,
    required this.onOpenModule,
  });

  final CounterQueue? queue;
  final bool loading;
  final ValueChanged<String> onOpenModule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (loading) return const _GlanceLoading();

    final value = queue;
    if (value == null || value.total == 0) {
      return _GlanceEmpty(
        icon: Icons.coffee_outlined,
        message: 'No orders waiting',
        style: theme.textTheme.bodyMedium,
      );
    }

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onOpenModule(ModuleCatalog.canteen),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              _QueueStep(
                count: value.waiting,
                label: 'Waiting',
                colour: theme.colorScheme.error,
              ),
              _QueueArrow(),
              _QueueStep(
                count: value.preparing,
                label: 'Preparing',
                colour: theme.colorScheme.tertiary,
              ),
              _QueueArrow(),
              _QueueStep(
                count: value.ready,
                label: 'Ready',
                colour: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueStep extends StatelessWidget {
  const _QueueStep({
    required this.count,
    required this.label,
    required this.colour,
  });

  final int count;
  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            '$count',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: count == 0 ? theme.colorScheme.outline : colour,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Icon(
      Icons.chevron_right_rounded,
      size: 18,
      color: Theme.of(context).colorScheme.outlineVariant,
    ),
  );
}

// ----------------------------------------------------------------- shared --

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.leading,
    required this.headline,
    required this.supporting,
    required this.onTap,
    this.trailing,
  });

  final Widget leading;
  final String headline;
  final String supporting;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        headline,
                        style: theme.textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        supporting,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayIcon extends StatelessWidget {
  const _DayIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.moduleSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, size: 22, color: AppColors.brandBlue),
    );
  }
}

class _GlanceLoading extends StatelessWidget {
  const _GlanceLoading();

  @override
  Widget build(BuildContext context) => const Column(
    children: [
      SkeletonListRow(),
      SizedBox(height: 8),
      SkeletonListRow(),
      SizedBox(height: 8),
      SkeletonListRow(),
    ],
  );
}

class _GlanceEmpty extends StatelessWidget {
  const _GlanceEmpty({
    required this.icon,
    required this.message,
    required this.style,
  });

  final IconData icon;
  final String message;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: style?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlanceLabel extends StatelessWidget {
  const _GlanceLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    ),
  );
}
