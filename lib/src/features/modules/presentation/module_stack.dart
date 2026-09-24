// ignore_for_file: unused_element
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/access/academic_presentation.dart';
import '../../../core/access/effective_permissions.dart';
import '../../../core/access/module_catalog.dart';
import 'today_glance.dart';

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
/// Live content for the cards that show more than their own name.
///
/// The boards for attendance and gatepass draw real information — today's roll
/// call, the pass itself. Everything here is optional: with nothing supplied
/// each card falls back to a state that is true rather than to invented data.
class ModuleCardContent {
  const ModuleCardContent({this.attendanceMarks, this.gatepassQr, this.shops});

  /// The seven latest published subject rolls, oldest to newest. Null is an
  /// unused leading position when fewer than seven rolls have been published.
  final List<AttendanceMark?>? attendanceMarks;

  /// What the gatepass panel should encode. Null draws the module's glyph
  /// instead of a code, so the card never shows a scannable square that means
  /// nothing.
  final String? gatepassQr;

  /// The storefronts in the grid on the shops board. Null uses the campus shop
  /// types, which is what the board draws; supply this to show the tenant's own
  /// shops instead. Every one of them opens the shop list.
  final List<ModuleShopShortcut>? shops;
}

/// One storefront tile on the shops board.
class ModuleShopShortcut {
  const ModuleShopShortcut(this.id, this.label, this.icon);

  final String id;
  final String label;
  final IconData icon;
}

/// The shop types SuperCampus ships with, in the order the board draws them.
const _defaultShops = <ModuleShopShortcut>[
  ModuleShopShortcut('food', 'Canteen', Icons.restaurant_rounded),
  ModuleShopShortcut('drinks', 'Beverages', Icons.local_cafe_rounded),
  ModuleShopShortcut('stationery', 'Stationery', Icons.edit_rounded),
  ModuleShopShortcut('laundry', 'Laundry', Icons.local_laundry_service_rounded),
];

class ModuleStack extends StatelessWidget {
  const ModuleStack({
    super.key,
    required this.modules,
    required this.permissions,
    required this.onOpenModule,
    this.onQuickAction,
    this.onIndexChanged,
    this.content = const ModuleCardContent(),
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

  /// What the module-specific panels should draw. See [ModuleCardContent].
  final ModuleCardContent content;

  static double heightFor(int moduleCount) =>
      moduleCount <= 0 ? 0 : (_cardHeight * moduleCount + 14 * (moduleCount - 1));

  @override
  Widget build(BuildContext context) {
    if (modules.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < modules.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _ModuleCard(
            key: ValueKey('module-card-${modules[i].id}'),
            front: true,
            content: content,
            module: modules[i],
            permissions: permissions,
            onQuickAction: onQuickAction,
            onTap: () => onOpenModule(modules[i].id),
          ),
        ],
      ],
    );
  }
}

/// The card is the reference artwork's own shape: the three boards are all
/// 360 tall on a ~756 wide card, so the card is a touch over 2:1 and every
/// measurement below is that artwork's, scaled by [_k].
const _cardHeight = 157.0;

/// Artwork pixel -> card pixel.
const _k = _cardHeight / 360;

const _cardRadius = 32 * _k;

/// The border of card colour around everything inside it: 33 on the artwork,
/// on all four sides.
const _cardPad = 33 * _k;

/// The gap between neighbouring cells.
const _cellGap = 28 * _k;

/// Corner radii, off the artwork: the hero cell and the big left block, the
/// action tiles, and the small attendance marks.
const _heroRadius = 26 * _k;
const _tileRadius = 24 * _k;
const _markRadius = 12 * _k;

/// Padding inside a hero cell, and the icon plate that sits in it.
const _heroPad = 22 * _k;
const _heroPlate = 93 * _k;
const _heroGlyph = 44 * _k;

/// Type off the artwork: the module name, and the line under it.
const _titleSize = 38 * _k;
const _captionSize = 26 * _k;

/// The glyph in an action tile — the boards draw these large and solid.
const _tileGlyph = 60 * _k;

/// The colours a card is painted in.
///
/// The reference boards give every module its own palette rather than tinting
/// one shared surface, and that is most of why they read as distinct objects
/// instead of rows in a list. The values here are sampled straight off those
/// boards, so a card can be checked against its image.
class _CardPalette {
  const _CardPalette({
    required this.from,
    required this.to,
    required this.hero,
    required this.plate,
    required this.tiles,
  });

  /// The card's own gradient, top-left to bottom-right.
  final Color from;
  final Color to;

  /// The hero cell, and the icon plate that sits inside it.
  final Color hero;
  final Color plate;

  /// Action tiles, in order. The boards give neighbouring tiles visibly
  /// different colours; the list cycles when a module has more actions than
  /// the board drew.
  final List<Color> tiles;

  Color tile(int i) => tiles[i % tiles.length];
}

/// 13.png, 14.png, 15.png.
const _boardPalettes = <String, _CardPalette>{
  ModuleCatalog.attendance: _CardPalette(
    from: Color(0xFF4200FF),
    to: Color(0xFF9600FF),
    hero: Color(0xFF30258D),
    plate: Color(0xFF776CF5),
    tiles: [Color(0xFF776CF5), Color(0xFF4200FF), Color(0xFF9600FF)],
  ),
  ModuleCatalog.gatepass: _CardPalette(
    from: Color(0xFF4200FF),
    to: Color(0xFF9600FF),
    hero: Color(0xFF4E35EE),
    plate: Color(0xFF776CF5),
    tiles: [Color(0xFF4200FF), Color(0xFF776CF5), Color(0xFF9600FF)],
  ),
  ModuleCatalog.canteen: _CardPalette(
    from: Color(0xFF4200FF),
    to: Color(0xFF9600FF),
    hero: Color(0xFF30258D),
    plate: Color(0xFF776CF5),
    tiles: [
      Color(0xFF776CF5),
      Color(0xFF9600FF),
      Color(0xFF594DE5),
      Color(0xFF4200FF),
    ],
  ),
};

/// Staff **Attendance**.
///
/// A brighter brand gradient distinguishes the operational staff surface from
/// the calmer learner streak card without leaving the SuperCampus palette.
const _staffAttendancePalette = _CardPalette(
  from: Color(0xFF4200FF),
  to: Color(0xFF9600FF),
  hero: Color(0xFF30258D),
  plate: Color(0xFF776CF5),
  tiles: [Color(0xFF776CF5), Color(0xFF4200FF), Color(0xFF9600FF)],
);

/// Everything the boards did not draw is built from the module's own catalog
/// colour, in the same register: a deep saturated card, a slightly lifted hero,
/// and four tile steps that keep neighbouring tiles apart.
_CardPalette _paletteFor(ModuleDescriptor module, EffectivePermissions perms) {
  final presentation = academicPresentationFor(perms);
  if (presentation == AcademicPresentation.learner &&
      academicModules.contains(module.id)) {
    return _boardPalettes[ModuleCatalog.attendance]!;
  }
  if (presentation == AcademicPresentation.staff &&
      module.id == ModuleCatalog.attendance) {
    return _staffAttendancePalette;
  }

  final preset = _boardPalettes[module.id];
  if (preset != null) return preset;
  return _paletteFromSeed(module);
}

_CardPalette _paletteFromSeed(ModuleDescriptor module) {
  switch (module.id) {
    case ModuleCatalog.administration:
      return const _CardPalette(
        from: Color(0xFF1E293B),
        to: Color(0xFF334155),
        hero: Color(0xFF0F172A),
        plate: Color(0xFF475569),
        tiles: [
          Color(0xFF334155),
          Color(0xFF475569),
          Color(0xFF64748B),
          Color(0xFF1E293B),
        ],
      );
    case ModuleCatalog.examination:
      return const _CardPalette(
        from: Color(0xFF1E40AF),
        to: Color(0xFF3B82F6),
        hero: Color(0xFF172554),
        plate: Color(0xFF2563EB),
        tiles: [
          Color(0xFF2563EB),
          Color(0xFF3B82F6),
          Color(0xFF60A5FA),
          Color(0xFF1D4ED8),
        ],
      );
    case ModuleCatalog.timetable:
      return const _CardPalette(
        from: Color(0xFF5B21B6),
        to: Color(0xFF7C3AED),
        hero: Color(0xFF4C1D95),
        plate: Color(0xFF6D28D9),
        tiles: [
          Color(0xFF7C3AED),
          Color(0xFF8B5CF6),
          Color(0xFF6D28D9),
          Color(0xFF5B21B6),
        ],
      );
    case ModuleCatalog.canteen:
      return const _CardPalette(
        from: Color(0xFF9A3412),
        to: Color(0xFFC2410C),
        hero: Color(0xFF7C2D12),
        plate: Color(0xFFEA580C),
        tiles: [
          Color(0xFFEA580C),
          Color(0xFFF97316),
          Color(0xFFC2410C),
          Color(0xFF9A3412),
        ],
      );
    case ModuleCatalog.tuitionFee:
      return const _CardPalette(
        from: Color(0xFF0F766E),
        to: Color(0xFF0D9488),
        hero: Color(0xFF134E4A),
        plate: Color(0xFF14B8A6),
        tiles: [
          Color(0xFF0D9488),
          Color(0xFF14B8A6),
          Color(0xFF2DD4BF),
          Color(0xFF0F766E),
        ],
      );
    case ModuleCatalog.library:
      return const _CardPalette(
        from: Color(0xFF6B21A8),
        to: Color(0xFF9333EA),
        hero: Color(0xFF581C87),
        plate: Color(0xFF7E22CE),
        tiles: [
          Color(0xFF9333EA),
          Color(0xFFA855F7),
          Color(0xFF7E22CE),
          Color(0xFF6B21A8),
        ],
      );
    case ModuleCatalog.hostel:
      return const _CardPalette(
        from: Color(0xFF334155),
        to: Color(0xFF475569),
        hero: Color(0xFF1E293B),
        plate: Color(0xFF64748B),
        tiles: [
          Color(0xFF475569),
          Color(0xFF64748B),
          Color(0xFF334155),
          Color(0xFF1E293B),
        ],
      );
    case ModuleCatalog.academics:
      return const _CardPalette(
        from: Color(0xFF1E3A8A),
        to: Color(0xFF1D4ED8),
        hero: Color(0xFF172554),
        plate: Color(0xFF2563EB),
        tiles: [
          Color(0xFF2563EB),
          Color(0xFF3B82F6),
          Color(0xFF1D4ED8),
          Color(0xFF1E3A8A),
        ],
      );
    default:
      return const _CardPalette(
        from: Color(0xFF2563EB),
        to: Color(0xFF4F46E5),
        hero: Color(0xFF1E40AF),
        plate: Color(0xFF3B82F6),
        tiles: [
          Color(0xFF3B82F6),
          Color(0xFF4F46E5),
          Color(0xFF6366F1),
          Color(0xFF2563EB),
        ],
      );
  }
}

/// The mark colours on the attendance strip, off 13.png.
const _markPresent = Color(0xFF1DCF00);
const _markAbsent = Color(0xFFFF1723);
const _markOnDuty = Color(0xFFFFD600);
const _markPending = Color(0xFF7C7C7C);

/// Used only when a shops board somehow has no granted action to open; the
/// grid is not built in that case, so it is never run.
const _noAction = _QuickAction(
  'menu',
  'Menu',
  Icons.storefront,
  'menu',
  'read',
);

class _ModuleCard extends StatefulWidget {
  const _ModuleCard({
    super.key,
    required this.module,
    required this.permissions,
    required this.front,
    required this.content,
    this.onQuickAction,
    required this.onTap,
  });

  final ModuleDescriptor module;
  final EffectivePermissions permissions;

  /// Whether this card is the one currently in the frame. Only the front card
  /// opens its module on a tap; the rest scroll themselves into the frame
  /// first, and the hero cell is named for whichever of the two it will do.
  final bool front;

  final ModuleCardContent content;

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
  VoidCallback _run(_QuickAction action) => widget.onQuickAction == null
      ? widget.onTap
      : () => widget.onQuickAction!(
          widget.module.id,
          action.id,
          action.featureId,
          action.requiredAction,
        );

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    final ready = module.status != ModuleStatus.planned;
    final actions = ready
        ? [
            for (final action in _quickActionsFor(module, widget.permissions))
              if (widget.permissions.can(
                module.id,
                action.featureId,
                action.requiredAction,
              ))
                action,
          ]
        : const <_QuickAction>[];
    final subtitle = ready
        ? widget.permissions.accessLevel(module.id).label
        : 'Coming soon';

    final accentColor = module.color;
    final badgeText = subtitle;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(module.icon, color: accentColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                module.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          module.tagline,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFCBD5E1),
                    size: 20,
                  ),
                ],
              ),
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final action in actions)
                      Material(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          onTap: _run(action),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  action.label,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ],
                            ),
                          ),
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

  /// Which board this module is drawn on.
  ///
  /// Three modules have artwork of their own and are built to it. Everything
  /// else gets the shared board, which is the same construction with the
  /// module-specific panel left out.
  Widget _board(
    ModuleDescriptor module,
    _CardPalette palette,
    List<_QuickAction> actions,
    String subtitle,
    bool ready,
  ) {
    if (!ready) {
      if (module.id == ModuleCatalog.tuitionFee) {
        return _feePreviewBoard(module, palette, subtitle);
      }
      return _defaultBoard(module, palette, const [], subtitle, true);
    }
    final presentation = academicPresentationFor(widget.permissions);

    // A learner's folded Academics entry carries their own streak: the strip
    // is one person's sessions — present, absent, not taken yet — so it means
    // something only on the card of the person being counted. Two tiles sit
    // beside the hero, the streak runs underneath.
    if (presentation == AcademicPresentation.learner &&
        academicModules.contains(module.id)) {
      return _attendanceBoard(
        module,
        palette,
        actions.take(3).toList(),
        'Attendance & results',
      );
    }

    if (presentation == AcademicPresentation.staff &&
        module.id == ModuleCatalog.academics) {
      return _staffAcademicBoard(module, palette, actions, subtitle);
    }

    return switch (module.id) {
      // Staff mark other people's records, and no single streak describes a
      // whole class, so their card is the plain board: three even tiles.
      ModuleCatalog.attendance => _staffAttendanceBoard(
        module,
        palette,
        actions.take(4).toList(),
        subtitle,
      ),
      ModuleCatalog.gatepass => _gatepassBoard(
        module,
        palette,
        actions,
        'Gate-in access',
      ),
      ModuleCatalog.canteen => _shopsBoard(module, palette, actions, subtitle),
      ModuleCatalog.examination => _examinationBoard(
        module,
        palette,
        actions,
        subtitle,
      ),
      ModuleCatalog.timetable => _timetableBoard(
        module,
        palette,
        actions,
        subtitle,
      ),
      ModuleCatalog.library => _libraryBoard(
        module,
        palette,
        actions,
        subtitle,
      ),
      ModuleCatalog.hostel => _hostelBoard(module, palette, actions, subtitle),
      _ => _defaultBoard(module, palette, actions, subtitle, false),
    };
  }

  // ---------------------------------------------------------------- 13.png

  /// Hero and one tall tile across the top, today's roll call underneath.
  ///
  /// The board draws a single tile beside the hero. A module with more than one
  /// granted action stacks them in that same column rather than dropping any —
  /// with one action the column is the board exactly.
  Widget _attendanceBoard(
    ModuleDescriptor module,
    _CardPalette palette,
    List<_QuickAction> actions,
    String subtitle,
  ) {
    final marks = widget.content.attendanceMarks;

    return Column(
      children: [
        SizedBox(
          height: 146 * _k,
          child: Row(
            children: [
              Expanded(
                flex: 450,
                child: _heroCell(module, palette, subtitle, radius: 100),
              ),
              if (actions.isNotEmpty) ...[
                SizedBox(width: 25 * _k),
                Expanded(
                  flex: 214,
                  child: Column(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) SizedBox(height: 14 * _k),
                        Expanded(
                          child: _ActionTile(
                            action: actions[i],
                            fill: palette.tile(i),
                            onTap: _run(actions[i]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'last 7 attendance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _captionSize,
                  fontWeight: FontWeight.w400,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 16 * _k),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < attendanceStreakLength; i++) ...[
                    if (i > 0) SizedBox(width: 21 * _k),
                    _mark(
                      marks != null && i < marks.length ? marks[i] : null,
                      position: i + 1,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// One session: taken and present, taken and absent, or not taken yet.
  ///
  /// A session with no record is grey. Nothing is invented — with no data wired
  /// the whole strip reads as "not taken yet", which is true.
  Widget _mark(AttendanceMark? mark, {required int position}) => Semantics(
    label: switch (mark) {
      AttendanceMark.present => 'Recent attendance $position present',
      AttendanceMark.absent => 'Recent attendance $position absent',
      AttendanceMark.onDuty => 'Recent attendance $position on duty',
      null => 'Recent attendance $position has no record',
    },
    child: Container(
      width: 58 * _k,
      height: 59 * _k,
      decoration: BoxDecoration(
        color: switch (mark) {
          AttendanceMark.present => _markPresent,
          AttendanceMark.absent => _markAbsent,
          AttendanceMark.onDuty => _markOnDuty,
          null => _markPending,
        },
        borderRadius: BorderRadius.circular(_markRadius),
      ),
    ),
  );

  /// Attendance is an operational card: the primary roll action is large,
  /// while roster and reports remain smaller supporting tools.
  Widget _staffAttendanceBoard(
    ModuleDescriptor module,
    _CardPalette palette,
    List<_QuickAction> actions,
    String subtitle,
  ) {
    final primaryIndex = actions.indexWhere((action) => action.id == 'mark');
    final primary = actions.isEmpty
        ? null
        : actions[primaryIndex < 0 ? 0 : primaryIndex];
    final support = actions.where((action) => action != primary).toList();
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Column(
            children: [
              Expanded(child: _heroCell(module, palette, subtitle)),
              if (primary != null) ...[
                SizedBox(height: 16 * _k),
                SizedBox(
                  height: 92 * _k,
                  child: _labelAction(primary, palette.tile(2), wide: true),
                ),
              ],
            ],
          ),
        ),
        if (support.isNotEmpty) ...[
          SizedBox(width: _cellGap),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                for (var i = 0; i < support.length; i++) ...[
                  if (i > 0) SizedBox(height: 14 * _k),
                  Expanded(
                    child: _labelAction(
                      support[i],
                      palette.tile(i),
                      wide: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Staff Academics is a people-first board. The identity sits above the
  /// main student/subject destination and the remaining tools form a side rail.
  Widget _staffAcademicBoard(
    ModuleDescriptor module,
    _CardPalette palette,
    List<_QuickAction> actions,
    String subtitle,
  ) {
    final primary = actions.isEmpty ? null : actions.first;
    final support = actions.skip(1).take(2).toList();
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: Column(
            children: [
              Expanded(child: _heroCell(module, palette, subtitle)),
              if (primary != null) ...[
                SizedBox(height: 14 * _k),
                SizedBox(
                  height: 78 * _k,
                  child: _labelAction(primary, palette.tile(0), wide: true),
                ),
              ],
            ],
          ),
        ),
        if (support.isNotEmpty) ...[
          SizedBox(width: _cellGap),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                for (var i = 0; i < support.length; i++) ...[
                  if (i > 0) SizedBox(height: 14 * _k),
                  Expanded(
                    child: _ActionTile(
                      action: support[i],
                      fill: palette.tile(i + 1),
                      onTap: _run(support[i]),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------- 14.png

  /// Hero over a row of tiles on the left, the pass itself on the right.
  Widget _gatepassBoard(
    ModuleDescriptor module,
    _CardPalette palette,
    List<_QuickAction> actions,
    String subtitle,
  ) {
    return Row(
      key: const ValueKey('gatepass-split-board'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            children: [
              Expanded(child: _heroCell(module, palette, subtitle)),
              if (actions.isNotEmpty) ...[
                SizedBox(height: 12 * _k),
                SizedBox(
                  height: 72 * _k,
                  child: Row(
                    children: [
                      for (var i = 0; i < actions.take(3).length; i++) ...[
                        if (i > 0) SizedBox(width: 10 * _k),
                        Expanded(
                          child: _ActionTile(
                            action: actions[i],
                            fill: palette.tile(i),
                            onTap: _run(actions[i]),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(width: _cellGap),
        // The pass is the reason this card exists. It owns the full height of
        // the right half instead of sharing space with decorative actions.
        AspectRatio(aspectRatio: 1, child: _passPanel(module)),
      ],
    );
  }

  /// The white panel on the right of the gatepass board.
  ///
  /// It draws a code only when there is one to draw. With nothing wired it
  /// shows the module's own glyph instead, so the card never offers a scannable
  /// square that means nothing.
  Widget _passPanel(ModuleDescriptor module) {
    final data = widget.content.gatepassQr;

    return DecoratedBox(
      key: const ValueKey('gatepass-qr-panel'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28 * _k),
      ),
      child: Padding(
        padding: EdgeInsets.all(14 * _k),
        child: data == null
            ? Icon(
                module.icon,
                color: const Color(0xFF171719),
                size: _tileGlyph,
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final side = constraints.maxWidth < constraints.maxHeight
                      ? constraints.maxWidth
                      : constraints.maxHeight;
                  return Center(
                    child: SizedBox.square(
                      key: const ValueKey('gatepass-qr-code-frame'),
                      dimension: side,
                      child: QrImageView(
                        data: data,
                        padding: EdgeInsets.zero,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF171719),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF171719),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  // ---------------------------------------------------------------- 15.png

  /// A block of two stacked rows on the left, a grid of tiles on the right.
  ///
  /// The top row opens the module, the row under it is the module's headline
  /// action — the board names it "wallet" — and everything else goes in the
  /// grid, two columns wide.
  Widget _shopsBoard(
    ModuleDescriptor module,
    _CardPalette palette,
    List<_QuickAction> actions,
    String subtitle,
  ) {
    // The board's second row is the wallet, and its grid is storefronts — not
    // the module's leftover actions. Anything the grid does not show is still
    // one tap away inside the module.
    final headlineAt = actions.indexWhere((a) => a.id == 'wallet');
    final headline = actions.isEmpty
        ? null
        : actions[headlineAt >= 0 ? headlineAt : 0];
    final rest = [
      for (final a in actions)
        if (!identical(a, headline)) a,
    ];

    // The board draws four tiles. The module's own actions take those cells
    // first — none of them is dropped for a storefront — and storefronts fill
    // whatever is left, which is all four once the actions live elsewhere.
    final browse = actions.firstWhere(
      (a) => a.id == 'menu',
      orElse: () => actions.isEmpty ? _noAction : actions.first,
    );
    final shops = widget.content.shops ?? _defaultShops;
    final fill = shops.take((4 - rest.length).clamp(0, shops.length)).toList();
    final cells = [
      for (var i = 0; i < rest.length; i++)
        _ActionTile(
          action: rest[i],
          fill: palette.tile(i),
          onTap: _run(rest[i]),
        ),
      for (var i = 0; i < fill.length; i++)
        _shopTile(fill[i], browse, palette, rest.length + i),
    ];

    return Row(
      children: [
        Expanded(
          flex: 367,
          child: Container(
            decoration: BoxDecoration(
              color: palette.hero,
              borderRadius: BorderRadius.circular(_heroRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
                width: 1.5,
              ),
            ),
            padding: EdgeInsets.all(18 * _k),
            child: Column(
              children: [
                Expanded(
                  child: _labelledRow(
                    key: ValueKey(
                      widget.front
                          ? 'open-module-${module.id}'
                          : 'module-bar-${module.id}',
                    ),
                    label: moduleLabelFor(
                      module,
                      widget.permissions,
                    ).toUpperCase(),
                    icon: module.icon,
                  ),
                ),
                if (headline != null) ...[
                  SizedBox(height: 12 * _k),
                  SizedBox(
                    height: 127 * _k,
                    child: _Pressable(
                      onTap: _run(headline),
                      child: _labelledRow(
                        label: headline.label.toLowerCase(),
                        icon: headline.icon,
                        fill: const Color(0xFF3C3CFF),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (cells.isNotEmpty) ...[
          SizedBox(width: 35 * _k),
          Expanded(flex: 288, child: _grid(cells)),
        ],
      ],
    );
  }

  /// One line of the left block: glyph, label, and the chevron that says it
  /// goes somewhere.
  Widget _labelledRow({
    Key? key,
    required String label,
    required IconData icon,
    Color? fill,
  }) => Container(
    key: key,
    decoration: fill == null
        ? null
        : BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(_tileRadius),
          ),
    padding: EdgeInsets.symmetric(horizontal: 16 * _k),
    child: Row(
      children: [
        Icon(icon, color: Colors.white, size: 46 * _k),
        SizedBox(width: 14 * _k),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                color: Colors.white,
                fontSize: 34 * _k,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                height: 1.1,
              ),
            ),
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: Colors.white, size: 34 * _k),
      ],
    ),
  );

  /// Two columns, however many rows that takes. Nothing is dropped — a fifth
  /// cell makes the rows shorter rather than falling off the card.
  Widget _grid(List<Widget> cells) {
    final rows = (cells.length / 2).ceil();

    return Column(
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) SizedBox(height: 31 * _k),
          Expanded(
            child: Row(
              children: [
                for (var c = 0; c < 2; c++) ...[
                  if (c > 0) SizedBox(width: 34 * _k),
                  Expanded(
                    child: r * 2 + c < cells.length
                        ? cells[r * 2 + c]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _shopTile(
    ModuleShopShortcut shop,
    _QuickAction browse,
    _CardPalette palette,
    int index,
  ) => Tooltip(
    message: shop.label,
    child: _Pressable(
      key: ValueKey('shop-tile-${shop.id}'),
      onTap: _run(browse),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.tile(index),
          borderRadius: BorderRadius.circular(_tileRadius),
        ),
        child: Center(
          child: Icon(shop.icon, color: Colors.white, size: _tileGlyph),
        ),
      ),
    ),
  );

  // ----------------------------------------------------- module personalities

  /// Examination reads like a workbench: one large primary task and two
  /// secondary tools. Labels remain visible because marks and results must not
  /// be confused by icon alone.
  Widget _examinationBoard(
    ModuleDescriptor module,
    _CardPalette palette,
    List<_QuickAction> actions,
    String subtitle,
  ) {
    final primary = actions.isEmpty ? null : actions.first;
    final secondary = actions.skip(1).take(2).toList();
    return Row(
      children: [
        Expanded(
          flex: 7,
          child: Column(
            children: [
              Expanded(child: _heroCell(module, palette, subtitle)),
              if (primary != null) ...[
                SizedBox(height: 16 * _k),
                SizedBox(
                  height: 82 * _k,
                  child: _labelAction(primary, palette.tile(2), wide: true),
                ),
              ],
            ],
          ),
        ),
        if (secondary.isNotEmpty) ...[
          SizedBox(width: _cellGap),
          Expanded(
            flex: 3,
            child: Column(
              children: [
                for (var i = 0; i < secondary.length; i++) ...[
                  if (i > 0) SizedBox(height: 16 * _k),
                  Expanded(
                    child: _labelAction(
                      secondary[i],
                      palette.tile(i),
                      vertical: true,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Timetable uses a calendar-like rail: the module identity is compact and
  /// the schedule is the dominant, wide action beneath it.
  Widget _timetableBoard(
    ModuleDescriptor module,
    _CardPalette palette,
    List<_QuickAction> actions,
    String subtitle,
  ) {
    return Column(
      children: [
        SizedBox(height: 118 * _k, child: _heroCell(module, palette, subtitle)),
        SizedBox(height: 18 * _k),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) SizedBox(width: 18 * _k),
                Expanded(
                  flex: i == 0 ? 5 : 3,
                  child: _labelAction(actions[i], palette.tile(i), wide: true),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Library resembles a shelf: the identity occupies the left, while useful
  /// destinations sit as labelled book spines on the right.
  Widget _libraryBoard(
    ModuleDescriptor module,
    _CardPalette palette,
    List<_QuickAction> actions,
    String subtitle,
  ) {
    return Row(
      key: const ValueKey('library-shelf-board'),
      children: [
        Expanded(flex: 4, child: _heroCell(module, palette, subtitle)),
        if (actions.isNotEmpty) ...[
          SizedBox(width: _cellGap),
          Expanded(
            flex: 6,
            child: actions.length <= 3
                ? Column(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) SizedBox(height: 12 * _k),
                        Expanded(
                          child: _labelAction(
                            actions[i],
                            palette.tile(i),
                            wide: true,
                          ),
                        ),
                      ],
                    ],
                  )
                : _grid([
                    for (var i = 0; i < actions.take(6).length; i++)
                      _ActionTile(
                        action: actions[i],
                        fill: palette.tile(i),
                        onTap: _run(actions[i]),
                      ),
                  ]),
          ),
        ],
      ],
    );
  }

  /// Hostel is arranged like rooms around a central lobby: a tall identity
  /// tile and a compact two-column action grid.
  Widget _hostelBoard(
    ModuleDescriptor module,
    _CardPalette palette,
    List<_QuickAction> actions,
    String subtitle,
  ) {
    return Row(
      key: const ValueKey('hostel-room-grid-board'),
      children: [
        Expanded(flex: 4, child: _heroCell(module, palette, subtitle)),
        if (actions.isNotEmpty) ...[
          SizedBox(width: _cellGap),
          Expanded(
            flex: 6,
            child: _grid([
              for (var i = 0; i < actions.take(4).length; i++)
                _labelAction(actions[i], palette.tile(i), vertical: true),
            ]),
          ),
        ],
      ],
    );
  }

  /// Fee is intentionally calm while the workflow is not yet enabled: the
  /// amount/status area is visually separate from the future payment action.
  Widget _feePreviewBoard(
    ModuleDescriptor module,
    _CardPalette palette,
    String subtitle,
  ) {
    return Row(
      key: const ValueKey('tuition-fee-preview-board'),
      children: [
        Expanded(flex: 6, child: _heroCell(module, palette, subtitle)),
        SizedBox(width: _cellGap),
        Expanded(
          flex: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(_tileRadius),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    color: Colors.white,
                    size: 46 * _k,
                  ),
                  SizedBox(height: 10 * _k),
                  Text(
                    'Dues & receipts',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24 * _k,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _labelAction(
    _QuickAction action,
    Color fill, {
    bool wide = false,
    bool vertical = false,
  }) => Tooltip(
    message: action.label,
    child: _Pressable(
      key: ValueKey('quick-action-${action.id}'),
      onTap: _run(action),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(_tileRadius),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 18 * _k : 10 * _k,
            vertical: 8 * _k,
          ),
          child: Flex(
            direction: vertical ? Axis.vertical : Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                action.icon,
                color: Colors.white,
                size: (vertical ? 38 : 34) * _k,
              ),
              SizedBox(
                width: vertical ? 0 : 10 * _k,
                height: vertical ? 4 * _k : 0,
              ),
              Flexible(
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22 * _k,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  // -------------------------------------------------------------- everything

  /// The shared board: hero across the top, actions in a row underneath. It is
  /// 14.png with the pass panel taken out.
  Widget _defaultBoard(
    ModuleDescriptor module,
    _CardPalette palette,
    List<_QuickAction> actions,
    String subtitle,
    bool comingSoon,
  ) {
    if (actions.isEmpty) {
      return _heroCell(module, palette, subtitle, wide: true);
    }

    return Column(
      children: [
        SizedBox(height: 150 * _k, child: _heroCell(module, palette, subtitle)),
        SizedBox(height: 26 * _k),
        Expanded(
          child: Row(
            children: [
              for (var i = 0; i < actions.take(6).length; i++) ...[
                if (i > 0) SizedBox(width: 20 * _k),
                Expanded(
                  child: _ActionTile(
                    action: actions[i],
                    fill: palette.tile(i),
                    onTap: _run(actions[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// The module's own cell: icon plate, name, access line.
  Widget _heroCell(
    ModuleDescriptor module,
    _CardPalette palette,
    String subtitle, {
    bool wide = false,
    double? radius,
  }) {
    return Container(
      // The hero is what "open this module" means on this card, so it is the
      // cell that carries the name of what tapping it will do. Naming the card
      // as a whole would leave the name pointing at a rectangle whose middle is
      // a quick action.
      key: ValueKey(
        widget.front ? 'open-module-${module.id}' : 'module-bar-${module.id}',
      ),
      decoration: BoxDecoration(
        color: palette.hero,
        borderRadius: BorderRadius.circular(radius ?? _heroRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      padding: EdgeInsets.symmetric(horizontal: _heroPad),
      child: Row(
        children: [
          SizedBox(
            width: _heroPlate,
            height: _heroPlate,
            child: Icon(module.icon, color: Colors.white, size: _heroGlyph),
          ),
          SizedBox(width: 20 * _k),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Long names get no good break points, so one shrinks to fit
                // rather than folding mid-word.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    // Named for the viewer: a learner's card says Academics
                    // where a faculty member's says Attendance.
                    moduleLabelFor(module, widget.permissions),
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _titleSize,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                      height: 1.15,
                    ),
                  ),
                ),
                SizedBox(height: 4 * _k),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.66),
                    fontSize: _captionSize,
                    fontWeight: FontWeight.w400,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (wide) const Spacer(),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: 0.85),
            size: 34 * _k,
          ),
        ],
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

List<_QuickAction> _quickActionsFor(
  ModuleDescriptor module,
  EffectivePermissions permissions,
) => switch (module.id) {
  ModuleCatalog.administration => const [
    _QuickAction(
      'access_control',
      'Users & roles',
      Icons.manage_accounts_outlined,
      'access_control',
      ModuleActions.read,
    ),
    _QuickAction(
      'approvals',
      'Approvals',
      Icons.approval_outlined,
      'approvals',
      ModuleActions.read,
    ),
    _QuickAction(
      'emergency',
      'Emergency',
      Icons.emergency_outlined,
      'emergency',
      ModuleActions.read,
    ),
  ],
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
  ModuleCatalog.academics
      when academicPresentationFor(permissions) == AcademicPresentation.staff =>
    const [
      _QuickAction(
        'programmes',
        'Programmes',
        Icons.school_outlined,
        'programme',
        ModuleActions.read,
      ),
      _QuickAction(
        'subjects',
        'Subjects',
        Icons.menu_book_outlined,
        'subject',
        ModuleActions.read,
      ),
      _QuickAction(
        'classes',
        'Classes',
        Icons.groups_outlined,
        'registration',
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
      'Results',
      Icons.insights_outlined,
      'analysis',
      ModuleActions.read,
    ),
  ],
  ModuleCatalog.attendance => const [
    _QuickAction(
      'roster',
      'Roster',
      Icons.fact_check_outlined,
      'roster',
      ModuleActions.read,
    ),
    _QuickAction(
      'mark',
      'Mark attendance',
      Icons.format_list_bulleted_add,
      'session',
      ModuleActions.create,
    ),
    _QuickAction(
      'history',
      'History',
      Icons.history_rounded,
      'records',
      ModuleActions.read,
    ),
    _QuickAction(
      'reports',
      'Reports',
      Icons.auto_graph_rounded,
      'reports',
      ModuleActions.create,
    ),
  ],
  ModuleCatalog.canteen when module.displayName == 'Accounts' => const [
    _QuickAction(
      'wallet',
      'Student wallets',
      Icons.account_balance_wallet_outlined,
      'wallet',
      ModuleActions.read,
    ),
    _QuickAction(
      'transactions',
      'Transactions',
      Icons.receipt_long_outlined,
      'wallet',
      ModuleActions.read,
    ),
    _QuickAction(
      'top_up',
      'Top up',
      Icons.add_card_outlined,
      'wallet',
      ModuleActions.update,
    ),
  ],
  ModuleCatalog.canteen when module.displayName == 'Stationery' => const [
    _QuickAction(
      'menu',
      'Inventory',
      Icons.inventory_2_outlined,
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
      'order_history',
      'History',
      Icons.history_rounded,
      'order',
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
      'order_history',
      'History',
      Icons.history_rounded,
      'order',
      ModuleActions.read,
    ),
  ],
  ModuleCatalog.gatepass when module.displayName == 'Gate Security' => const [
    _QuickAction(
      'scan',
      'Scan pass',
      Icons.qr_code_scanner_rounded,
      'scan',
      ModuleActions.create,
    ),
    _QuickAction(
      'manual_code',
      'Enter code',
      Icons.pin_outlined,
      'scan',
      ModuleActions.create,
    ),
    _QuickAction(
      'movement_logs',
      'Movement logs',
      Icons.history_rounded,
      'scan',
      ModuleActions.read,
    ),
  ],
  ModuleCatalog.gatepass when module.displayName == 'Approvals' => [
    if (permissions.can(
      ModuleCatalog.gatepass,
      'leave',
      ModuleActions.read,
    )) ...const [
      _QuickAction(
        'leave_pending',
        'Leave requests',
        Icons.fact_check_outlined,
        'leave',
        ModuleActions.read,
      ),
      _QuickAction(
        'leave_history',
        'Leave history',
        Icons.history_rounded,
        'leave',
        ModuleActions.read,
      ),
    ] else ...const [
      _QuickAction(
        'outpass_pending',
        'Outpass requests',
        Icons.fact_check_outlined,
        'outpass',
        ModuleActions.read,
      ),
      _QuickAction(
        'outpass_history',
        'Outpass history',
        Icons.history_rounded,
        'outpass',
        ModuleActions.read,
      ),
    ],
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
  ModuleCatalog.library
      when permissions.can(
        ModuleCatalog.library,
        'visit_pass',
        ModuleActions.approve,
      ) =>
    const [
      _QuickAction(
        'slots',
        'Set slots',
        Icons.event_seat_outlined,
        'capacity',
        'manage',
      ),
      _QuickAction(
        'scan',
        'Scan QR',
        Icons.qr_code_scanner_rounded,
        'visit_pass',
        ModuleActions.approve,
      ),
      _QuickAction(
        'logs',
        'Logs',
        Icons.history_rounded,
        'logs',
        ModuleActions.read,
      ),
      _QuickAction(
        'download',
        'Report',
        Icons.download_outlined,
        'logs',
        ModuleActions.read,
      ),
      _QuickAction(
        'announcement',
        'Announce',
        Icons.campaign_outlined,
        'announcement',
        ModuleActions.create,
      ),
    ],
  ModuleCatalog.library => const [
    _QuickAction(
      'book',
      'Book visit',
      Icons.event_available_outlined,
      'visit_pass',
      ModuleActions.create,
    ),
    _QuickAction(
      'qr',
      'QR pass',
      Icons.qr_code_2_rounded,
      'qr_pass',
      ModuleActions.read,
    ),
    _QuickAction(
      'history',
      'History',
      Icons.history_rounded,
      'visit_history',
      ModuleActions.read,
    ),
  ],
  ModuleCatalog.hostel => const [
    _QuickAction(
      'outpass',
      'Outpass',
      Icons.directions_walk_rounded,
      'outpass',
      ModuleActions.read,
    ),
    _QuickAction(
      'complaints',
      'Complaint',
      Icons.build_circle_outlined,
      'complaints',
      ModuleActions.create,
    ),
    _QuickAction(
      'mess',
      'Mess menu',
      Icons.restaurant_rounded,
      'mess',
      ModuleActions.read,
    ),
    _QuickAction(
      'residency',
      'My room',
      Icons.bed_outlined,
      'residency',
      ModuleActions.read,
    ),
  ],
  ModuleCatalog.vendorManagement => const [
    _QuickAction(
      'vendors',
      'Vendors',
      Icons.store_outlined,
      'vendors',
      ModuleActions.read,
    ),
    _QuickAction(
      'contracts',
      'Contracts',
      Icons.description_outlined,
      'contracts',
      ModuleActions.read,
    ),
    _QuickAction(
      'purchase_orders',
      'Purchase orders',
      Icons.shopping_cart_checkout_outlined,
      'purchase_orders',
      ModuleActions.read,
    ),
    _QuickAction(
      'payments',
      'Payments',
      Icons.payments_outlined,
      'payments',
      ModuleActions.read,
    ),
    _QuickAction(
      'work_orders',
      'Work orders',
      Icons.build_outlined,
      'work_orders',
      ModuleActions.read,
    ),
  ],
  ModuleCatalog.tuitionFee => const [
    _QuickAction(
      'dues',
      'Dues',
      Icons.request_quote_outlined,
      'invoice',
      ModuleActions.read,
    ),
    _QuickAction(
      'pay',
      'Pay fees',
      Icons.payment_outlined,
      'payment',
      ModuleActions.create,
    ),
    _QuickAction(
      'receipts',
      'Receipts',
      Icons.receipt_long_outlined,
      'payment',
      ModuleActions.read,
    ),
  ],
  _ => const [],
};

/// Anything on a card that can be tapped on its own.
///
/// It highlights on press rather than on release, so the feedback lands while
/// the finger is still down instead of after it lifts.
class _Pressable extends StatefulWidget {
  const _Pressable({super.key, required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// One quick action: a rounded tile in its own colour carrying just its glyph.
///
/// The label lives in the tooltip rather than under the icon — the boards put
/// nothing but the glyph in a tile, and at this size a caption would either
/// wrap or be shrunk past reading.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.action,
    required this.fill,
    required this.onTap,
  });

  final _QuickAction action;
  final Color fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: action.label,
      child: _Pressable(
        key: ValueKey('quick-action-${action.id}'),
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(_tileRadius),
          ),
          child: Center(
            child: Icon(action.icon, color: Colors.white, size: _tileGlyph),
          ),
        ),
      ),
    );
  }
}
