import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';

void main() {
  test('light mode uses the near-white lavender blush canvas', () {
    expect(AppColors.canvas, const Color(0xFFFCF8FF));
    expect(AppTheme.light.scaffoldBackgroundColor, AppColors.canvas);
    // Dark mode is a layered palette, never pure black.
    expect(AppTheme.dark.scaffoldBackgroundColor, AppPalette.dark.canvas);
    expect(AppTheme.dark.scaffoldBackgroundColor, isNot(Colors.black));
  });
}
