import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/access/module_catalog.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';

void main() {
  test('SuperCampus uses the approved permanent brand palette', () {
    expect(AppColors.brandBlue, const Color(0xFF1400FF));
    expect(AppColors.brandMagenta, const Color(0xFFA600FF));
    expect(AppColors.brandLavender, const Color(0xFF776CF5));
    expect(AppColors.violetGradient.colors, const [
      Color(0xFF1400FF),
      Color(0xFFA600FF),
    ]);
  });

  test('module identity colours stay inside the approved brand palette', () {
    final approved = {Color(0xFF1400FF), Color(0xFFA600FF), Color(0xFF776CF5)};

    for (final module in ModuleCatalog.all) {
      expect(
        approved,
        contains(module.color),
        reason: '${module.id} must use the SuperCampus brand palette',
      );
    }
  });
}
