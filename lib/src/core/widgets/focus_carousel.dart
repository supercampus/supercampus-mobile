import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A vertical snap carousel with a single focused card.
///
/// The centred card renders at full scale, opacity and sharpness; neighbours
/// scale down, fade and blur in proportion to their distance from centre, and
/// the whole viewport is masked with a gradient so cards dissolve into the
/// background at the top and bottom edges.
///
/// Snapping is [PageView]'s — releasing a drag always settles a card exactly
/// on centre rather than leaving it mid-scroll.
class FocusCarousel extends StatefulWidget {
  const FocusCarousel({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.itemHeightFraction = 0.72,
    this.minItemHeight = 215,
    this.maxItemHeight = 300,
    this.itemGap = 12,
    this.minScale = 0.88,
    this.minOpacity = 0.38,
    this.maxBlur = 4.5,
    this.edgeFade = 0.12,
    this.showIndicator = true,
    this.indicatorHideDelay = const Duration(seconds: 1),
    this.indicatorColor,
    this.onPageChanged,
  });

  final int itemCount;

  /// Builds one card. `focus` is 1.0 when the card is exactly centred and
  /// falls to 0.0 for its immediate neighbours — use it to drive shadow or
  /// any other emphasis that should track the transition.
  final Widget Function(BuildContext context, int index, double focus)
  itemBuilder;

  /// Card height as a fraction of the carousel's own height.
  final double itemHeightFraction;
  final double minItemHeight;
  final double maxItemHeight;

  /// Gap between cards, in logical pixels. The page slot is
  /// `itemHeight + itemGap`, so how much of the neighbours peek works out to
  /// `(viewport - itemHeight) / 2 - itemGap`.
  final double itemGap;

  /// Scale, opacity and blur applied at one full page away from centre.
  final double minScale;
  final double minOpacity;
  final double maxBlur;

  /// Height of the top and bottom dissolve, as a fraction of the viewport.
  final double edgeFade;

  /// Position dots fade in while scrolling and back out once the list has
  /// been idle for [indicatorHideDelay].
  final bool showIndicator;
  final Duration indicatorHideDelay;
  final Color? indicatorColor;

  final ValueChanged<int>? onPageChanged;

  @override
  State<FocusCarousel> createState() => _FocusCarouselState();
}

class _FocusCarouselState extends State<FocusCarousel> {
  PageController? _controller;
  double _viewportFraction = 0;

  bool _indicatorVisible = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  /// The page slot depends on the carousel's measured height, which isn't
  /// known until layout — and [PageController.viewportFraction] is fixed at
  /// construction. Rebuild the controller when the fraction actually changes,
  /// preserving the current page.
  void _ensureController(double fraction) {
    final existing = _controller;
    if (existing != null && (_viewportFraction - fraction).abs() < 0.001) {
      return;
    }

    final currentPage = existing != null && existing.hasClients
        ? (existing.page ?? existing.initialPage.toDouble()).round()
        : 0;

    _controller = PageController(
      viewportFraction: fraction,
      initialPage: currentPage,
    );
    _viewportFraction = fraction;

    if (existing != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => existing.dispose());
    }
  }

  void _pingIndicator() {
    if (!widget.showIndicator) return;
    _hideTimer?.cancel();
    if (!_indicatorVisible) setState(() => _indicatorVisible = true);
    _hideTimer = Timer(widget.indicatorHideDelay, () {
      if (mounted) setState(() => _indicatorVisible = false);
    });
  }

  /// Fractional page position. `PageController.page` asserts on an unattached
  /// or unmeasured controller, which happens on the first build.
  double get _page {
    final controller = _controller;
    if (controller == null || !controller.hasClients) return 0;
    final position = controller.position;
    if (!position.hasPixels || !position.haveDimensions) {
      return controller.initialPage.toDouble();
    }
    return controller.page ?? controller.initialPage.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount == 0) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = constraints.maxHeight;
        final itemHeight = (viewport * widget.itemHeightFraction).clamp(
          widget.minItemHeight,
          math.min(widget.maxItemHeight, viewport),
        ).toDouble();
        final slot = itemHeight + widget.itemGap;
        _ensureController((slot / viewport).clamp(0.1, 1.0));

        final controller = _controller!;

        return Stack(
          children: [
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification ||
                      notification is ScrollUpdateNotification) {
                    _pingIndicator();
                  }
                  return false;
                },
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [
                      Colors.transparent,
                      Colors.black,
                      Colors.black,
                      Colors.transparent,
                    ],
                    stops: [0.0, widget.edgeFade, 1 - widget.edgeFade, 1.0],
                  ).createShader(rect),
                  child: PageView.builder(
                    controller: controller,
                    scrollDirection: Axis.vertical,
                    itemCount: widget.itemCount,
                    onPageChanged: widget.onPageChanged,
                    itemBuilder: (context, index) => AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) =>
                          _buildItem(context, index, itemHeight),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.showIndicator)
              Positioned(
                right: 4,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _indicatorVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                    child: AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) => _Indicator(
                        count: widget.itemCount,
                        page: _page,
                        color:
                            widget.indicatorColor ??
                            Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildItem(BuildContext context, int index, double itemHeight) {
    final distance = (_page - index).abs().clamp(0.0, 1.0);
    final focus = 1 - distance;

    final scale = ui.lerpDouble(1.0, widget.minScale, distance)!;
    final opacity = ui.lerpDouble(1.0, widget.minOpacity, distance)!;
    final blur = ui.lerpDouble(0.0, widget.maxBlur, distance)!;

    Widget card = SizedBox(
      height: itemHeight,
      child: widget.itemBuilder(context, index, focus),
    );

    // Sigma 0 still forces an offscreen render pass, so skip the filter
    // entirely for the focused card.
    if (blur > 0.1) {
      card = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
          tileMode: TileMode.decal,
        ),
        child: card,
      );
    }

    return Center(
      child: Transform.scale(
        scale: scale,
        child: Opacity(opacity: opacity, child: card),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({
    required this.count,
    required this.page,
    required this.color,
  });

  final int count;
  final double page;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _Dot(
                focus: (1 - (page - i).abs()).clamp(0.0, 1.0),
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.focus, required this.color});

  final double focus;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = ui.lerpDouble(5.0, 8.5, focus)!;
    return SizedBox(
      width: 9,
      height: 9,
      child: Center(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color.lerp(
              const Color(0xFF1C1C1E).withValues(alpha: 0.26),
              color,
              focus,
            ),
          ),
        ),
      ),
    );
  }
}
