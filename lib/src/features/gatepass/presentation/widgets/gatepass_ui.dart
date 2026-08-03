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
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE8E8EC)),
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
    final (color, background) = switch (status) {
      ApprovalStatus.approved => (
        const Color(0xFF087A4B),
        const Color(0xFFE7F7EF),
      ),
      ApprovalStatus.pending => (
        const Color(0xFF8A5A00),
        const Color(0xFFFFF4D6),
      ),
      ApprovalStatus.rejected => (
        const Color(0xFFB42318),
        const Color(0xFFFFE9E7),
      ),
      ApprovalStatus.completed => (AppColors.gateBlue, const Color(0xFFECEAFF)),
      ApprovalStatus.cancelled => (AppColors.muted, const Color(0xFFF0F1F3)),
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
