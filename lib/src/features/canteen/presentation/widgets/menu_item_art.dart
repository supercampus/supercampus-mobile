import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/canteen_models.dart';

class MenuItemArt extends StatelessWidget {
  const MenuItemArt({super.key, required this.item, this.size = 72});

  final CanteenMenuItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background) = switch (item.category) {
      MenuCategory.meals => (
        Icons.rice_bowl_outlined,
        AppColors.primary,
        const Color(0xFFE7F3EC),
      ),
      MenuCategory.snacks => (
        Icons.bakery_dining_outlined,
        const Color(0xFFB96708),
        AppColors.amberSoft,
      ),
      MenuCategory.drinks => (
        Icons.local_cafe_outlined,
        const Color(0xFF2563A9),
        const Color(0xFFE7F0FC),
      ),
    };

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: size * 0.46, color: color),
    );
  }
}
