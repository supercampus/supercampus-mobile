import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/gatepass_models.dart';
import '../../data/gatepass_pass_phase.dart';

const gatepassGradient = LinearGradient(
  colors: [AppColors.gateBlue, AppColors.gateMagenta],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Corner radius shared by every gatepass card so the module reads as one
/// family of surfaces.
const gatepassCardRadius = 16.0;

/// System-like type ramp with size-specific tracking: large text tightens,
/// small text opens up slightly so it stays legible.
abstract final class GatepassType {
  static TextStyle largeTitle(BuildContext context) => TextStyle(
    fontSize: 24,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: context.palette.ink,
  );

  static TextStyle title(BuildContext context) => TextStyle(
    fontSize: 20,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    color: context.palette.ink,
  );

  static TextStyle headline(BuildContext context) => TextStyle(
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    color: context.palette.ink,
  );

  static TextStyle body(BuildContext context) => TextStyle(
    fontSize: 14,
    height: 1.4,
    letterSpacing: -0.1,
    color: context.palette.ink,
  );

  static TextStyle secondary(BuildContext context) => TextStyle(
    fontSize: 14,
    height: 1.4,
    letterSpacing: -0.1,
    color: context.palette.inkSecondary,
  );

  static TextStyle footnote(BuildContext context) => TextStyle(
    fontSize: 12.5,
    height: 1.35,
    letterSpacing: 0,
    color: context.palette.inkSecondary,
  );

  static TextStyle sectionLabel(BuildContext context) => TextStyle(
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: context.palette.inkSecondary,
  );
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "26 Sep" — compact day and month, used inside pass windows.
String gatepassDay(DateTime date) => '${date.day} ${_months[date.month - 1]}';

/// "4:00 PM" — same shape as the app-wide time formatter.
String gatepassTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}

/// "26 Sep, 4:00 PM".
String gatepassMoment(DateTime date) =>
    '${gatepassDay(date)}, ${gatepassTime(date)}';

class GatepassSurface extends StatelessWidget {
  const GatepassSurface({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    // A Material (not a decorated box) so list rows and ink responses inside
    // the card paint their press feedback on it.
    return Material(
      color: context.palette.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(gatepassCardRadius),
        side: BorderSide(
          color: context.adaptive(
            light: const Color(0xFFE9E9EE),
            dark: context.palette.border,
          ),
        ),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
  }
}

/// A card that acknowledges a touch the instant it lands: it settles to 98%
/// scale on press and springs back on release or cancel.
class GatepassPressable extends StatefulWidget {
  const GatepassPressable({
    super.key,
    required this.child,
    required this.onTap,
    this.color,
    this.padding,
    this.borderColor,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final String? semanticLabel;

  @override
  State<GatepassPressable> createState() => _GatepassPressableState();
}

class _GatepassPressableState extends State<GatepassPressable> {
  var _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(gatepassCardRadius);
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: widget.color ?? context.palette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color:
                  widget.borderColor ??
                  context.adaptive(
                    light: const Color(0xFFE9E9EE),
                    dark: context.palette.border,
                  ),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: widget.onTap == null ? null : (_) => _set(true),
            onTapUp: (_) => _set(false),
            onTapCancel: () => _set(false),
            splashFactory: NoSplash.splashFactory,
            child: Padding(
              padding: widget.padding ?? EdgeInsets.zero,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class GatepassSectionHeader extends StatelessWidget {
  const GatepassSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            Expanded(
              child: Text(title, style: GatepassType.sectionLabel(context)),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Foreground and soft background for a status tone, in both themes.
(Color, Color) gatepassTone(BuildContext context, GatepassPassPhase phase) {
  final p = context.palette;
  return switch (phase) {
    GatepassPassPhase.active => (
      context.adaptive(
        light: const Color(0xFF087A4B),
        dark: const Color(0xFF6EE7B7),
      ),
      p.successSoft,
    ),
    GatepassPassPhase.upcoming => (
      p.brandInk,
      context.adaptive(light: const Color(0xFFEEF0FF), dark: p.brandSoft),
    ),
    GatepassPassPhase.pending => (
      context.adaptive(
        light: const Color(0xFF8A5A00),
        dark: const Color(0xFFFCD34D),
      ),
      p.warningSoft,
    ),
    GatepassPassPhase.rejected => (
      context.adaptive(
        light: const Color(0xFFB42318),
        dark: const Color(0xFFFCA5A5),
      ),
      p.dangerSoft,
    ),
    GatepassPassPhase.completed ||
    GatepassPassPhase.expired ||
    GatepassPassPhase.cancelled => (p.inkSecondary, p.surfaceMuted),
  };
}

class PassPhaseChip extends StatelessWidget {
  const PassPhaseChip({super.key, required this.phase});

  final GatepassPassPhase phase;

  @override
  Widget build(BuildContext context) {
    final (color, background) = gatepassTone(context, phase);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        phase.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          height: 1.2,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

class ApprovalPill extends StatelessWidget {
  const ApprovalPill({super.key, required this.status});

  final ApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (color, background) = switch (status) {
      ApprovalStatus.approved => (
        context.adaptive(
          light: const Color(0xFF087A4B),
          dark: const Color(0xFF6EE7B7),
        ),
        p.successSoft,
      ),
      ApprovalStatus.pending => (
        context.adaptive(
          light: const Color(0xFF8A5A00),
          dark: const Color(0xFFFCD34D),
        ),
        p.warningSoft,
      ),
      ApprovalStatus.rejected => (
        context.adaptive(
          light: const Color(0xFFB42318),
          dark: const Color(0xFFFCA5A5),
        ),
        p.dangerSoft,
      ),
      ApprovalStatus.completed => (
        p.brandInk,
        context.adaptive(light: const Color(0xFFECEAFF), dark: p.brandSoft),
      ),
      ApprovalStatus.cancelled => (
        p.inkSecondary,
        context.adaptive(light: const Color(0xFFF0F1F3), dark: p.surfaceMuted),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

/// In-page intro line for screens that already carry their title in the app
/// bar. The title is kept for semantics but not repeated visually.
class GatepassPageHeader extends StatelessWidget {
  const GatepassPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      label: title,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Expanded(
            child: Text(subtitle, style: GatepassType.secondary(context)),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
