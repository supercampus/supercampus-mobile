import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supercampus_mobile/src/core/theme/app_theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  group('Light theme is unchanged', () {
    test('light palette reproduces the existing light colours', () {
      const p = AppPalette.light;
      expect(p.canvas, AppColors.canvas);
      expect(p.surface, Colors.white);
      expect(p.ink, AppColors.ink);
      expect(p.inkSecondary, AppColors.muted);
      expect(p.border, AppColors.border);
      expect(p.brand, AppColors.primary);
      expect(p.brandInk, AppColors.primary);
      expect(p.brandSoft, AppColors.moduleSoft);
    });

    test('AppTheme.light carries the light palette and its original canvas', () {
      final theme = AppTheme.light;
      expect(theme.extension<AppPalette>(), AppPalette.light);
      expect(theme.scaffoldBackgroundColor, AppColors.canvas);
      expect(theme.appBarTheme.backgroundColor, Colors.white);
    });
  });

  group('Dark theme', () {
    test('surfaces are layered and never pure black', () {
      const p = AppPalette.dark;
      for (final c in [p.canvas, p.surface, p.surfaceRaised, p.surfaceSunken]) {
        expect(c, isNot(Colors.black));
      }
      expect(p.surface.computeLuminance(), greaterThan(p.canvas.computeLuminance()));
      expect(p.surfaceRaised.computeLuminance(), greaterThan(p.surface.computeLuminance()));
    });

    test('text and brand ink are legible on dark surfaces (WCAG AA)', () {
      const p = AppPalette.dark;
      for (final surface in [p.canvas, p.surface, p.surfaceRaised]) {
        expect(_contrast(p.ink, surface), greaterThanOrEqualTo(7));
        expect(_contrast(p.inkSecondary, surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(p.brandInk, surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(p.danger, surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(p.success, surface), greaterThanOrEqualTo(4.5));
      }
      expect(_contrast(p.inkTertiary, p.surface), greaterThanOrEqualTo(4.5));
      expect(_contrast(p.onBrand, p.brand), greaterThanOrEqualTo(4.5));
    });

    test('AppTheme.dark uses the palette for scaffold, inputs and primary', () {
      final theme = AppTheme.dark;
      final p = theme.extension<AppPalette>()!;
      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, p.canvas);
      expect(theme.colorScheme.primary, p.brandInk);
      expect(theme.colorScheme.surface, p.surface);
      expect(theme.inputDecorationTheme.fillColor, p.surfaceSunken);
      expect(theme.dialogTheme.backgroundColor, p.surfaceRaised);
    });

    test('a dark tenant brand is lifted so it stays legible', () {
      for (final brand in const [Color(0xFF000000), Color(0xFF0B3D2E), AppColors.primary]) {
        final lifted = AppPalette.liftForDark(brand);
        expect(_contrast(lifted, AppPalette.dark.surface), greaterThanOrEqualTo(4.5));
      }
      const light = Color(0xFFE4F5FF);
      expect(AppPalette.liftForDark(light), light, reason: 'already-light brands are kept');
    });
  });

  testWidgets('context.palette follows the active theme mode', (tester) async {
    AppPalette? seen;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        home: Builder(
          builder: (context) {
            seen = context.palette;
            return Scaffold(backgroundColor: context.palette.canvas);
          },
        ),
      ),
    );
    expect(seen, AppPalette.dark);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppPalette.dark.canvas,
    );
  });

  testWidgets('context.adaptive keeps the exact light value', (tester) async {
    late Color light;
    late Color dark;
    Widget probe(ThemeMode mode, void Function(Color) out) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: Builder(builder: (context) {
            out(context.adaptive(light: const Color(0xFF334155), dark: const Color(0xFFD9DAE0)));
            return const SizedBox();
          }),
        );
    await tester.pumpWidget(probe(ThemeMode.light, (c) => light = c));
    await tester.pumpWidget(probe(ThemeMode.dark, (c) => dark = c));
    await tester.pumpAndSettle();
    expect(light, const Color(0xFF334155));
    expect(dark, const Color(0xFFD9DAE0));
  });
}
