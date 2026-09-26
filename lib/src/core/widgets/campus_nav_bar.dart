import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Single item descriptor for custom role-specific navigation tabs in [CampusNavBar].
class CampusNavItem {
  const CampusNavItem({
    required this.id,
    required this.label,
    required this.icon,
    this.selectedIcon,
    required this.onTap,
  });

  final String id;
  final String label;
  final Widget icon;
  final Widget? selectedIcon;
  final VoidCallback onTap;
}

/// The unified navigation bar for staff, operators, and institutional portals.
///
/// Center profile avatar has been removed and replaced by top-right header avatars.
/// QR scanner is strictly restricted to roles that perform scanning actions
/// (canteen owner, stationery operator, laundry owner, captains, security).
class CampusNavBar extends StatefulWidget {
  const CampusNavBar({
    super.key,
    required this.onHome,
    required this.onModules,
    this.onProfile,
    this.onScan,
    this.showScan,
    this.items,
    this.selectedId,
    this.initials = '',
    this.avatarUrl,
  });

  final VoidCallback onHome;
  final VoidCallback onModules;

  /// Deprecated: Profile avatar has been moved to the top right of each screen.
  final VoidCallback? onProfile;

  /// Null leaves the scanner visible but inert, so a permission change never
  /// reflows the bar.
  final VoidCallback? onScan;

  /// Whether to display the Scan QR button on the right.
  /// If null, defaults to whether [onScan] is non-null.
  final bool? showScan;

  /// Optional custom items for role-specific navigation (e.g. Admin, Faculty, Accountant).
  /// If provided, these items are rendered instead of the default Home & Modules tabs.
  final List<CampusNavItem>? items;

  /// `home` or `modules` or item id; anything else leaves tabs unselected.
  final String? selectedId;

  final String initials;

  /// Shown in place of the initials once the platform stores a photo.
  final String? avatarUrl;

  /// 942 / 152, off the board.
  static const double aspect = 942 / 152;

  /// Air either side of the bar, and the widest it may grow before a tablet
  /// would turn it into a banner.
  static const double sideMargin = 16;
  static const double maxWidth = 480;

  /// What the bar occupies at this width. Callers pad the bottom of scrolling
  /// content by this plus the safe area so the last row stays readable.
  static double heightFor(BuildContext context) {
    final width = math.min(
      MediaQuery.sizeOf(context).width - sideMargin * 2,
      maxWidth,
    );
    return math.max(0, width) / aspect;
  }

  @override
  State<CampusNavBar> createState() => _CampusNavBarState();
}

// Colours sampled from the board.
const _scanFrom = Color(0xFF4400FF);
const _scanTo = Color(0xFF9000FF);
const _iconPurple = Color(0xFF5900FF);

/// What the label turns on each pulse.
const _pulseMagenta = Color(0xFFDC00FF);

// Horizontal placement, as a fraction of the bar's width.
const _scanLeftX = 592 / 942;
const _scanWidth = 312 / 942;

/// How much width a tab claims for its tap target: wide enough to hold
/// "Modules" comfortably, narrow enough that the two never meet.
const _tabWidth = 0.17;

// Vertical placement and sizes, as a fraction of the bar's height.
const _glyphSize = 53 / 152;
const _glyphCentreY = 66 / 152;
const _labelCentreY = 109.5 / 152;
const _labelSize = 18 / 152;
const _scanTop = 21 / 152;
const _scanHeight = 115 / 152;
const _scanLabelSize = 26.4 / 152;
const _bracketStroke = 6 / 152;
const _bracketArm = 32 / 152;
const _bracketInset = 9 / 152;

class _CampusNavBarState extends State<CampusNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
    reverseDuration: const Duration(milliseconds: 460),
  );
  Timer? _ticker;

  bool get _effectiveShowScan => widget.showScan ?? (widget.onScan != null);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final quiet = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (quiet || !_effectiveShowScan || widget.onScan == null) {
      _stop();
    } else {
      _start();
    }
  }

  void _start() {
    _ticker ??= Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pulse.forward().then((_) {
        if (mounted) _pulse.reverse();
      }),
    );
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
    _pulse.value = 0;
  }

  @override
  void didUpdateWidget(covariant CampusNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldShow = oldWidget.showScan ?? (oldWidget.onScan != null);
    if ((_effectiveShowScan && widget.onScan != null) !=
        (oldShow && oldWidget.onScan != null)) {
      (_effectiveShowScan && widget.onScan != null) ? _start() : _stop();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: CampusNavBar.sideMargin,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: CampusNavBar.maxWidth),
          child: AspectRatio(
            aspectRatio: CampusNavBar.aspect,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final h = constraints.maxHeight;
                final hasScan = _effectiveShowScan;

                final List<Widget> navChildren = [];

                if (hasScan) {
                  // Right side: Scan Button
                  navChildren.add(
                    Positioned(
                      left: _scanLeftX * w,
                      top: _scanTop * h,
                      width: _scanWidth * w,
                      height: _scanHeight * h,
                      child: _ScanButton(
                        pulse: _pulse,
                        onTap: widget.onScan,
                        barHeight: h,
                      ),
                    ),
                  );

                  // Left area (width: _scanLeftX * w)
                  if (widget.items != null && widget.items!.isNotEmpty) {
                    final count = widget.items!.length;
                    for (int i = 0; i < count; i++) {
                      final item = widget.items![i];
                      final centreX = (_scanLeftX * (i + 0.5)) / count;
                      navChildren.add(
                        _tab(
                          w: w,
                          h: h,
                          centreX: centreX,
                          id: item.id,
                          label: item.label,
                          icon: item.icon,
                          selectedIcon: item.selectedIcon,
                          onTap: item.onTap,
                          customWidth: (_scanLeftX * w) / count,
                        ),
                      );
                    }
                  } else {
                    // Default Home & Modules spaced cleanly in left zone
                    navChildren.add(
                      _tab(
                        w: w,
                        h: h,
                        centreX: _scanLeftX * 0.30,
                        id: 'home',
                        label: 'Home',
                        icon: Icon(
                          widget.selectedId == 'home'
                              ? Icons.home_rounded
                              : Icons.home_outlined,
                        ),
                        onTap: widget.onHome,
                      ),
                    );
                    navChildren.add(
                      _tab(
                        w: w,
                        h: h,
                        centreX: _scanLeftX * 0.72,
                        id: 'modules',
                        label: 'Modules',
                        icon: CampusNavCubeGlyph(
                          filled: widget.selectedId == 'modules',
                        ),
                        onTap: widget.onModules,
                      ),
                    );
                  }
                } else {
                  // No scan button: Full width w used
                  if (widget.items != null && widget.items!.isNotEmpty) {
                    final count = widget.items!.length;
                    for (int i = 0; i < count; i++) {
                      final item = widget.items![i];
                      final centreX = (i + 0.5) / count;
                      navChildren.add(
                        _tab(
                          w: w,
                          h: h,
                          centreX: centreX,
                          id: item.id,
                          label: item.label,
                          icon: item.icon,
                          selectedIcon: item.selectedIcon,
                          onTap: item.onTap,
                          customWidth: w / count,
                        ),
                      );
                    }
                  } else {
                    // Default: Home and Modules spaced across width
                    navChildren.add(
                      _tab(
                        w: w,
                        h: h,
                        centreX: 0.30,
                        id: 'home',
                        label: 'Home',
                        icon: Icon(
                          widget.selectedId == 'home'
                              ? Icons.home_rounded
                              : Icons.home_outlined,
                        ),
                        onTap: widget.onHome,
                      ),
                    );
                    navChildren.add(
                      _tab(
                        w: w,
                        h: h,
                        centreX: 0.70,
                        id: 'modules',
                        label: 'Modules',
                        icon: CampusNavCubeGlyph(
                          filled: widget.selectedId == 'modules',
                        ),
                        onTap: widget.onModules,
                      ),
                    );
                  }
                }

                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(h / 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: h * 0.30,
                        offset: Offset(0, h * 0.10),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: navChildren,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab({
    required double w,
    required double h,
    required double centreX,
    required String id,
    required String label,
    required Widget icon,
    Widget? selectedIcon,
    required VoidCallback onTap,
    double? customWidth,
  }) {
    final width = customWidth ?? (_tabWidth * w);
    final glyph = _glyphSize * h;
    final selected = widget.selectedId == id;
    final inactiveColor = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: .58);
    final displayIcon = (selected && selectedIcon != null) ? selectedIcon : icon;

    return Positioned(
      left: centreX * w - width / 2,
      top: 0,
      width: width,
      height: h,
      child: InkResponse(
        key: ValueKey('nav-$id'),
        onTap: onTap,
        containedInkWell: false,
        radius: width / 2,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: _glyphCentreY * h - glyph / 2,
              height: glyph,
              child: IconTheme(
                data: IconThemeData(
                  color: selected ? _iconPurple : inactiveColor,
                  size: glyph,
                ),
                child: Center(child: displayIcon),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: _labelCentreY * h - _labelSize * h * 0.6,
              child: Center(
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected
                        ? Theme.of(context).colorScheme.onSurface
                        : inactiveColor,
                    fontSize: _labelSize * h,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The board's Modules glyph: an isometric cube.
class CampusNavCubeGlyph extends StatelessWidget {
  const CampusNavCubeGlyph({super.key, required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = theme.size ?? 24;
    return CustomPaint(
      size: Size.square(size),
      painter: _CubePainter(
        color: theme.color ?? _iconPurple,
        seam: Theme.of(context).colorScheme.surface,
        filled: filled,
      ),
    );
  }
}

class _CubePainter extends CustomPainter {
  const _CubePainter({
    required this.color,
    required this.seam,
    required this.filled,
  });

  final Color color;
  final Color seam;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.width / 2;
    Offset at(double degrees) {
      final radians = degrees * math.pi / 180;
      return centre + Offset(math.cos(radians), -math.sin(radians)) * radius;
    }

    final hexagon = Path()
      ..addPolygon([for (var i = 0; i < 6; i++) at(90 + i * 60.0)], true);
    if (filled) {
      canvas.drawPath(hexagon, Paint()..color = color);
    } else {
      canvas.drawPath(
        hexagon,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.085
          ..strokeJoin = StrokeJoin.round,
      );
    }

    final pen = Paint()
      ..color = filled ? seam : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round;
    for (final angle in [90.0, 210.0, 330.0]) {
      canvas.drawLine(centre, at(angle), pen);
    }
  }

  @override
  bool shouldRepaint(_CubePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.seam != seam ||
      oldDelegate.filled != filled;
}

/// The scanner: a gradient slab framed by viewfinder corners.
class _ScanButton extends StatelessWidget {
  const _ScanButton({
    required this.pulse,
    required this.onTap,
    required this.barHeight,
  });

  final Animation<double> pulse;
  final VoidCallback? onTap;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final h = barHeight;

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Scan QR code',
      child: InkResponse(
        key: const ValueKey('nav-scan'),
        onTap: onTap,
        containedInkWell: false,
        child: AnimatedBuilder(
          animation: pulse,
          builder: (context, _) {
            final t = pulse.value;
            final arm = (_bracketArm + t * 0.035) * h;
            final inset = (_bracketInset - t * 0.02) * h;
            final bracketColor = Color.lerp(Colors.white, _pulseMagenta, t)!;

            return CustomPaint(
              foregroundPainter: _ViewfinderPainter(
                stroke: _bracketStroke * h,
                arm: arm,
                inset: inset,
                color: bracketColor,
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_scanHeight * h / 2),
                  gradient: const LinearGradient(
                    colors: [_scanFrom, _scanTo],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _scanTo.withValues(alpha: 0.35),
                      blurRadius: h * 0.20,
                      offset: Offset(0, h * 0.06),
                    ),
                  ],
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Colors.white,
                        size: _scanLabelSize * h * 1.05,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Scan',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _scanLabelSize * h * 0.9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter({
    required this.stroke,
    required this.arm,
    required this.inset,
    required this.color,
  });

  final double stroke;
  final double arm;
  final double inset;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;

    final rect = Rect.fromLTRB(
      inset + stroke / 2,
      inset + stroke / 2,
      size.width - inset - stroke / 2,
      size.height - inset - stroke / 2,
    );

    void corner(Offset at, double dx, double dy) {
      final radius = arm * 0.72;
      canvas.drawPath(
        Path()
          ..moveTo(at.dx + dx * arm, at.dy)
          ..lineTo(at.dx + dx * radius, at.dy)
          ..quadraticBezierTo(at.dx, at.dy, at.dx, at.dy + dy * radius)
          ..lineTo(at.dx, at.dy + dy * arm),
        paint,
      );
    }

    corner(rect.topLeft, 1, 1);
    corner(rect.topRight, -1, 1);
    corner(rect.bottomLeft, 1, -1);
    corner(rect.bottomRight, -1, -1);
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) =>
      oldDelegate.inset != inset ||
      oldDelegate.color != color ||
      oldDelegate.stroke != stroke ||
      oldDelegate.arm != arm;
}
