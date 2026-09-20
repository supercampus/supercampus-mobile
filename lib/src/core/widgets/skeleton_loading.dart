import 'package:flutter/material.dart';
import 'package:agent_orbs/agent_orbs.dart';

export 'package:agent_orbs/agent_orbs.dart';

/// A centered ThinkingOrb loading indicator (state: working, size: 96 by default).
class ThinkingOrbLoading extends StatelessWidget {
  const ThinkingOrbLoading({
    super.key,
    this.size = 96,
    this.state = OrbState.working,
    this.padding = const EdgeInsets.all(24),
  });

  final double size;
  final OrbState state;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: padding,
        child: ThinkingOrb(
          state: state,
          size: size,
          theme: dark ? OrbTheme.dark : OrbTheme.light,
        ),
      ),
    );
  }
}

/// A loading surface powered by [ThinkingOrb] (state: working).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final orbSize = height >= 96 ? 96.0 : (height >= 64 ? 64.0 : (height >= 40 ? 40.0 : 20.0));
    return SizedBox(
      width: width,
      height: height,
      child: Center(
        child: ThinkingOrb(
          state: OrbState.working,
          size: orbSize,
          theme: dark ? OrbTheme.dark : OrbTheme.light,
        ),
      ),
    );
  }
}

class SkeletonLine extends StatelessWidget {
  const SkeletonLine({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 6,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => SkeletonBox(
    width: width,
    height: height,
    borderRadius: BorderRadius.circular(radius),
  );
}

/// Matches the common 68px list/card row loading placeholder.
class SkeletonListRow extends StatelessWidget {
  const SkeletonListRow({super.key, this.height = 68});

  final double height;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: height,
      child: Center(
        child: ThinkingOrb(
          state: OrbState.working,
          size: height >= 96 ? 96.0 : (height >= 64 ? 64.0 : 40.0),
          theme: dark ? OrbTheme.dark : OrbTheme.light,
        ),
      ),
    );
  }
}

/// Full screen or section loading view featuring the ThinkingOrb in 'working' state (size 96).
class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.rows = 5,
    this.rowHeight = 68,
    this.padding = const EdgeInsets.all(24),
  });

  final int rows;
  final double rowHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: padding,
        child: ThinkingOrb(
          state: OrbState.working,
          size: 96,
          theme: dark ? OrbTheme.dark : OrbTheme.light,
        ),
      ),
    );
  }
}

/// Timetable placeholder powered by ThinkingOrb.
class TimetableLoadingSkeleton extends StatelessWidget {
  const TimetableLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ThinkingOrb(
          state: OrbState.working,
          size: 96,
          theme: dark ? OrbTheme.dark : OrbTheme.light,
        ),
      ),
    );
  }
}

/// Attendance placeholder powered by ThinkingOrb.
class AttendanceLoadingSkeleton extends StatelessWidget {
  const AttendanceLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ThinkingOrb(
          state: OrbState.working,
          size: 96,
          theme: dark ? OrbTheme.dark : OrbTheme.light,
        ),
      ),
    );
  }
}
