import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';

/// Expanding pill list of modules.
///
/// Every module is a thin gradient bar; the selected one grows into a stadium
/// card carrying its icon, name and an open affordance.
///
/// The whole list is driven by one continuous position — `1.4` means "40% of
/// the way from Attendance to Canteen" — so a transition is a single morph
/// rather than one bar shrinking while another independently grows. Dragging
/// moves that position under your finger; releasing settles it onto the
/// nearest module with a spring. Wheel notches step it one at a time.
class ModuleAccordion extends StatefulWidget {
  const ModuleAccordion({
    super.key,
    required this.modules,
    required this.permissions,
    required this.onOpenModule,
    this.onExpandedChanged,
    this.maxExpandedHeight = 158,
    this.minExpandedHeight = 104,
    this.collapsedHeight = 17,
    this.gap = 10,
    this.wheelThreshold = 45,
    this.stepLock = const Duration(milliseconds: 260),
  });

  final List<ModuleDescriptor> modules;
  final EffectivePermissions permissions;
  final ValueChanged<String> onOpenModule;
  final ValueChanged<int>? onExpandedChanged;

  /// The expanded card takes whatever height the collapsed bars leave over,
  /// within these bounds, so the list always fills its slot without scrolling.
  final double maxExpandedHeight;
  final double minExpandedHeight;

  final double collapsedHeight;
  final double gap;

  /// Wheel delta that constitutes one step.
  final double wheelThreshold;

  /// How long the wheel is ignored after a step, so one flick moves one card.
  final Duration stepLock;

  @override
  State<ModuleAccordion> createState() => _ModuleAccordionState();
}

/// Just under critical damping (ratio ≈ 0.92): settles quickly with a hint of
/// follow-through, which is what reads as "physical" rather than "eased".
const _spring = SpringDescription(mass: 1, stiffness: 200, damping: 26);

class _ModuleAccordionState extends State<ModuleAccordion>
    with SingleTickerProviderStateMixin {
  /// Fractional index of the expanded card. Unbounded because a spring needs
  /// room to overshoot before it settles.
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
  );

  int _selected = 0;
  double _accumulated = 0;
  bool _locked = false;
  Timer? _lockTimer;

  /// Finger travel that equals one step. Set from the measured card height so
  /// the list tracks the drag at a natural rate on any screen.
  double _stepDistance = 96;

  @override
  void initState() {
    super.initState();
    _position.addListener(_syncSelection);
  }

  @override
  void didUpdateWidget(covariant ModuleAccordion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_position.value > _maxIndex) _position.value = 0;
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _position.dispose();
    super.dispose();
  }

  double get _maxIndex => (widget.modules.length - 1).toDouble();

  /// The list renders straight off [_position]; this only tracks which module
  /// is *nearest*, for the item keys and the caller's accent colour.
  void _syncSelection() {
    final nearest = _position.value.round().clamp(0, widget.modules.length - 1);
    if (nearest == _selected) return;
    setState(() => _selected = nearest);
    widget.onExpandedChanged?.call(nearest);
  }

  void _settle({double velocity = 0}) {
    var target = _position.value.roundToDouble();

    // A deliberate flick carries to the next card even from less than halfway.
    if (velocity.abs() > 1.5) {
      target = velocity > 0
          ? _position.value.ceilToDouble()
          : _position.value.floorToDouble();
    }

    _springTo(target.clamp(0.0, _maxIndex), velocity);
  }

  void _springTo(double target, double velocity) {
    _position.animateWith(
      SpringSimulation(_spring, _position.value, target, velocity),
    );
  }

  void _goTo(int index) {
    final target = index.clamp(0, widget.modules.length - 1).toDouble();
    if (target == _position.value && !_position.isAnimating) return;
    _springTo(target, 0);
  }

  void _lock() {
    _locked = true;
    _lockTimer?.cancel();
    _lockTimer = Timer(widget.stepLock, () => _locked = false);
  }

  /// Claims the wheel before any enclosing [Scrollable]. Pointer signals are
  /// dispatched deepest-first and the resolver keeps the first registration.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      _onWheel((resolved as PointerScrollEvent).scrollDelta.dy);
    });
  }

  void _onWheel(double delta) {
    if (_locked) return;
    _accumulated += delta;
    if (_accumulated.abs() < widget.wheelThreshold) return;

    final direction = _accumulated > 0 ? 1 : -1;
    _accumulated = 0;

    final next = (_selected + direction).clamp(0, widget.modules.length - 1);
    if (next == _selected) return;

    _goTo(next);
    _lock();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.modules.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final collapsedTotal =
            (count - 1) * (widget.collapsedHeight + widget.gap);
        final expandedHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - collapsedTotal).clamp(
                widget.minExpandedHeight,
                widget.maxExpandedHeight,
              )
            : widget.maxExpandedHeight;

        _stepDistance = expandedHeight * 0.62;

        // A viewport rather than a bare Column so an unusually long module
        // list clips instead of throwing an overflow. It never scrolls itself
        // — the listener inside owns every scroll gesture, and sits deeper
        // than this Scrollable so it claims wheel events first.
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Listener(
            onPointerSignal: _onPointerSignal,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => _position.stop(),
              // Dragging up moves towards the next module.
              onVerticalDragUpdate: (details) {
                _position.value = (_position.value -
                        details.delta.dy / _stepDistance)
                    .clamp(0.0, _maxIndex);
              },
              onVerticalDragEnd: (details) => _settle(
                velocity: -(details.primaryVelocity ?? 0) / _stepDistance,
              ),
              onVerticalDragCancel: _settle,
              child: AnimatedBuilder(
                animation: _position,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < count; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i == count - 1 ? 0 : widget.gap,
                        ),
                        child: _AccordionItem(
                          module: widget.modules[i],
                          permissions: widget.permissions,
                          // 1.0 fully expanded, 0.0 fully collapsed. These
                          // always sum to 1 across the list, so the column's
                          // total height never changes mid-transition.
                          expansion: (1 - (_position.value - i).abs()).clamp(
                            0.0,
                            1.0,
                          ),
                          isSelected: i == _selected,
                          expandedHeight: expandedHeight,
                          collapsedHeight: widget.collapsedHeight,
                          onTap: () => _goTo(i),
                          onOpen: () =>
                              widget.onOpenModule(widget.modules[i].id),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AccordionItem extends StatefulWidget {
  const _AccordionItem({
    required this.module,
    required this.permissions,
    required this.expansion,
    required this.isSelected,
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.onTap,
    required this.onOpen,
  });

  final ModuleDescriptor module;
  final EffectivePermissions permissions;
  final double expansion;
  final bool isSelected;
  final double expandedHeight;
  final double collapsedHeight;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  State<_AccordionItem> createState() => _AccordionItemState();
}

class _AccordionItemState extends State<_AccordionItem> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    final ready = module.status != ModuleStatus.planned;
    final t = widget.expansion;

    final height =
        widget.collapsedHeight +
        (widget.expandedHeight - widget.collapsedHeight) * t;

    // Content holds back until the bar has real height, then eases in — a
    // straight linear fade shows text crushed inside a 30px pill.
    final reveal = Curves.easeOut.transform(
      ((t - 0.3) / 0.7).clamp(0.0, 1.0),
    );

    return GestureDetector(
      // The key follows the state, so a caller can always address the item by
      // what tapping it will do.
      key: ValueKey(
        widget.isSelected
            ? 'open-module-${module.id}'
            : 'module-bar-${module.id}',
      ),
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: () {
        if (!widget.isSelected) {
          widget.onTap();
        } else if (ready) {
          widget.onOpen();
        }
      },
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Container(
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: _gradientFor(module.color),
            // Tied to the live height, so the pill *becomes* the stadium
            // instead of cross-fading into it.
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: t <= 0.01
                ? const []
                : [
                    BoxShadow(
                      color: module.color.withValues(alpha: 0.30 * t),
                      blurRadius: 8 + 20 * t,
                      offset: Offset(0, 4 + 8 * t),
                    ),
                  ],
          ),
          // Content is laid out at full size the whole time, so the reveal is
          // a clip rather than a rebuild — no relayout jank mid-animation, and
          // no overflow error at 17px tall.
          child: OverflowBox(
            minHeight: widget.expandedHeight,
            maxHeight: widget.expandedHeight,
            alignment: Alignment.center,
            child: Opacity(
              opacity: reveal,
              child: _ExpandedContent(
                module: module,
                permissions: widget.permissions,
                height: widget.expandedHeight,
                ready: ready,
                reveal: reveal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedContent extends StatelessWidget {
  const _ExpandedContent({
    required this.module,
    required this.permissions,
    required this.height,
    required this.ready,
    required this.reveal,
  });

  final ModuleDescriptor module;
  final EffectivePermissions permissions;
  final double height;
  final bool ready;
  final double reveal;

  @override
  Widget build(BuildContext context) {
    final circle = height - 34;
    final level = permissions.accessLevel(module.id);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: height * 0.11),
      child: Row(
        children: [
          // Secondary motion: the circle scales up and the text slides in
          // behind it, so the card assembles rather than appearing.
          Transform.scale(
            scale: 0.86 + 0.14 * reveal,
            child: Container(
              width: circle,
              height: circle,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                module.icon,
                color: module.color,
                size: circle * 0.42,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Transform.translate(
              offset: Offset(16 * (1 - reveal), 0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    module.displayName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.6,
                      height: 1.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    ready ? level.label : 'Coming soon',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Transform.translate(
            offset: Offset(20 * (1 - reveal), 0),
            child: Icon(
              ready ? Icons.play_arrow_rounded : Icons.schedule_rounded,
              color: Colors.white.withValues(alpha: ready ? 1 : 0.6),
              size: 34,
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-stop gradient that shifts hue as well as lightness, so each bar reads
/// as a single vivid colour rather than a wash toward grey.
LinearGradient _gradientFor(Color color) {
  final hsl = HSLColor.fromColor(color);
  final saturation = (hsl.saturation * 1.2).clamp(0.0, 1.0);

  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      hsl
          .withHue((hsl.hue - 14) % 360)
          .withSaturation(saturation)
          .withLightness((hsl.lightness * 1.5).clamp(0.0, 0.72))
          .toColor(),
      hsl
          .withHue((hsl.hue + 16) % 360)
          .withSaturation(saturation)
          .withLightness((hsl.lightness * 0.82).clamp(0.0, 1.0))
          .toColor(),
    ],
  );
}
