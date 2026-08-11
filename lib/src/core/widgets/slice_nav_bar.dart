import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One tab in the floating nav bar.
class SliceNavDestination {
  const SliceNavDestination({
    required this.id,
    required this.label,
    required this.icon,
  });

  final String id;
  final String label;
  final IconData icon;
}

/// Floating pill navigation, after the slice payments app.
///
/// Two things make it read as "slice" rather than as a Material
/// [NavigationBar]: it floats over the content instead of sitting in a
/// docked bar, and it is not static — scrolling the page down shrinks it to
/// just the scan button, scrolling back up grows the tabs
/// again. The thumb keeps its primary action at all times while the reading
/// area gets the space back.
///
/// The morph is one animated width, not a swap between two widgets: the tab
/// row is always laid out at full width inside an [OverflowBox] and the pill
/// clips it, so tabs are eaten from the edges inward instead of being
/// squeezed.
class SliceNavBar extends StatefulWidget {
  const SliceNavBar({
    super.key,
    required this.destinations,
    required this.selectedId,
    required this.onSelect,
    this.onCenterTap,
    this.centerIcon = Icons.qr_code_scanner_rounded,
    this.centerTooltip = 'Scan & pay',
    this.collapsed = false,
    this.maxWidth = 420,
    this.collapsedWidth = 196,
    this.duration = const Duration(milliseconds: 320),
  });

  /// Up to four tabs. They are split evenly either side of the scan button.
  final List<SliceNavDestination> destinations;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  /// The raised circle in the middle. Omitted entirely when null.
  final VoidCallback? onCenterTap;
  final IconData centerIcon;
  final String centerTooltip;

  /// Driven by the page's scroll direction.
  final bool collapsed;

  final double maxWidth;
  final double collapsedWidth;
  final Duration duration;

  /// Height the bar occupies, including the part of the scan button that
  /// stands proud of the pill. Callers use it as bottom padding so the last
  /// item of a list can still be read.
  static const double height = 86;

  static const double _pillHeight = 62;
  static const double _centerSize = 62;

  @override
  State<SliceNavBar> createState() => _SliceNavBarState();
}

class _SliceNavBarState extends State<SliceNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.collapsed ? 0 : 1,
  );

  late final Animation<double> _t = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void didUpdateWidget(covariant SliceNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collapsed != oldWidget.collapsed) {
      widget.collapsed ? _controller.reverse() : _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasCenter = widget.onCenterTap != null;

    // Two either side of the scan button; the center action is the scanner.
    final destinations = widget.destinations.take(4).toList();
    // Without the scanner there is no center gap, so all tabs belong to the
    // left group. Keeping the old split made the bar render half-empty and
    // pushed the navigation into the wrong side of the pill.
    final split = hasCenter
        ? (destinations.length + 1) ~/ 2
        : destinations.length;
    final left = destinations.take(split).toList();
    final right = destinations.skip(split).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final expandedWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth - 32).clamp(
                widget.collapsedWidth,
                widget.maxWidth,
              )
            : widget.maxWidth;

        return SizedBox(
          height: SliceNavBar.height,
          child: AnimatedBuilder(
            animation: _t,
            builder: (context, _) {
              final t = _t.value;
              final width =
                  widget.collapsedWidth +
                  (expandedWidth - widget.collapsedWidth) * t;

              return Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  _pill(
                    width: width,
                    expandedWidth: expandedWidth,
                    t: t,
                    left: left,
                    right: right,
                    hasCenter: hasCenter,
                  ),
                  if (hasCenter)
                    Positioned(
                      bottom: 2,
                      child: _CenterButton(
                        icon: widget.centerIcon,
                        tooltip: widget.centerTooltip,
                        onTap: widget.onCenterTap!,
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _pill({
    required double width,
    required double expandedWidth,
    required double t,
    required List<SliceNavDestination> left,
    required List<SliceNavDestination> right,
    required bool hasCenter,
  }) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        height: SliceNavBar._pillHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(SliceNavBar._pillHeight / 2),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        // Laid out at full width whatever the pill is doing, so collapsing
        // clips the tabs away rather than reflowing them.
        child: OverflowBox(
          minWidth: expandedWidth,
          maxWidth: expandedWidth,
          alignment: Alignment.center,
          child: IgnorePointer(
            ignoring: t < 0.5,
            child: Opacity(
              opacity: t,
              child: Row(
                children: [
                  Expanded(child: _group(left)),
                  // Wide enough to clear the scan button's collar, so a tab
                  // never ends up underneath it.
                  if (hasCenter)
                    const SizedBox(width: SliceNavBar._centerSize + 22),
                  Expanded(child: _group(right)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _group(List<SliceNavDestination> destinations) {
    if (destinations.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        for (final d in destinations)
          Expanded(
            child: _NavTab(
              destination: d,
              selected: d.id == widget.selectedId,
              onTap: () => widget.onSelect(d.id),
            ),
          ),
      ],
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final SliceNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return InkResponse(
      key: ValueKey('nav-${destination.id}'),
      onTap: onTap,
      radius: 30,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(destination.icon, size: 23, color: color),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                destination.label.toUpperCase(),
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The scan button. A white collar separates the gradient from the pill so
/// the circle reads as sitting on top of it rather than punched out of it.
class _CenterButton extends StatelessWidget {
  const _CenterButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        key: const ValueKey('nav-center'),
        onTap: onTap,
        child: Container(
          width: SliceNavBar._centerSize + 10,
          height: SliceNavBar._centerSize + 10,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: SliceNavBar._centerSize,
              height: SliceNavBar._centerSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.42),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
