import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

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
///
/// Every destination and the scanner share the bar in equal slots, so two,
/// three or four destinations all line up the same way; the scanner is the
/// last slot, a solid brand-coloured key with its label under it like the
/// destinations beside it.
class CampusNavBar extends StatelessWidget {
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

  bool get _effectiveShowScan => showScan ?? (onScan != null);

  @override
  Widget build(BuildContext context) {
    final tabs = (items != null && items!.isNotEmpty)
        ? items!
        : [
            CampusNavItem(
              id: 'home',
              label: 'Home',
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              onTap: onHome,
            ),
            CampusNavItem(
              id: 'modules',
              label: 'Modules',
              icon: const CampusNavCubeGlyph(filled: false),
              selectedIcon: const CampusNavCubeGlyph(filled: true),
              onTap: onModules,
            ),
          ];
    final hasScan = _effectiveShowScan;

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
                final h = constraints.maxHeight;
                final p = context.palette;
                return DecoratedBox(
                  decoration: BoxDecoration(
                    // Raised above the dark canvas, with a hairline edge so
                    // the pill still reads where the shadow cannot.
                    color: p.surfaceRaised,
                    borderRadius: BorderRadius.circular(h / 2),
                    border: context.isDarkTheme
                        ? Border.all(color: p.border)
                        : null,
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
                    child: Padding(
                      // Keeps the outer slots clear of the rounded caps.
                      padding: EdgeInsets.symmetric(horizontal: h * 0.22),
                      child: Row(
                        children: [
                          for (final item in tabs)
                            Expanded(
                              child: _NavTab(
                                item: item,
                                selected: selectedId == item.id,
                                barHeight: h,
                              ),
                            ),
                          if (hasScan)
                            Expanded(
                              child: _ScanButton(onTap: onScan, barHeight: h),
                            ),
                        ],
                      ),
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
}

const _iconPurple = Color(0xFF7B42F6);

// Vertical placement and sizes, as a fraction of the bar's height.
const _glyphSize = 53 / 152;
const _glyphCentreY = 66 / 152;
const _labelCentreY = 109.5 / 152;
const _labelSize = 18 / 152;

/// The scanner key: where its centre sits, its size and its glyph. It stays
/// clear of its label, which lines up with the destinations' labels.
const _scanCentreY = 63 / 152;
const _scanKeyHeight = 60 / 152;
const _scanKeyWidth = 96 / 152;
const _scanGlyphSize = 36 / 152;

/// The label under a glyph, in the destinations' type.
TextStyle _labelStyle(double h, {required Color color, required bool bold}) =>
    TextStyle(
      color: color,
      fontSize: _labelSize * h,
      height: 1.2,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
    );

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.item,
    required this.selected,
    required this.barHeight,
  });

  final CampusNavItem item;
  final bool selected;
  final double barHeight;

  @override
  Widget build(BuildContext context) {
    final h = barHeight;
    final glyph = _glyphSize * h;
    final inactiveColor = context.adaptive(
      light: Theme.of(
        context,
      ).colorScheme.onSurfaceVariant.withValues(alpha: .58),
      dark: context.palette.inkSecondary,
    );
    final activeColor = context.adaptive(
      light: _iconPurple,
      dark: context.palette.brandInk,
    );
    final displayIcon = (selected && item.selectedIcon != null)
        ? item.selectedIcon!
        : item.icon;

    // One node per destination: its name, that it is a button, whether it
    // is the current one, and the tap the InkResponse brings.
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: item.label,
      child: InkResponse(
        key: ValueKey('nav-${item.id}'),
        onTap: item.onTap,
        containedInkWell: false,
        radius: h * 0.6,
        child: ExcludeSemantics(
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: _glyphCentreY * h - glyph / 2,
                height: glyph,
                child: IconTheme(
                  data: IconThemeData(
                    color: selected ? activeColor : inactiveColor,
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
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: _labelStyle(
                      h,
                      color: selected
                          ? Theme.of(context).colorScheme.onSurface
                          : inactiveColor,
                      bold: selected,
                    ),
                  ),
                ),
              ),
            ],
          ),
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
        // Matches the bar fill so the seams read as cut-outs.
        seam: context.palette.surfaceRaised,
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

/// The scanner: a solid brand-coloured key holding a crisp scanner glyph, with
/// "Scan" under it where the destinations carry their labels.
///
/// It presses in the moment a finger lands — a slight scale and a deeper
/// fill — and springs back on release. Without an [onTap] it stays in place,
/// dimmed, so a permission change never reflows the bar.
class _ScanButton extends StatefulWidget {
  const _ScanButton({required this.onTap, required this.barHeight});

  final VoidCallback? onTap;
  final double barHeight;

  @override
  State<_ScanButton> createState() => _ScanButtonState();
}

class _ScanButtonState extends State<_ScanButton> {
  var _pressed = false;

  void _press(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.barHeight;
    final enabled = widget.onTap != null;
    final p = context.palette;
    final quiet = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final keyHeight = _scanKeyHeight * h;
    final keyWidth = _scanKeyWidth * h;
    final fill = enabled
        ? (_pressed ? Color.lerp(p.brand, Colors.black, 0.18)! : p.brand)
        : p.brand.withValues(alpha: 0.38);

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: 'Scan QR code',
      child: Tooltip(
        message: 'Scan QR code',
        excludeFromSemantics: true,
        // The key goes in on pointer-down — not after the tap is decided —
        // and comes back out when the finger lifts or slides away.
        child: Listener(
          onPointerDown: enabled ? (_) => _press(true) : null,
          onPointerUp: (_) => _press(false),
          onPointerCancel: (_) => _press(false),
          child: GestureDetector(
            key: const ValueKey('nav-scan'),
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: ExcludeSemantics(
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _scanCentreY * h - keyHeight / 2,
                    height: keyHeight,
                    child: Center(
                      child: AnimatedScale(
                        scale: _pressed ? 0.92 : 1,
                        duration: quiet
                            ? Duration.zero
                            : const Duration(milliseconds: 110),
                        curve: Curves.easeOut,
                        child: AnimatedContainer(
                          key: const ValueKey('nav-scan-key'),
                          duration: quiet
                              ? Duration.zero
                              : const Duration(milliseconds: 110),
                          width: keyWidth,
                          height: keyHeight,
                          decoration: BoxDecoration(
                            color: fill,
                            // A rounded square, not a pill: it reads as a key.
                            borderRadius: BorderRadius.circular(
                              keyHeight * 0.36,
                            ),
                            boxShadow: enabled && !_pressed
                                ? [
                                    BoxShadow(
                                      color: p.brand.withValues(alpha: 0.28),
                                      blurRadius: h * 0.12,
                                      offset: Offset(0, h * 0.04),
                                    ),
                                  ]
                                : const [],
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.qr_code_scanner_rounded,
                            color: p.onBrand,
                            size: _scanGlyphSize * h,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _labelCentreY * h - _labelSize * h * 0.6,
                    child: Center(
                      child: Text(
                        'Scan',
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.center,
                        style: _labelStyle(
                          h,
                          color: enabled
                              ? context.adaptive(
                                  light: _iconPurple,
                                  dark: p.brandInk,
                                )
                              : p.inkDisabled,
                          bold: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
