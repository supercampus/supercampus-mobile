import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Flutter port of the ScrollStack interaction.
///
/// Cards flow in a normal vertical scroll until each one reaches
/// [stackPosition] (a fraction of viewport height from the top), at which
/// point it pins there and scales down toward `baseScale + index * itemScale`.
/// Each successive card pins [itemStackDistance] lower and slightly larger,
/// so the stack accumulates at the top with earlier cards nested behind.
///
/// Transforms are applied in the same order as the CSS original
/// (`translate → scale → rotate`, origin top-center) and layout is
/// deterministic from the index, so no per-frame measurement is needed.
class ScrollStack extends StatefulWidget {
  const ScrollStack({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.itemHeight,
    this.itemDistance = 24,
    this.itemScale = 0.03,
    this.itemStackDistance = 20,
    this.stackPosition = 0.06,
    this.scaleEndPosition = -0.04,
    this.baseScale = 0.85,
    this.rotationAmount = 0,
    this.blurAmount = 0,
    this.horizontalPadding = 20,
    this.smoothWheel = true,
    this.wheelMultiplier = 1.0,
    this.smoothDuration = const Duration(milliseconds: 340),
    this.smoothCurve = Curves.easeOutCubic,
    this.onStackComplete,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Fixed card height. Defaults to a viewport-relative height so the stack
  /// works on a phone as well as a desktop browser window.
  final double? itemHeight;

  /// Visible gap between cards at rest. Also sets how far you scroll between
  /// one card pinning and the next, so very small values make the stack
  /// accumulate quickly.
  final double itemDistance;

  /// How much larger each successive card ends up than the one behind it.
  final double itemScale;

  /// Vertical offset between pinned cards.
  final double itemStackDistance;

  /// Where cards pin, as a fraction of viewport height. Also the resting gap
  /// above the first card — lower it to tuck the stack under your header.
  final double stackPosition;

  /// Where the scale animation finishes, as a fraction of viewport height.
  ///
  /// The ramp runs for `(stackPosition - scaleEndPosition) * viewport` pixels
  /// of scroll, starting when the card pins. **Negative values are expected**
  /// with a small [stackPosition]: they place the finish line below the pin
  /// line, preserving a long ramp instead of snapping the scale instantly.
  final double scaleEndPosition;

  /// Scale of the first (deepest) card once fully stacked.
  final double baseScale;

  /// Degrees of rotation applied per index at full progress. 0 disables it.
  final double rotationAmount;

  /// Blur in logical pixels applied per unit of depth below the top card.
  /// 0 disables it — blur is the most expensive part of this effect.
  final double blurAmount;

  final double horizontalPadding;

  /// Animates discrete mouse-wheel notches instead of jumping, which is what
  /// Lenis provides in the web original. Touch and trackpad scrolling already
  /// arrive as a smooth stream and are left to the platform physics.
  final bool smoothWheel;

  /// Scroll distance per wheel notch, as a multiple of the raw delta.
  final double wheelMultiplier;

  final Duration smoothDuration;
  final Curve smoothCurve;

  /// Fires once when the last card reaches its pinned state.
  final VoidCallback? onStackComplete;

  @override
  State<ScrollStack> createState() => _ScrollStackState();
}

class _ScrollStackState extends State<ScrollStack> {
  final _controller = ScrollController();
  bool _stackCompleted = false;

  /// Where the in-flight smooth-scroll animation is heading. Successive wheel
  /// notches accumulate onto this rather than the current offset, so spinning
  /// the wheel fast covers the full distance instead of restarting each time.
  double? _wheelTarget;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _progress(double value, double start, double end) {
    if (end <= start) return value >= end ? 1 : 0;
    if (value < start) return 0;
    if (value > end) return 1;
    return (value - start) / (end - start);
  }

  /// Claims the wheel event before [Scrollable] can. Pointer signals are
  /// dispatched deepest-first and the resolver keeps the first registration,
  /// so this only wins because the listener sits inside the viewport.
  void _onPointerSignal(PointerSignalEvent event) {
    if (!widget.smoothWheel || event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(
      event,
      (resolved) => _animateWheel(resolved as PointerScrollEvent),
    );
  }

  void _animateWheel(PointerScrollEvent event) {
    if (!_controller.hasClients) return;
    final position = _controller.position;

    var base = _wheelTarget ?? position.pixels;
    // A drag or fling can move the sheet out from under a stale target.
    if ((base - position.pixels).abs() > position.viewportDimension) {
      base = position.pixels;
    }

    final target = (base + event.scrollDelta.dy * widget.wheelMultiplier).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if (target == position.pixels) {
      _wheelTarget = null;
      return;
    }

    _wheelTarget = target;
    _controller
        .animateTo(
          target,
          duration: widget.smoothDuration,
          curve: widget.smoothCurve,
        )
        .whenComplete(() {
          if (_wheelTarget == target) _wheelTarget = null;
        });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxHeight;
        final itemHeight =
            widget.itemHeight ?? (viewport * 0.36).clamp(230.0, 300.0);

        final stackPx = widget.stackPosition * viewport;
        final scaleEndPx = widget.scaleEndPosition * viewport;
        final topPad = stackPx;

        // Offset of each card within the scrollable content.
        double cardTop(int i) =>
            topPad + i * (itemHeight + widget.itemDistance);

        // Where the `.scroll-stack-end` spacer sits in the original.
        final endTop =
            topPad +
            widget.itemCount * itemHeight +
            (widget.itemCount - 1) * widget.itemDistance;
        final pinEnd = endTop - viewport / 2;

        // Enough trailing space that the last card can reach pinEnd and
        // release, replacing the original's hardcoded bottom padding.
        final bottomPad = viewport * 0.6 + widget.itemDistance;

        return SingleChildScrollView(
          controller: _controller,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final scrollTop = _controller.hasClients
                  ? _controller.offset
                  : 0.0;

              // Index of the card currently on top of the stack — everything
              // before it is "behind" and eligible for depth blur.
              var topCardIndex = 0;
              for (var j = 0; j < widget.itemCount; j++) {
                final triggerStart =
                    cardTop(j) - stackPx - widget.itemStackDistance * j;
                if (scrollTop >= triggerStart) topCardIndex = j;
              }

              final last = widget.itemCount - 1;
              _reportCompletion(
                scrollTop: scrollTop,
                pinStart:
                    cardTop(last) - stackPx - widget.itemStackDistance * last,
                pinEnd: pinEnd,
              );

              // The listener must live inside the viewport to claim wheel
              // events, so the padding is built as content rather than passed
              // to SingleChildScrollView — otherwise the padded strips would
              // fall through to the default scroll handling.
              return Listener(
                onPointerSignal: _onPointerSignal,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.horizontalPadding,
                  ),
                  child: Column(
                    children: [
                      SizedBox(height: topPad),
                      for (var i = 0; i < widget.itemCount; i++) ...[
                        _buildCard(
                          index: i,
                          scrollTop: scrollTop,
                          cardTop: cardTop(i),
                          itemHeight: itemHeight,
                          stackPx: stackPx,
                          scaleEndPx: scaleEndPx,
                          pinEnd: pinEnd,
                          topCardIndex: topCardIndex,
                        ),
                        if (i != last) SizedBox(height: widget.itemDistance),
                      ],
                      SizedBox(height: bottomPad),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCard({
    required int index,
    required double scrollTop,
    required double cardTop,
    required double itemHeight,
    required double stackPx,
    required double scaleEndPx,
    required double pinEnd,
    required int topCardIndex,
  }) {
    final pinOffset = stackPx + widget.itemStackDistance * index;
    final triggerStart = cardTop - pinOffset;
    final triggerEnd = cardTop - scaleEndPx;

    final scaleProgress = _progress(scrollTop, triggerStart, triggerEnd);
    final targetScale = widget.baseScale + index * widget.itemScale;
    final scale = 1 - scaleProgress * (1 - targetScale);
    final rotation = widget.rotationAmount == 0
        ? 0.0
        : index * widget.rotationAmount * scaleProgress;

    // Pinned: hold the card at a fixed viewport position. Past the release
    // point: freeze where it was so the whole stack scrolls away together.
    double translateY = 0;
    if (scrollTop >= triggerStart && scrollTop <= pinEnd) {
      translateY = scrollTop - cardTop + pinOffset;
    } else if (scrollTop > pinEnd) {
      translateY = pinEnd - cardTop + pinOffset;
    }

    Widget card = SizedBox(
      height: itemHeight,
      width: double.infinity,
      child: widget.itemBuilder(context, index),
    );

    if (widget.blurAmount > 0 && index < topCardIndex) {
      final blur = (topCardIndex - index) * widget.blurAmount;
      card = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: card,
      );
    }

    return Transform(
      alignment: Alignment.topCenter,
      transform: Matrix4.identity()
        ..translateByDouble(0.0, translateY, 0.0, 1.0)
        ..scaleByDouble(scale, scale, 1.0, 1.0)
        ..rotateZ(rotation * math.pi / 180),
      child: RepaintBoundary(child: card),
    );
  }

  void _reportCompletion({
    required double scrollTop,
    required double pinStart,
    required double pinEnd,
  }) {
    if (widget.onStackComplete == null) return;
    final inView = scrollTop >= pinStart && scrollTop <= pinEnd;
    if (inView && !_stackCompleted) {
      _stackCompleted = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onStackComplete?.call(),
      );
    } else if (!inView && _stackCompleted) {
      _stackCompleted = false;
    }
  }
}
