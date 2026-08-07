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
/// just the scan button and your avatar, scrolling back up grows the tabs
/// again. The thumb keeps its primary action at all times while the reading
/// area gets the space back.
///
/// The morph is one animated width, not a swap between two widgets: the tab
/// row is always laid out at full width inside an [OverflowBox] and the pill
/// clips it, so tabs are eaten from the edges inward instead of being
/// squeezed. The scan button and avatar are positioned against the *live*
/// pill width, so they ride the edge in as it closes.
class SliceNavBar extends StatefulWidget {
  const SliceNavBar({
    super.key,
    required this.destinations,
    required this.selectedId,
    required this.onSelect,
    required this.avatarInitials,
    required this.onAvatarTap,
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

  final String avatarInitials;
  final VoidCallback onAvatarTap;

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
  static const double _avatarSize = 42;
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

    // Two either side of the scan button; a fifth tab would crowd the pill
    // more than it would help.
    final destinations = widget.destinations.take(4).toList();
    final split = hasCenter ? (destinations.length + 1) ~/ 2 : 0;
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
              final width = widget.collapsedWidth +
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
                  // Rides the closing edge of the pill.
                  Positioned(
                    bottom:
                        (SliceNavBar._pillHeight - SliceNavBar._avatarSize) / 2,
                    child: Transform.translate(
                      offset: Offset(
                        width / 2 - SliceNavBar._avatarSize / 2 - 10,
                        0,
                      ),
                      child: _Avatar(
                        initials: widget.avatarInitials,
                        onTap: widget.onAvatarTap,
                      ),
                    ),
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
    return Container(
      width: width,
      height: SliceNavBar._pillHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(SliceNavBar._pillHeight / 2),
        border: Border.all(color: AppColors.border),
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
                // Keeps a tab from sliding under the avatar.
                const SizedBox(width: SliceNavBar._avatarSize + 14),
              ],
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
    final color = selected ? AppColors.violet : AppColors.muted;

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
            // Only the current tab is named. Four labels at phone width read
            // as a row of truncated stubs, and the icon already carries the
            // meaning for the places you are not.
            if (selected) ...[
              const SizedBox(height: 3),
              Text(
                destination.label,
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
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
          decoration: const BoxDecoration(
            color: AppColors.canvas,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: SliceNavBar._centerSize,
              height: SliceNavBar._centerSize,
              decoration: BoxDecoration(
                gradient: AppColors.violetGradient,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.violet.withValues(alpha: 0.42),
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials, required this.onTap});

  final String initials;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const ValueKey('nav-avatar'),
      onTap: onTap,
      child: Container(
        width: SliceNavBar._avatarSize,
        height: SliceNavBar._avatarSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.ink,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
