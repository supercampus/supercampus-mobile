import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/gatepass_models.dart';

const gatepassGradient = LinearGradient(
  colors: [AppColors.gateBlue, AppColors.gateMagenta],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class GatepassSurface extends StatelessWidget {
  const GatepassSurface({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: context.adaptive(
            light: const Color(0xFFE8E8EC),
            dark: context.palette.border,
          ),
        ),
      ),
      child: child,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 5),
              Text(subtitle),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
