import 'package:flutter/material.dart';

/// Standard navigation controls used by every module surface.
class ModuleBackButton extends StatelessWidget {
  const ModuleBackButton({super.key, required this.onPressed, this.color});

  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Back',
    onPressed: onPressed,
    color: color,
    icon: const Icon(Icons.arrow_back),
  );
}

class ModuleHomeButton extends StatelessWidget {
  const ModuleHomeButton({super.key, required this.onPressed, this.color});

  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Home',
    onPressed: onPressed,
    color: color,
    icon: const Icon(Icons.home_outlined),
  );
}
