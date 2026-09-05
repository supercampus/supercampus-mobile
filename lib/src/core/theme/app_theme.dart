import 'package:flutter/material.dart';

abstract final class AppColors {
  /// Canonical SuperCampus brand palette. Keep every non-semantic product
  /// surface inside these three colours unless the product theme is changed.
  static const brandBlue = Color(0xFF1400FF);
  static const brandMagenta = Color(0xFFA600FF);
  static const brandLavender = Color(0xFF776CF5);

  static const primary = brandBlue;
  static const primaryDark = Color(0xFF0E00B8);
  static const amber = Color(0xFFF5A623);
  static const amberSoft = Color(0xFFFFF3D9);
  static const accent = gateLavender;
  static const success = Color(0xFF2E7D52);
  static const ink = Color(0xFF1C1C1E);
  static const muted = Color(0xFF6B7280);

  /// Near-white lavender blush used behind light-mode content.
  static const canvas = Color(0xFFFCF8FF);
  static const border = Color(0xFFE3E0FF);
  static const gateBlue = brandBlue;
  static const gateMagenta = brandMagenta;
  static const gateLavender = brandLavender;
  static const gateLime = Color(0xFFDFFF00);

  /// The violet the student home is built on. Same two stops as the gate
  /// colours — the home screen and the QR surfaces read as one family.
  static const violet = gateBlue;
  static const violetBright = gateMagenta;

  /// The single accent the module list is built on. A wall of per-module
  /// gradients reads as noise, so hierarchy is carried by lightness inside one
  /// violet: [moduleSoft] for a resting bar, [moduleAccent] for the open card.
  static const moduleAccent = gateLavender;
  static const moduleAccentDeep = gateBlue;
  static const moduleSoft = Color(0xFFE8E5FF);

  static const violetGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, violetBright],
  );
}

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Poppins',
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.canvas,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: AppColors.ink,
          fontSize: 30,
          fontWeight: FontWeight.w500,
          height: 1.15,
        ),
        titleLarge: TextStyle(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
        titleMedium: TextStyle(
          color: AppColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(
          color: AppColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w300,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          color: AppColors.muted,
          fontSize: 14,
          fontWeight: FontWeight.w300,
          height: 1.45,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: colorScheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        indicatorColor: AppColors.moduleSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.muted,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w500
                : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.muted,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );
  }

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'Poppins',
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      brightness: Brightness.dark,
    ),
    scaffoldBackgroundColor: Colors.black,
    canvasColor: Colors.black,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1B1E20),
      foregroundColor: Colors.white,
    ),
    cardColor: const Color(0xFF171717),
    cardTheme: const CardThemeData(
      color: Color(0xFF171717),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: Color(0xFF171717),
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xFF171717),
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.gateLavender, width: 1.5),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFF111111),
      surfaceTintColor: Colors.transparent,
      indicatorColor: Color(0xFF30258D),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(color: Colors.white70, fontSize: 12),
      ),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: Colors.white70)),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Color(0xFF242424),
      contentTextStyle: TextStyle(color: Colors.white),
    ),
  );
}
