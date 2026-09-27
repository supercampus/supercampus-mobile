import 'package:flutter/material.dart';

import 'app_palette.dart';

export 'app_palette.dart';

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
      extensions: const [AppPalette.light],
      scaffoldBackgroundColor: AppColors.canvas,
      appBarTheme: const AppBarTheme(
        // Page titles sit left-aligned beside the back button on every
        // platform (Material centres them on iOS by default).
        centerTitle: false,
        titleSpacing: NavigationToolbar.kMiddleSpacing,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: AppColors.ink),
        actionsIconTheme: IconThemeData(color: AppColors.ink),
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          color: AppColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
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

  /// Layered dark theme — never pure black. Mirrors [light] component by
  /// component so a screen styled through the theme needs no dark branch.
  static ThemeData get dark {
    const p = AppPalette.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      // Brand blue #1400FF is too dark to read as text on near-black, so the
      // scheme uses the lifted brand ink; filled buttons pair it with dark text.
      primary: p.brandInk,
      onPrimary: p.inkInverse,
      secondary: AppColors.gateLavender,
      error: p.danger,
      surface: p.surface,
      onSurface: p.ink,
      onSurfaceVariant: p.inkSecondary,
      outline: p.borderStrong,
      outlineVariant: p.border,
    ).copyWith(
      surfaceContainerLowest: p.surfaceSunken,
      surfaceContainerLow: p.surface,
      surfaceContainer: p.surface,
      surfaceContainerHigh: p.surfaceRaised,
      surfaceContainerHighest: p.surfaceMuted,
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Poppins',
      colorScheme: colorScheme,
      extensions: const [AppPalette.dark],
      scaffoldBackgroundColor: p.canvas,
      canvasColor: p.canvas,
      cardColor: p.surface,
      dividerColor: p.divider,
      dividerTheme: DividerThemeData(color: p.divider, thickness: 1),
      appBarTheme: AppBarTheme(
        // Page titles sit left-aligned beside the back button on every
        // platform (Material centres them on iOS by default).
        centerTitle: false,
        titleSpacing: NavigationToolbar.kMiddleSpacing,
        backgroundColor: p.surface,
        foregroundColor: p.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: p.ink),
        actionsIconTheme: IconThemeData(color: p.ink),
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          color: p.ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          color: p.ink,
          fontSize: 30,
          fontWeight: FontWeight.w500,
          height: 1.15,
        ),
        titleLarge: TextStyle(color: p.ink, fontSize: 20, fontWeight: FontWeight.w500),
        titleMedium: TextStyle(color: p.ink, fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(
          color: p.ink,
          fontSize: 16,
          fontWeight: FontWeight.w300,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          color: p.inkSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w300,
          height: 1.45,
        ),
      ),
      iconTheme: IconThemeData(color: p.ink),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceSunken,
        hintStyle: TextStyle(color: p.inkTertiary),
        labelStyle: TextStyle(color: p.inkSecondary),
        prefixIconColor: p.inkSecondary,
        suffixIconColor: p.inkSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.brandInk, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: p.danger, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          disabledBackgroundColor: p.surfaceMuted,
          disabledForegroundColor: p.inkDisabled,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          side: BorderSide(color: p.borderStrong),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: p.brandInk),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: p.brandSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected) ? p.brandInk : p.inkSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected) ? p.brandInk : p.inkSecondary,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          color: p.ink,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(fontFamily: 'Poppins', color: p.inkSecondary, fontSize: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surfaceRaised,
        modalBackgroundColor: p.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: p.borderStrong,
        modalBarrierColor: p.overlay,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        textStyle: TextStyle(fontFamily: 'Poppins', color: p.ink),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surfaceRaised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: p.inkSecondary,
        textColor: p.ink,
        // No selectedTileColor: a themed tile background makes every ListTile
        // on a decorated card lose its ink splash (Flutter asserts on it).
        selectedColor: p.brandInk,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.surfaceMuted,
        selectedColor: p.brandSoft,
        disabledColor: p.surfaceSunken,
        labelStyle: TextStyle(fontFamily: 'Poppins', color: p.ink),
        secondaryLabelStyle: TextStyle(fontFamily: 'Poppins', color: p.brandInk),
        side: BorderSide(color: p.border),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.inkInverse : p.inkSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.brandInk : p.surfaceMuted,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? Colors.transparent : p.borderStrong,
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.brandInk : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(p.inkInverse),
        side: BorderSide(color: p.borderStrong, width: 1.5),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? p.brandInk : p.borderStrong,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.brandInk,
        linearTrackColor: p.surfaceMuted,
        circularTrackColor: p.surfaceMuted,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: p.brandInk,
        unselectedLabelColor: p.inkSecondary,
        indicatorColor: p.brandInk,
        dividerColor: p.divider,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        headerForegroundColor: p.ink,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.surfaceRaised,
        dialBackgroundColor: p.surfaceMuted,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: p.border),
        ),
        textStyle: TextStyle(fontFamily: 'Poppins', color: p.ink, fontSize: 12),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.surfaceRaised,
        contentTextStyle: TextStyle(color: p.ink),
        actionTextColor: p.brandInk,
      ),
    );
  }
}
