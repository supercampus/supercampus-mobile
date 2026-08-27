import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/swipe_action_card.dart';

/// The three marks a student can carry on a roll.
///
/// Colours are the reference card's, sampled from it rather than approximated.
enum AttendanceMark {
  present('present', 'Present', Color(0xFF00B207), Icons.check_circle),
  absent('absent', 'Absent', Color(0xFFC90000), Icons.cancel),
  onDuty('od', 'On duty', Color(0xFFFFD600), Icons.shield);

  const AttendanceMark(this.wire, this.label, this.color, this.icon);

  /// What the API stores.
  final String wire;
  final String label;
  final Color color;
  final IconData icon;

  static AttendanceMark fromWire(String? value) => switch (value) {
    'absent' => AttendanceMark.absent,
    'od' => AttendanceMark.onDuty,
    _ => AttendanceMark.present,
  };
}

/// One student on the roll.
///
/// Every measurement is a fraction of the card's own height, taken from the
/// reference artwork (866 × 159), so the card keeps its proportions at any
/// width instead of drifting as the phone changes:
///
/// | element            | reference | fraction of height |
/// | ------------------ | --------- | ------------------ |
/// | card               | 866 × 159 | aspect 5.446       |
/// | corner radius      | 17        | 0.107              |
/// | avatar diameter    | 96        | 0.604              |
/// | left padding       | 40        | 0.252              |
/// | avatar → text gap  | 27        | 0.170              |
/// | name size          | 34        | 0.214              |
/// | second line size   | 27        | 0.170              |
/// | badge              | 54 (r 8)  | 0.340 (r 0.050)    |
/// | badge right inset  | 53        | 0.333              |
///
/// A class is present until told otherwise, so present is the resting state and
/// the two swipes are the exceptions to it: **left marks absent, right grants
/// on duty.** Tapping a marked row puts the student back to present.
class AttendanceRosterRow extends StatelessWidget {
  const AttendanceRosterRow({
    super.key,
    required this.name,
    required this.number,
    required this.mark,
    required this.onMark,
    this.programme,
    this.department,
    this.photoUrl,
    this.enabled = true,
  });

  final String name;
  final String number;

  /// e.g. "B.E. Artificial Intelligence and Data Science". Only its degree —
  /// the leading token — reaches the card.
  final String? programme;

  /// e.g. "AIDS".
  final String? department;

  final String? photoUrl;
  final AttendanceMark mark;
  final ValueChanged<AttendanceMark> onMark;
  final bool enabled;

  /// The reference card's proportions.
  static const double aspect = 866 / 159;

  /// How much of the reference height a row actually takes.
  ///
  /// At full size a card is a sixth of a phone screen, and a class of forty
  /// becomes a long scroll. Every measurement below is a fraction of the height
  /// this yields, so the card keeps the reference's internal proportions
  /// exactly — the whole thing is simply drawn smaller, which is the one
  /// deviation from the artwork and a deliberate one.
  static const double density = 0.84;

  static const double _radius = 17 / 159;
  static const double _avatar = 96 / 159;
  static const double _padLeft = 40 / 159;
  static const double _avatarGap = 27 / 159;
  static const double _nameSize = 34 / 159;
  static const double _metaSize = 27 / 159;
  static const double _badge = 54 / 159;
  static const double _badgeRadius = 8 / 159;
  static const double _padRight = 53 / 159;
  static const double gapBetweenCards = 25 / 159;

  /// "MEC26AI001 | B.E., AIDS" — the roll number, the degree, the department.
  String get _meta {
    final degree = (programme ?? '').split(' ').first;
    final tail = [
      if (degree.isNotEmpty) degree,
      if ((department ?? '').isNotEmpty) department!,
    ].join(', ');
    return tail.isEmpty ? number : '$number  |  $tail';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final marked = mark != AttendanceMark.present;

    return Padding(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxWidth / aspect * density;
          return Padding(
            padding: EdgeInsets.only(bottom: gapBetweenCards * height),
            child: SizedBox(
              height: height,
              child: SwipeActionCard(
                enabled: enabled,
                dismissOnCommit: false,
                // Right: consent to on duty.
                forward: mark == AttendanceMark.onDuty
                    ? null
                    : SwipeAction(
                        label: AttendanceMark.onDuty.label,
                        icon: AttendanceMark.onDuty.icon,
                        color: AttendanceMark.onDuty.color,
                        foreground: AppColors.ink,
                        onCommit: () => onMark(AttendanceMark.onDuty),
                      ),
                // Left: mark absent.
                backward: mark == AttendanceMark.absent
                    ? null
                    : SwipeAction(
                        label: AttendanceMark.absent.label,
                        icon: AttendanceMark.absent.icon,
                        color: AttendanceMark.absent.color,
                        onCommit: () => onMark(AttendanceMark.absent),
                      ),
                child: Material(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(_radius * height),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    // Only a marked student has anywhere to go back to.
                    onTap: enabled && marked
                        ? () => onMark(AttendanceMark.present)
                        : null,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: _padLeft * height,
                        right: _padRight * height,
                      ),
                      child: Row(
                        children: [
                          _Avatar(
                            name: name,
                            photoUrl: photoUrl,
                            size: _avatar * height,
                          ),
                          SizedBox(width: _avatarGap * height),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: _nameSize * height,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface,
                                    // Tracking tightens as type grows.
                                    letterSpacing: -0.2,
                                    height: 1.15,
                                  ),
                                ),
                                SizedBox(height: 0.03 * height),
                                Text(
                                  _meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: _metaSize * height,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    letterSpacing: 0.1,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: _avatarGap * height),
                          _MarkBadge(
                            mark: mark,
                            size: _badge * height,
                            radius: _badgeRadius * height,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The student's photo, or their initials when there is none.
///
/// No account carries a photo yet, so initials are the ordinary case rather
/// than the fallback — a grey silhouette for forty students in a row would
/// carry no information at all.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.photoUrl,
    required this.size,
  });

  final String name;
  final String? photoUrl;
  final double size;

  String get _initials {
    final parts = name.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    final letters = parts.take(2).map((p) => p[0]).join();
    return letters.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final url = photoUrl;

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Container(
          color: theme.colorScheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: url == null || url.isEmpty
              ? Text(
                  _initials,
                  style: TextStyle(
                    fontSize: size * 0.36,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                    letterSpacing: 0.2,
                  ),
                )
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  width: size,
                  height: size,
                  // A broken photo must not cost the row its identity.
                  errorBuilder: (context, _, _) => Text(
                    _initials,
                    style: TextStyle(
                      fontSize: size * 0.36,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// The rounded square on the right: green check, amber shield, red cross.
class _MarkBadge extends StatelessWidget {
  const _MarkBadge({
    required this.mark,
    required this.size,
    required this.radius,
  });

  final AttendanceMark mark;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: mark.label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: mark.color,
          borderRadius: BorderRadius.circular(radius),
        ),
        alignment: Alignment.center,
        child: Icon(
          mark.icon,
          size: size * 0.64,
          // White on all three, as the reference draws them — the amber is
          // light, but the glyph is a solid shape rather than text, so it
          // holds up.
          color: Colors.white,
        ),
      ),
    );
  }
}
