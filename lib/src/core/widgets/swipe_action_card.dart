import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

import '../motion/app_springs.dart';

/// One end of a swipe: what it does, and how it looks while you are doing it.
@immutable
class SwipeAction {
  const SwipeAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onCommit,
    this.foreground = Colors.white,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color foreground;
  final VoidCallback onCommit;
}

/// A card you push sideways to act on.
///
/// The card tracks the finger 1:1, resists once it is past the point where the
/// action would fire, and settles on a spring that inherits the release
/// velocity — so there is no seam between dragging and animating. It can be
/// grabbed again mid-flight and reversed, because the spring always starts from
/// the value currently on screen rather than from where it was headed.
///
/// Commit is decided by projecting the flick forward, not by where the finger
/// happened to let go: a short hard flick commits, a long slow drag that stops
/// short does not.
class SwipeActionCard extends StatefulWidget {
  const SwipeActionCard({
    super.key,
    required this.child,
    this.forward,
    this.backward,
    this.enabled = true,
    this.commitFraction = 0.35,
    this.dismissOnCommit = true,
  });

  final Widget child;

  /// Revealed by dragging right.
  final SwipeAction? forward;

  /// Revealed by dragging left.
  final SwipeAction? backward;

  final bool enabled;

  /// How far across the card the drag must be projected to land for the action
  /// to fire.
  final double commitFraction;

  /// Whether committing carries the card off the screen.
  ///
  /// True when the action removes the row from the list it is in — an order
  /// that moves to another queue leaves, and the card leaving says so. False
  /// when the row stays and only its state changes, as when a student is marked
  /// on a roster: nothing is going anywhere, so the card springs home and the
  /// row underneath tells you what happened.
  final bool dismissOnCommit;

  @override
  State<SwipeActionCard> createState() => _SwipeActionCardState();
}

class _SwipeActionCardState extends State<SwipeActionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _offset = AnimationController.unbounded(
    vsync: this,
  )..addListener(_onOffsetChanged);

  double _width = 0;

  /// Set once the drag passes the commit point, so the haptic fires on the
  /// crossing rather than repeatedly.
  bool _armed = false;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _onOffsetChanged() {
    final armed = _actionFor(_offset.value) != null &&
        _offset.value.abs() >= _commitDistance;
    if (armed != _armed) {
      _armed = armed;
      // Causality: the tick lands exactly when the card crosses the point of
      // no return, which is the moment worth feeling.
      if (armed) HapticFeedback.selectionClick();
    }
    setState(() {});
  }

  double get _commitDistance => _width * widget.commitFraction;

  SwipeAction? _actionFor(double offset) {
    if (offset > 0) return widget.forward;
    if (offset < 0) return widget.backward;
    return null;
  }

  void _onDragStart(DragStartDetails _) {
    // Interruptibility: stop where it is rather than letting the old animation
    // finish. The next drag continues from the on-screen value.
    _offset.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final next = _offset.value + details.delta.dx;
    final action = _actionFor(next);

    if (action == null) {
      // Nothing lives this way, so the card barely follows.
      _offset.value = rubberband(next, _width) * 0.35;
      return;
    }

    // Track the finger exactly up to the commit point, then resist — the card
    // keeps responding, but its slowing tells you it has all it needs.
    final past = next.abs() - _commitDistance;
    if (past <= 0) {
      _offset.value = next;
    } else {
      final resisted = _commitDistance + rubberband(past, _width);
      _offset.value = next.isNegative ? -resisted : resisted;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;

    // Where the flick would come to rest, not where the finger stopped.
    final projected = _offset.value + projectMomentum(velocity);
    final action = _actionFor(projected);
    final committed =
        action != null && projected.abs() >= _commitDistance;

    if (!committed) {
      _settleHome(velocity);
      return;
    }

    if (prefersReducedMotion(context)) {
      _offset.value = 0;
      action.onCommit();
      return;
    }

    HapticFeedback.mediumImpact();
    if (!widget.dismissOnCommit) {
      // The row is staying, so the card comes back rather than flying off and
      // reappearing. The spring still inherits the release velocity, so the
      // return continues the gesture instead of cutting it off.
      action.onCommit();
      _settleHome(velocity);
      return;
    }

    // Carry the card off the way it was already going, then hand back to the
    // caller. The list rebuilds on the new status, which removes this card.
    final target = projected.isNegative ? -_width : _width;
    _offset
        .animateWith(
          SpringSimulation(AppSprings.momentum, _offset.value, target, velocity),
        )
        .whenCompleteOrCancel(() {
          if (mounted) _offset.value = 0;
        });
    action.onCommit();
  }

  void _settleHome(double velocity) {
    if (prefersReducedMotion(context)) {
      _offset.value = 0;
      return;
    }
    _offset
        .animateWith(
          SpringSimulation(AppSprings.standard, _offset.value, 0, velocity),
        )
        .whenCompleteOrCancel(() {
          // A spring settles within a tolerance, not exactly on zero. The
          // remainder is invisible behind the card, but it keeps the backdrop
          // mounted and its label in the semantics tree, so the rest is
          // discarded once the motion is over.
          if (mounted && _offset.value != 0) _offset.value = 0;
        });
  }

  @override
  Widget build(BuildContext context) {
    final offset = _offset.value;
    final action = _actionFor(offset);

    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: widget.enabled ? _onDragStart : null,
          onHorizontalDragUpdate: widget.enabled ? _onDragUpdate : null,
          onHorizontalDragEnd: widget.enabled ? _onDragEnd : null,
          child: Stack(
            children: [
              if (action != null)
                Positioned.fill(
                  child: _ActionBackdrop(
                    action: action,
                    // The backdrop fills in as the card clears it, so the
                    // in-between frames point at the outcome.
                    progress: _commitDistance == 0
                        ? 0
                        : (offset.abs() / _commitDistance).clamp(0.0, 1.0),
                    alignEnd: offset.isNegative,
                  ),
                ),
              Transform.translate(
                offset: Offset(offset, 0),
                child: widget.child,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionBackdrop extends StatelessWidget {
  const _ActionBackdrop({
    required this.action,
    required this.progress,
    required this.alignEnd,
  });

  final SwipeAction action;
  final double progress;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    // Armed reads as full strength; before that it is visibly provisional.
    final armed = progress >= 1;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: action.color.withValues(alpha: 0.25 + 0.75 * progress),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Align(
        alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, color: action.foreground, size: 20),
              const SizedBox(width: 8),
              Text(
                action.label,
                style: TextStyle(
                  color: action.foreground,
                  fontWeight: armed ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
