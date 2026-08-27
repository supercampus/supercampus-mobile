import 'package:flutter/material.dart';

/// A layout-preserving, light-purple loading surface.
///
/// Keep [width], [height], and [borderRadius] identical to the widget that
/// replaces it. This prevents content jumps when the network response arrives.
class SkeletonBox extends StatefulWidget {
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
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF29223D) : const Color(0xFFEEE9FF);
    final shine = dark ? const Color(0xFF51436D) : const Color(0xFFFCFAFF);

    Widget surface(double progress) => ExcludeSemantics(
      child: RepaintBoundary(
        child: Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-2.5 + (progress * 5), 0),
              end: Alignment(-1.5 + (progress * 5), 0),
              colors: [base, shine, base],
              stops: const [0.18, 0.5, 0.82],
            ),
          ),
        ),
      ),
    );

    if (reduceMotion) return surface(0);
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) => surface(_controller.value),
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

/// Matches the common 68px list/card row used across the mobile portal.
class SkeletonListRow extends StatelessWidget {
  const SkeletonListRow({super.key, this.height = 68});

  final double height;

  @override
  Widget build(BuildContext context) =>
      SkeletonBox(height: height, borderRadius: BorderRadius.circular(14));
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({
    super.key,
    this.rows = 5,
    this.rowHeight = 68,
    this.padding = const EdgeInsets.all(16),
  });

  final int rows;
  final double rowHeight;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: padding,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: rows,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, _) => SkeletonListRow(height: rowHeight),
  );
}

/// Timetable placeholder with the same header-and-period-card rhythm as the
/// published schedule screen.
class TimetableLoadingSkeleton extends StatelessWidget {
  const TimetableLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    physics: const NeverScrollableScrollPhysics(),
    children: [
      const SkeletonLine(width: 176, height: 24, radius: 8),
      const SizedBox(height: 8),
      const SkeletonLine(width: 252),
      const SizedBox(height: 20),
      for (var day = 0; day < 3; day++) ...[
        const SkeletonBox(height: 42),
        const SizedBox(height: 8),
        for (var row = 0; row < 3; row++) ...[
          const SkeletonListRow(height: 76),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
      ],
    ],
  );
}

/// Attendance placeholder that reserves the subject header, summary and exact
/// roster row sizes used after the class data arrives.
class AttendanceLoadingSkeleton extends StatelessWidget {
  const AttendanceLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    physics: const NeverScrollableScrollPhysics(),
    children: [
      const SkeletonBox(height: 104),
      const SizedBox(height: 16),
      Row(
        children: [
          const SkeletonLine(width: 72, height: 18),
          const SizedBox(width: 12),
          const SkeletonLine(width: 62, height: 18),
          const Spacer(),
          const SkeletonLine(width: 42, height: 18),
        ],
      ),
      const SizedBox(height: 18),
      for (var row = 0; row < 7; row++) ...[
        const SkeletonListRow(height: 58),
        const SizedBox(height: 8),
      ],
    ],
  );
}
