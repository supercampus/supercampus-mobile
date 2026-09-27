import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Timetable colours that have no exact [AppPalette] role.
///
/// Every helper returns the original light value unchanged in light mode, so
/// the light timetable stays pixel-identical; dark mode gets a layered value.
extension TimetableTones on BuildContext {
  /// Material grey shade ([Colors.grey] `[shade]`) mapped onto the dark
  /// neutral ramp: fills, lines, hints, secondary and primary text.
  Color grey(int shade) => adaptive(
    light: Colors.grey[shade]!,
    dark: switch (shade) {
      <= 100 => const Color(0xFF1C1D23),
      200 => const Color(0xFF2B2C34),
      300 => const Color(0xFF3A3B44),
      <= 500 => const Color(0xFF878995),
      <= 700 => const Color(0xFFA3A5B0),
      _ => const Color(0xFFE0E1E6),
    },
  );

  /// The timetable page background (#F4F6FA in light).
  Color get timetableCanvas =>
      adaptive(light: const Color(0xFFF4F6FA), dark: palette.canvas);
}

/// Adapts a hue-coded colour (subject category, status, alert tint).
extension TimetableHue on Color {
  /// This hue as text or an icon on a surface: unchanged in light, lifted to a
  /// light shade of the same hue in dark so it stays legible.
  Color inkOn(BuildContext context) {
    if (!context.isDarkTheme) return this;
    final hsl = HSLColor.fromColor(this);
    return hsl.lightness >= 0.72 ? this : hsl.withLightness(0.76).toColor();
  }

  /// This pastel as a background (or, with a higher [alpha], an outline):
  /// unchanged in light, a translucent tint of the same hue in dark.
  Color tintOn(BuildContext context, {double alpha = 0.18}) {
    if (!context.isDarkTheme) return this;
    final hsl = HSLColor.fromColor(this);
    return HSLColor.fromAHSL(alpha, hsl.hue, hsl.saturation, 0.5).toColor();
  }
}

/// The indigo exam family shared by the exam cards, the exam detail sheet and
/// the exam alert section. Light values are the original literals.
extension TimetableExamTones on BuildContext {
  /// Exam text, icons and accents (#3730A3).
  Color get examInk =>
      adaptive(light: const Color(0xFF4B1FB8), dark: const Color(0xFFB57BFF));

  /// Secondary exam icon accent (#4F46E5).
  Color get examAccent =>
      adaptive(light: const Color(0xFF7B42F6), dark: const Color(0xFFB57BFF));

  /// Exam headings (#1E1B4B).
  Color get examHeading =>
      adaptive(light: const Color(0xFF2A1260), dark: palette.ink);

  /// Exam card and chip outlines (#C7D2FE).
  Color get examLine =>
      adaptive(light: const Color(0xFFE2D5FD), dark: const Color(0x597B42F6));

  /// Exam category chips and dividers (#E0E7FF).
  Color get examSoft =>
      adaptive(light: const Color(0xFFEFE8FE), dark: const Color(0x2E7B42F6));

  /// Exam card fill (#F8F9FE).
  Color get examCard =>
      adaptive(light: const Color(0xFFF8F9FE), dark: const Color(0x147B42F6));

  /// "Alert set" green text and icons (#15803D).
  Color get examAlertGreen =>
      adaptive(light: const Color(0xFF15803D), dark: const Color(0xFF6EE7B7));
}
