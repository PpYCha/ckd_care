import 'package:flutter/material.dart';

/// "Renal calm" palette + Nunito type. Muted status colors on purpose — a daily
/// care app should stay reassuring, not alarming.
class AppColors {
  static const ground = Color(0xFFEEF3F1); // page background (cool mint)
  static const surface = Color(0xFFFFFFFF); // cards
  static const surfaceAlt = Color(0xFFF4F8F6); // subtle insets
  static const primary = Color(0xFF0E5F59); // deep renal teal
  static const primaryContainer = Color(0xFFCDE7E2); // soft teal tint
  static const water = Color(0xFF3E8EA6); // fluid blue-teal
  static const ink = Color(0xFF16221F); // near-black slate
  static const inkSoft = Color(0xFF5C6D68); // secondary text
  static const line = Color(0xFFDCE6E2); // hairline

  static const good = Color(0xFF2E7D5B); // within limit / taken
  static const warn = Color(0xFFB8791C); // caution / low stock
  static const over = Color(0xFFB4544A); // over limit / skipped (muted brick)

  /// Fluid status by intake/limit ratio.
  static Color fluidStatus(double ratio) {
    if (ratio > 1.0) return over;
    if (ratio >= 0.8) return warn;
    return water;
  }
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryContainer,
    onPrimaryContainer: AppColors.primary,
    secondary: AppColors.water,
    onSecondary: Colors.white,
    error: AppColors.over,
    onError: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    surfaceContainerHighest: AppColors.surfaceAlt,
    onSurfaceVariant: AppColors.inkSoft,
    outline: AppColors.line,
  );

  TextStyle n(double size, FontWeight w, {double? h, double? ls, Color? c}) =>
      TextStyle(
        fontFamily: 'Nunito',
        fontSize: size,
        fontWeight: w,
        height: h,
        letterSpacing: ls,
        color: c ?? AppColors.ink,
      );

  final textTheme = TextTheme(
    displaySmall: n(34, FontWeight.w800, h: 1.05, ls: -0.5),
    headlineMedium: n(26, FontWeight.w800, h: 1.1, ls: -0.4),
    titleLarge: n(22, FontWeight.w700, h: 1.15, ls: -0.3),
    titleMedium: n(17, FontWeight.w700, ls: -0.2),
    titleSmall: n(14, FontWeight.w700, ls: 0.2, c: AppColors.inkSoft),
    bodyLarge: n(16, FontWeight.w500, h: 1.35),
    bodyMedium: n(15, FontWeight.w500, h: 1.35, c: AppColors.inkSoft),
    labelLarge: n(15, FontWeight.w700, ls: 0.2),
    labelMedium: n(13, FontWeight.w600, ls: 0.3, c: AppColors.inkSoft),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.ground,
    fontFamily: 'Nunito',
    textTheme: textTheme,
    dividerTheme: const DividerThemeData(
        color: AppColors.line, thickness: 1, space: 24),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.ground,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: n(22, FontWeight.w800, ls: -0.3),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: n(16, FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: AppColors.primary, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: n(15, FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: n(15, FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceAlt,
      labelStyle: n(15, FontWeight.w600, c: AppColors.inkSoft),
      floatingLabelStyle: n(14, FontWeight.w700, c: AppColors.primary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.over, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.over, width: 1.6),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: n(20, FontWeight.w800),
      contentTextStyle: n(15, FontWeight.w500, h: 1.35, c: AppColors.inkSoft),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: n(14, FontWeight.w600, c: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.primaryContainer,
      elevation: 0,
      height: 66,
      labelTextStyle: WidgetStateProperty.all(
          n(12, FontWeight.w700, c: AppColors.inkSoft)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.inkSoft)),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.inkSoft,
      textColor: AppColors.ink,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceAlt,
      side: const BorderSide(color: AppColors.line),
      labelStyle: n(13, FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
