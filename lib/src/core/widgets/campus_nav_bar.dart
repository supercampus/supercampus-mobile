import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The one navigation bar every surface uses.
///
/// It replaced two bars that used to overlap: a floating pill from the module
/// host and a docked [NavigationBar] declared by individual module screens. A
/// screen inside the host must not declare its own — its sections belong at the
/// top of the page, not in a second bar underneath this one.
///
/// Every measurement below is taken off the design board, which draws the bar
/// at 942 x 152. They are written as fractions of that, and the bar keeps the
/// board's proportion at any width, so the layout is the artwork's own rather
/// than an approximation of it.
class CampusNavBar extends StatefulWidget {
  const CampusNavBar({
    super.key,
    required this.onHome,
    required this.onModules,
    required this.onProfile,
    this.onScan,
    this.selectedId,
    this.initials = '',
    this.avatarUrl,
  });

  final VoidCallback onHome;
  final VoidCallback onModules;
  final VoidCallback onProfile;

  /// Null leaves the scanner visible but inert, so a permission change never
  /// reflows the bar.
  final VoidCallback? onScan;

  /// `home` or `modules`; anything else leaves both unselected.
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
const _ringPurple = Color(0xFF4C00FF);

/// What the label turns on each pulse.
const _pulseMagenta = Color(0xFFDC00FF);

// Horizontal placement, as a fraction of the bar's width. These are the centres
// the board puts things on — each label sits exactly under its own glyph.
const _homeCentreX = 109 / 942;
const _modulesCentreX = 277 / 942;
const _avatarCentreX = 470 / 942;
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
const _avatarSize = 129 / 152;
const _avatarRing = 7 / 152;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A pulse is an attention cue, not information. Where the platform asks for
    // less motion it is dropped rather than slowed: the button already reads as
    // the primary action without it.
    final quiet = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (quiet || widget.onScan == null) {
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
    if ((widget.onScan == null) != (oldWidget.onScan == null)) {
      widget.onScan == null ? _stop() : _start();
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
                  // The taps inside are ink responses, which need a material to
                  // splash on. It is transparent — the fill and the shadow are
                  // the decoration's, so the bar keeps a soft edge rather than
                  // the hard ring an elevation draws.
                  child: Material(
                    color: Colors.transparent,
                    shape: const StadiumBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        _tab(
                          w: w,
                          h: h,
                          centreX: _homeCentreX,
                          id: 'home',
                          label: 'Home',
                          icon: Icon(
                            widget.selectedId == 'home'
                                ? Icons.home_rounded
                                : Icons.home_outlined,
                          ),
                          onTap: widget.onHome,
                        ),
                        _tab(
                          w: w,
                          h: h,
                          centreX: _modulesCentreX,
                          id: 'modules',
                          label: 'Modules',
                          icon: _CubeGlyph(
                            filled: widget.selectedId == 'modules',
                          ),
                          onTap: widget.onModules,
                        ),
                        Positioned(
                          left: _avatarCentreX * w - _avatarSize * h / 2,
                          top: (h - _avatarSize * h) / 2,
                          width: _avatarSize * h,
                          height: _avatarSize * h,
                          child: _Avatar(
                            initials: widget.initials,
                            imageUrl: widget.avatarUrl,
                            ring: _avatarRing * h,
                            onTap: widget.onProfile,
                          ),
                        ),
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
                      ],
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
    required VoidCallback onTap,
  }) {
    final width = _tabWidth * w;
    final glyph = _glyphSize * h;
    final selected = widget.selectedId == id;
    final inactiveColor = Theme.of(
      context,
    ).colorScheme.onSurfaceVariant.withValues(alpha: .58);

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
                child: Center(child: icon),
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
                    // The board sets both labels the same. Selection is carried
                    // by weight alone, the signal that does not recolour half
                    // the bar as you move through it.
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

/// The board's Modules glyph: an isometric cube — a filled hexagon split into
/// its three visible faces. Material ships no filled cube, and an outlined one
/// beside a solid house reads as a different family.
class _CubeGlyph extends StatelessWidget {
  const _CubeGlyph({required this.filled});

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

  /// The face seams are cut out of the solid, so they take the bar's own colour
  /// rather than being painted white over it.
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

    // Three seams from the middle to alternating corners cut the hexagon into a
    // top face and two sides, which is what makes it read as a box.
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

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.initials,
    required this.ring,
    required this.onTap,
    this.imageUrl,
  });

  final String initials;
  final double ring;
  final String? imageUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final hasImage = url != null && url.isNotEmpty;

    return Semantics(
      button: true,
      label: 'Profile',
      child: InkResponse(
        key: const ValueKey('nav-profile'),
        onTap: onTap,
        containedInkWell: false,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _ringPurple, width: ring),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            image: hasImage
                ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
                : null,
          ),
          alignment: Alignment.center,
          child: hasImage
              ? null
              : FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: EdgeInsets.all(ring * 2),
                    child: Text(
                      initials,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// The scanner: a gradient slab framed by viewfinder corners.
///
/// Every five seconds the frame opens a little and the label turns magenta,
/// then settles back. It is a short pulse rather than a slow cycle, so the bar
/// is still for most of the time it is on screen.
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
      label: enabled ? 'Scan here' : 'Scanner unavailable',
      child: GestureDetector(
        key: const ValueKey('nav-scan'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedBuilder(
          animation: pulse,
          builder: (context, _) {
            final t = Curves.easeOut.transform(pulse.value);
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: enabled
                    ? const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [_scanFrom, _scanTo],
                      )
                    : null,
                color: enabled
                    ? null
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(_scanHeight * h / 2),
              ),
              child: CustomPaint(
                painter: _ViewfinderPainter(
                  stroke: _bracketStroke * h,
                  arm: _bracketArm * h,
                  inset: _bracketInset * h * (1 - 0.28 * t),
                  color: enabled
                      ? Colors.white
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                child: Center(
                  child: Text(
                    'Scan here',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: _scanLabelSize * h,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                      color: enabled
                          ? Color.lerp(Colors.white, _pulseMagenta, t)
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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

/// Four corner brackets, inset from the slab's edge — the frame a camera draws
/// around what it is about to read.
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

    // Curve each bracket around the pill instead of drawing a sharp L. Keeping
    // the radius proportional to the arm makes the frame follow the rounded
    // button at every responsive navigation-bar size.
    void corner(Offset at, double dx, double dy) {
      // Use a generous radius so the rounding remains clearly visible at the
      // compact mobile size and mirrors the capsule behind it.
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
