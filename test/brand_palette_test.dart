import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/module_catalog.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';

void main() {
  test('SuperCampus uses the approved permanent brand palette', () {
    expect(AppColors.brandPurple, const Color(0xFF7B42F6));
    expect(AppColors.brandPink, const Color(0xFFFF2D95));
    expect(AppColors.brandViolet, const Color(0xFF9B1FE8));
    expect(AppColors.primary, AppColors.brandPurple);
    expect(AppColors.violetGradient.colors, const [
      Color(0xFF7B42F6),
      Color(0xFFFF2D95),
    ]);
  });

  test('module identity colours stay inside the approved brand palette', () {
    final approved = {
      AppColors.brandPurple,
      AppColors.hotPinkInk,
      AppColors.brandViolet,
    };

    for (final module in ModuleCatalog.all) {
      expect(
        approved,
        contains(module.color),
        reason: '${module.id} must use the SuperCampus brand palette',
      );
    }
  });
}
