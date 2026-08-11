import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';

/// One glass frame that every granted module scrolls through, a single card at
/// a time.
///
/// The frame never grows with the module count: a user with twelve modules
/// gets the same slot on the page as a user with two, and reaches the rest by
/// flicking through them. Only one card is ever inside the frame — the next
/// one is already out of sight below it — so the frame reads as a window onto
/// the list rather than as a pile of cards.
///
/// Motion is a vertical [PageView], so the drag is the platform's own scroll
/// physics: it tracks the finger exactly, carries momentum, and snaps to one
/// card. The card sliding away shrinks and fades a little as it goes, which is
/// what makes the change read as one movement instead of two.
///
/// The frame itself is plain glass — the page behind it, blurred, with a lit
/// edge. It has no colour of its own: whatever tint it seems to have is
/// borrowed from what is behind it.
class ModuleStack extends StatefulWidget {
  const ModuleStack({
    super.key,
    required this.modules,
    required this.permissions,
    required this.onOpenModule,
    this.onQuickAction,
    this.onIndexChanged,
  });

  final List<ModuleDescriptor> modules;
  final EffectivePermissions permissions;
  final ValueChanged<String> onOpenModule;
  final void Function(
    String moduleId,
    String actionId,
    String featureId,
    String requiredAction,
  )?
  onQuickAction;
  final ValueChanged<int>? onIndexChanged;

  /// The frame is a fixed slot — one card plus its glass surround — whatever
  /// the module count. Whoever places it hands it this height.
  static double heightFor(int moduleCount) => _frameHeight;

  @override
  State<ModuleStack> createState() => _ModuleStackState();
}

/// A card tall enough for a 52px icon tile, two lines of text and breathing
/// room — not so tall that it becomes a poster.
const _cardHeight = 174.0;

/// Glass showing around the card — the same on all four sides — and the
/// gutter the dot rail sits in beside the frame, outside the glass.
const _framePad = 8.0;
const _railWidth = 16.0;

const _frameRadius = 26.0;
const _cardRadius = _frameRadius - _framePad;

/// A page is the whole frame with the card centred in it, so the border of
/// glass above and below the card matches the one either side of it, and two
/// cards passing are separated by twice that.
const _frameHeight = _cardHeight + _framePad * 2;

/// How deep the soft edge runs into the frame, top and bottom. Deep enough to
/// swallow a card's corner radius, so nothing ever meets the frame at a line.
const _edgeFade = 18.0;

/// Where the card mask reaches full opacity, as a fraction of the frame.
const _fadeStop = _edgeFade / _frameHeight;

class _ModuleStackState extends State<ModuleStack> {
  final _controller = PageController();

  int _selected = 0;

  @override
  void didUpdateWidget(covariant ModuleStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected >= widget.modules.length) {
      _selected = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Where the deck is between cards — `1.4` means "40% of the way from
  /// Attendance to Canteen". Falls back to the settled page before the
  /// [PageView] has been laid out.
  double get _page {
    if (_controller.hasClients && _controller.position.hasContentDimensions) {
      return _controller.page ?? _selected.toDouble();
    }
    return _selected.toDouble();
  }

  void _goTo(int index) => _controller.animateToPage(
    index.clamp(0, widget.modules.length - 1),
    duration: const Duration(milliseconds: 420),
    curve: Curves.easeOutCubic,
  );

  /// How far the deck is between two cards, 0 at rest and 1 mid-move. The
  /// soft edge is a property of the movement, so everything it drives comes
  /// off this and costs nothing while the frame is still.
  double get _travel {
    final page = _page;
    return ((page - page.roundToDouble()).abs() * 2).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.modules.length;

    return Row(
      children: [
        Expanded(child: _frame(count)),
        if (count > 1)
          SizedBox(
            width: _railWidth,
            height: _frameHeight,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _DotRail(
                modules: widget.modules,
                position: _page,
                onSelect: _goTo,
              ),
            ),
          ),
      ],
    );
  }

  Widget _frame(int count) {
    return SizedBox(
      height: _frameHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_frameRadius),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2A2350).withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_frameRadius),
          child: Stack(
            children: [
              const Positioned.fill(child: _GlassPane()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _framePad),
                // A card in motion does not stop at the frame's edge, it
                // dissolves into it. The mask opens only as far as the deck is
                // moving, so a settled card keeps its edges exactly.
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (bounds) => _edgeMask(bounds),
                    child: child,
                  ),
                  child: PageView.builder(
                    controller: _controller,
                    scrollDirection: Axis.vertical,
                    itemCount: count,
                    onPageChanged: (index) {
                      setState(() => _selected = index);
                      widget.onIndexChanged?.call(index);
                    },
                    itemBuilder: (context, i) => AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) => _pageTransform(i, child!),
                      child: _ModuleCard(
                        // The key follows the state, so a caller can always
                        // address the card by what tapping it will do.
                        key: ValueKey(
                          i == _selected
                              ? 'open-module-${widget.modules[i].id}'
                              : 'module-bar-${widget.modules[i].id}',
                        ),
                        module: widget.modules[i],
                        permissions: widget.permissions,
                        onQuickAction: widget.onQuickAction,
                        onTap: () => i == _selected
                            ? widget.onOpenModule(widget.modules[i].id)
                            : _goTo(i),
                      ),
                    ),
                  ),
                ),
              ),
              // Frost that thickens towards the frame's edge, so a card leaves
              // through the glass rather than past a line drawn on it. Built
              // only while the deck is moving — a still frame is plain glass,
              // and pays for none of it.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _edgeFade,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) =>
                      _EdgeFrost(top: true, strength: _travel),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: _edgeFade,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) =>
                      _EdgeFrost(top: false, strength: _travel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opaque through the middle, tapering off at both ends by as much as the
  /// deck is moving. At rest the stops collapse to the corners and the mask
  /// leaves the card untouched.
  ui.Shader _edgeMask(Rect bounds) {
    final fade = _fadeStop * _travel;

    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: const [
        Colors.transparent,
        Colors.white,
        Colors.white,
        Colors.transparent,
      ],
      stops: [0, fade, 1 - fade, 1],
    ).createShader(bounds);
  }

  /// The card on its way out of the frame steps back rather than simply
  /// sliding: a touch smaller, a touch dimmer, so the eye follows the card
  /// arriving.
  Widget _pageTransform(int i, Widget card) {
    final delta = (_page - i).abs().clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(delta);

    // The page is the full height of the frame — the card is centred in it,
    // which is what leaves a gap of glass between one card and the next.
    return Center(
      child: Transform.scale(
        scale: 1 - 0.04 * eased,
        child: Opacity(opacity: 1 - 0.25 * eased, child: card),
      ),
    );
  }
}

/// The pane itself: the page behind the frame, blurred, under a wash of plain
/// white and a lit edge.
///
/// Nothing here is tinted, and nothing is painted behind the blur — the glass
/// has no colour of its own, so it shows whatever the page happens to put
/// behind it and reads as glass rather than as a coloured panel.
class _GlassPane extends StatelessWidget {
  const _GlassPane();

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_frameRadius),
          // Enough white to lift the pane off the page, little enough that it
          // is still obviously see-through.
          color: Colors.white.withValues(alpha: 0.42),
          // A lit edge is most of what says "glass"; without it the pane is
          // just a paler rectangle.
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.65),
            width: 1,
          ),
          // A neutral sheen down the pane — white to nothing, no hue.
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.30),
              Colors.white.withValues(alpha: 0.04),
            ],
          ),
        ),
      ),
    );
  }
}

/// A band of frost along one edge of the frame, blurring what passes under it
/// harder the closer it gets to the edge.
///
/// A single blur would put its own hard line where the band ends, so it is
/// built as a few thin strips of increasing strength with a fading white wash
/// over them — a progressive blur, which reads as depth of glass rather than
/// as a smudged strip.
class _EdgeFrost extends StatelessWidget {
  const _EdgeFrost({required this.top, required this.strength});

  /// Which edge this sits on: the strongest strip goes on the outside.
  final bool top;

  /// How far into the movement the deck is, 0 at rest. Nothing is painted at
  /// all below a whisker of it.
  final double strength;

  /// Outermost first. Three strips is the fewest that still hides its own
  /// steps, and every one costs a blurred layer.
  static const _sigmas = [7.0, 3.0, 1.0];

  @override
  Widget build(BuildContext context) {
    if (strength < 0.02) return const SizedBox.shrink();

    final scaled = [for (final s in _sigmas) s * strength];
    final sigmas = top ? scaled : scaled.reversed.toList();

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              for (final sigma in sigmas)
                Expanded(
                  child: ClipRect(
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
            ],
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: top ? Alignment.topCenter : Alignment.bottomCenter,
                end: top ? Alignment.bottomCenter : Alignment.topCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.26 * strength),
                  Colors.white.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatefulWidget {
  const _ModuleCard({
    super.key,
    required this.module,
    required this.permissions,
    this.onQuickAction,
    required this.onTap,
  });

  final ModuleDescriptor module;
  final EffectivePermissions permissions;
  final void Function(
    String moduleId,
    String actionId,
    String featureId,
    String requiredAction,
  )?
  onQuickAction;
  final VoidCallback onTap;

  @override
  State<_ModuleCard> createState() => _ModuleCardState();
}

class _ModuleCardState extends State<_ModuleCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    final ready = module.status != ModuleStatus.planned;
    final level = widget.permissions.accessLevel(module.id);
    final actions = ready
        ? [
            for (final action in _quickActionsFor(module.id))
              if (widget.permissions.can(
                module.id,
                action.featureId,
                action.requiredAction,
              ))
                action,
          ]
        : const <_QuickAction>[];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: Container(
          height: _cardHeight,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            // Two stops of the same violet, a shade apart. Enough to keep the
            // card from reading as a flat swatch, far short of the hue shift
            // that made the old bars look like a paint chart.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primaryContainer,
              ],
            ),
            borderRadius: BorderRadius.circular(_cardRadius),
            boxShadow: [
              // Light: a card resting on glass, not floating over a page —
              // a heavy shadow only greys the pane it is lying on.
              BoxShadow(
                color: const Color(0xFF2A2350).withValues(alpha: 0.14),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        // Tinted glass rather than a solid white disc — a disc that
                        // size reads as an app icon, which is what made the card
                        // look like a game tile.
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: Icon(module.icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sentence case at normal tracking. Long names still get
                          // no good break points, so one shrinks to fit rather than
                          // folding mid-word.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              module.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.1,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            ready ? level.label : 'Coming soon',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      // A chevron says "opens a screen". The play triangle it
                      // replaces says "starts a level".
                      ready
                          ? Icons.chevron_right_rounded
                          : Icons.schedule_rounded,
                      color: Colors.white.withValues(alpha: ready ? 0.9 : 0.55),
                      size: ready ? 26 : 20,
                    ),
                  ],
                ),
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final action in actions)
                      _QuickActionButton(
                        action: action,
                        onTap: widget.onQuickAction == null
                            ? widget.onTap
                            : () => widget.onQuickAction!(
                                module.id,
                                action.id,
                                action.featureId,
                                action.requiredAction,
                              ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(
    this.id,
    this.label,
    this.icon,
    this.featureId,
    this.requiredAction,
  );

  final String id;
  final String label;
  final IconData icon;
  final String featureId;
  final String requiredAction;
}

List<_QuickAction> _quickActionsFor(String moduleId) => switch (moduleId) {
  ModuleCatalog.examination => const [
    _QuickAction(
      'schedule',
      'Schedule',
      Icons.event_note_outlined,
      'publishing',
      ModuleActions.read,
    ),
    _QuickAction(
      'marks',
      'Marks',
      Icons.edit_note_outlined,
      'marks',
      ModuleActions.read,
    ),
    _QuickAction(
      'results',
      'Results',
      Icons.insights_outlined,
      'grades',
      ModuleActions.read,
    ),
  ],
  ModuleCatalog.timetable => const [
    _QuickAction(
      'schedule',
      'Schedule',
      Icons.calendar_month_outlined,
      'schedule',
      ModuleActions.read,
    ),
    _QuickAction(
      'substitution',
      'Substitutions',
      Icons.swap_horiz_rounded,
      'substitution',
      ModuleActions.read,
    ),
  ],
  ModuleCatalog.academics => const [
    _QuickAction(
      'attendance',
      'Attendance',
      Icons.fact_check_outlined,
      'attendance',
      ModuleActions.read,
    ),
    _QuickAction(
      'marks',
      'Marks',
      Icons.edit_note_outlined,
      'marks',
      ModuleActions.read,
    ),
    _QuickAction(
      'analysis',
      'Analysis',
      Icons.insights_outlined,
      'analysis',
      ModuleActions.read,
    ),
  ],
  ModuleCatalog.attendance => const [
    _QuickAction(
      'roster',
      'Roster',
      Icons.groups_outlined,
      'roster',
      ModuleActions.read,
    ),
    _QuickAction(
      'leave',
      'Leave',
      Icons.event_busy_outlined,
      'leave',
      ModuleActions.read,
    ),
  ],
  ModuleCatalog.canteen => const [
    _QuickAction(
      'menu',
      'Menu',
      Icons.restaurant_menu_outlined,
      'menu',
      ModuleActions.read,
    ),
    _QuickAction(
      'orders',
      'Orders',
      Icons.receipt_long_outlined,
      'order',
      ModuleActions.read,
    ),
    _QuickAction(
      'wallet',
      'Wallet',
      Icons.account_balance_wallet_outlined,
      'wallet',
      ModuleActions.read,
    ),
  ],
  ModuleCatalog.gatepass => const [
    _QuickAction(
      'outpass',
      'Outpass',
      Icons.directions_walk_outlined,
      'outpass',
      ModuleActions.read,
    ),
    _QuickAction(
      'visitors',
      'Visitors',
      Icons.people_outline,
      'visitor',
      ModuleActions.read,
    ),
    _QuickAction(
      'access',
      'Access',
      Icons.door_front_door_outlined,
      'access',
      ModuleActions.read,
    ),
  ],
  _ => const [],
};

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.action, required this.onTap});

  final _QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: action.label,
      child: Material(
        color: Colors.white.withValues(alpha: 0.16),
        shape: const CircleBorder(),
        child: InkWell(
          key: ValueKey('quick-action-${action.id}'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Icon(action.icon, color: Colors.white, size: 23),
          ),
        ),
      ),
    );
  }
}

/// Which card is in the frame, and how many are waiting. Reads the same
/// continuous position as the cards, so a dot brightens as its card arrives
/// rather than snapping when it lands.
class _DotRail extends StatelessWidget {
  const _DotRail({
    required this.modules,
    required this.position,
    required this.onSelect,
  });

  final List<ModuleDescriptor> modules;
  final double position;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    // A long module list would run the rail past the bottom of the frame, so
    // past roughly seven the dots shrink to fit rather than overflow.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < modules.length; i++)
            GestureDetector(
              key: ValueKey('module-dot-${modules[i].id}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 5),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.primary,
                      (1 - (position - i).abs()).clamp(0.0, 1.0),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
