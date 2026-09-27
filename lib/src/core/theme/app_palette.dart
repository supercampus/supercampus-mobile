import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Semantic colours for every SuperCampus surface, in light and dark.
///
/// Screens read colours from here (`context.palette.ink`) instead of static
/// constants such as [AppColors.ink] or `Colors.white`, so one widget renders
/// correctly in both themes. Light values reproduce the light theme exactly;
/// dark values form a layered palette:
///
///   canvas  <  surface (cards, sheets)  <  surfaceRaised (dialogs, menus)
///
/// Brand colour has two roles. [brand] is a fill that carries [onBrand] text
/// (buttons, selected chips, hero panels) and stays saturated in both themes.
/// [brandInk] is brand-coloured text, icons and outlines on a surface; in dark
/// mode it is lifted so it stays legible on near-black.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.canvas,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSunken,
    required this.surfaceMuted,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.ink,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.inkDisabled,
    required this.inkInverse,
    required this.brand,
    required this.brandInk,
    required this.brandSoft,
    required this.onBrand,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
    required this.info,
    required this.infoSoft,
    required this.overlay,
    required this.shadow,
  });

  /// Page background behind cards.
  final Color canvas;

  /// Cards, sheets, app bars, list rows — the default content surface.
  final Color surface;

  /// Dialogs, menus, popovers, bottom sheets — floats above [surface].
  final Color surfaceRaised;

  /// Inset areas inside a card: input wells, table headers, grouped rows.
  final Color surfaceSunken;

  /// Quiet chips, disabled fills, placeholder blocks.
  final Color surfaceMuted;

  /// Card and field outlines.
  final Color border;

  /// Emphasised outlines: selected, focused-adjacent, strong separators.
  final Color borderStrong;

  /// Hairline separators between rows.
  final Color divider;

  /// Primary text and icons.
  final Color ink;

  /// Secondary text, captions, inactive icons (was [AppColors.muted]).
  final Color inkSecondary;

  /// Tertiary text: timestamps, hints, placeholders.
  final Color inkTertiary;

  /// Disabled text and icons.
  final Color inkDisabled;

  /// Text drawn on an [ink]-coloured fill (for example a snackbar).
  final Color inkInverse;

  /// Brand fill (buttons, selected states, hero panels).
  final Color brand;

  /// Brand-coloured text, icons and outlines on [surface] / [canvas].
  final Color brandInk;

  /// Tinted brand background: selected rows, soft chips, module bars.
  final Color brandSoft;

  /// Text and icons on a [brand] fill.
  final Color onBrand;

  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;
  final Color info;
  final Color infoSoft;

  /// Modal barrier / scrim.
  final Color overlay;

  /// Drop-shadow colour. Dark mode needs a deeper shadow to read at all.
  final Color shadow;

  static const light = AppPalette(
    canvas: AppColors.canvas,
    surface: Colors.white,
    surfaceRaised: Colors.white,
    surfaceSunken: Color(0xFFF6F5FB),
    surfaceMuted: Color(0xFFF3F4F6),
    border: AppColors.border,
    borderStrong: Color(0xFFC7C7CC),
    divider: Color(0xFFEEEEEE),
    ink: AppColors.ink,
    inkSecondary: AppColors.muted,
    inkTertiary: Color(0xFF94A3B8),
    inkDisabled: Color(0xFFBDBDBD),
    inkInverse: Colors.white,
    brand: AppColors.primary,
    brandInk: AppColors.primary,
    brandSoft: AppColors.moduleSoft,
    onBrand: Colors.white,
    success: AppColors.success,
    // Acid green tint behind the legible green ink.
    successSoft: Color(0xFFEFF9D1),
    // Orange ink on a neon-gold tint.
    warning: AppColors.orangeInk,
    warningSoft: Color(0xFFFFF6D1),
    // Red-leaning magenta: reads as an error, distinct from the pink accent.
    danger: Color(0xFFE5003D),
    dangerSoft: Color(0xFFFFE3EA),
    // Deep cyan ink on an electric-cyan tint.
    info: AppColors.infoInk,
    infoSoft: Color(0xFFDBFEF9),
    overlay: Color(0x8A000000),
    shadow: Color(0x14000000),
  );

  static const dark = AppPalette(
    canvas: Color(0xFF0E0F13),
    surface: Color(0xFF17181D),
    surfaceRaised: Color(0xFF202128),
    surfaceSunken: Color(0xFF121317),
    surfaceMuted: Color(0xFF1C1D23),
    border: Color(0xFF2B2C34),
    borderStrong: Color(0xFF4D4E58),
    divider: Color(0xFF24252C),
    ink: Color(0xFFF2F2F5),
    inkSecondary: Color(0xFFA3A5B0),
    inkTertiary: Color(0xFF878995),
    inkDisabled: Color(0xFF5C5E68),
    inkInverse: Color(0xFF0E0F13),
    brand: AppColors.brandPurple,
    brandInk: Color(0xFFB57BFF),
    brandSoft: Color(0xFF2A1D4A),
    onBrand: Colors.white,
    success: AppColors.acidGreen,
    successSoft: Color(0x1FA8E000),
    warning: AppColors.neonGold,
    warningSoft: Color(0x1FFFD000),
    danger: Color(0xFFFF5C7A),
    dangerSoft: Color(0x1FFF5C7A),
    info: AppColors.electricCyan,
    infoSoft: Color(0x1F00F5D4),
    overlay: Color(0xB3000000),
    shadow: Color(0x66000000),
  );

  /// Lifts a colour so it reads as text or an icon on the dark surfaces.
  /// Used for the tenant's brand in the dark Material colour scheme; the
  /// palette's own [brand] / [brandInk] stay the SuperCampus brand, exactly as
  /// the screens used [AppColors.primary] before dark mode existed.
  static Color liftForDark(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.lightness < 0.72 ? hsl.withLightness(0.78).toColor() : color;
  }

  @override
  AppPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? surfaceRaised,
    Color? surfaceSunken,
    Color? surfaceMuted,
    Color? border,
    Color? borderStrong,
    Color? divider,
    Color? ink,
    Color? inkSecondary,
    Color? inkTertiary,
    Color? inkDisabled,
    Color? inkInverse,
    Color? brand,
    Color? brandInk,
    Color? brandSoft,
    Color? onBrand,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
    Color? info,
    Color? infoSoft,
    Color? overlay,
    Color? shadow,
  }) {
    return AppPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      surfaceRaised: surfaceRaised ?? this.surfaceRaised,
      surfaceSunken: surfaceSunken ?? this.surfaceSunken,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      divider: divider ?? this.divider,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkTertiary: inkTertiary ?? this.inkTertiary,
      inkDisabled: inkDisabled ?? this.inkDisabled,
      inkInverse: inkInverse ?? this.inkInverse,
      brand: brand ?? this.brand,
      brandInk: brandInk ?? this.brandInk,
      brandSoft: brandSoft ?? this.brandSoft,
      onBrand: onBrand ?? this.onBrand,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      info: info ?? this.info,
      infoSoft: infoSoft ?? this.infoSoft,
      overlay: overlay ?? this.overlay,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      canvas: l(canvas, other.canvas),
      surface: l(surface, other.surface),
      surfaceRaised: l(surfaceRaised, other.surfaceRaised),
      surfaceSunken: l(surfaceSunken, other.surfaceSunken),
      surfaceMuted: l(surfaceMuted, other.surfaceMuted),
      border: l(border, other.border),
      borderStrong: l(borderStrong, other.borderStrong),
      divider: l(divider, other.divider),
      ink: l(ink, other.ink),
      inkSecondary: l(inkSecondary, other.inkSecondary),
      inkTertiary: l(inkTertiary, other.inkTertiary),
      inkDisabled: l(inkDisabled, other.inkDisabled),
      inkInverse: l(inkInverse, other.inkInverse),
      brand: l(brand, other.brand),
      brandInk: l(brandInk, other.brandInk),
      brandSoft: l(brandSoft, other.brandSoft),
      onBrand: l(onBrand, other.onBrand),
      success: l(success, other.success),
      successSoft: l(successSoft, other.successSoft),
      warning: l(warning, other.warning),
      warningSoft: l(warningSoft, other.warningSoft),
      danger: l(danger, other.danger),
      dangerSoft: l(dangerSoft, other.dangerSoft),
      info: l(info, other.info),
      infoSoft: l(infoSoft, other.infoSoft),
      overlay: l(overlay, other.overlay),
      shadow: l(shadow, other.shadow),
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// The active [AppPalette]; falls back to the light palette in contexts
  /// built without the app theme (for example isolated widget tests).
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;

  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;

  /// For a one-off colour with no palette role: keeps the exact [light] value
  /// and uses [dark] in dark mode. Prefer a palette colour when one fits.
  Color adaptive({required Color light, required Color dark}) =>
      isDarkTheme ? dark : light;
}
