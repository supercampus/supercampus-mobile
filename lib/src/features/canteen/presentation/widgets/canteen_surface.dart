import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

class CanteenPageBody extends StatelessWidget {
  const CanteenPageBody({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 22, 20, 32),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(padding: padding, children: children),
        ),
      ),
    );
  }
}

class CanteenSurface extends StatelessWidget {
  const CanteenSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: color == Colors.white
          ? const BorderSide(color: AppColors.border)
          : BorderSide.none,
    );

    return Material(
      color: color,
      shape: shape,
      child: onTap == null
          ? Padding(padding: padding, child: child)
          : InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onTap,
              child: Padding(padding: padding, child: child),
            ),
    );
  }
}

class CanteenPageHeader extends StatelessWidget {
  const CanteenPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 5),
              Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

class StudentAvatar extends StatelessWidget {
  const StudentAvatar({super.key, required this.initials, this.size = 46});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.amber),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: AppColors.ink,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
