import 'package:flutter/material.dart';

/// Saturated accent + status colors. These read well on both light and dark
/// grounds, so they stay constant across themes; the neutral/structural colors
/// come from the per-brightness [ColorScheme] instead.
class AppColors {
  static const water = Color(0xFF3E8EA6); // fluid blue-teal
  static const good = Color(0xFF2E9E6E); // within limit / taken
  static const warn = Color(0xFFCB8A2A); // caution / low stock
  static const over = Color(0xFFC96A5F); // over limit / skipped (muted brick)

  /// Fluid status by intake/limit ratio.
  static Color fluidStatus(double ratio) {
    if (ratio > 1.0) return over;
    if (ratio >= 0.8) return warn;
    return water;
  }
}

/// The neutral + primary tokens that flip between light and dark.
class _Palette {
  const _Palette({
    required this.brightness,
    required this.ground,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkSoft,
    required this.line,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
  });

  final Brightness brightness;
  final Color ground, surface, surfaceAlt, ink, inkSoft, line;
  final Color primary, onPrimary, primaryContainer, onPrimaryContainer;

  static const light = _Palette(
    brightness: Brightness.light,
    ground: Color(0xFFEEF3F1),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF4F8F6),
    ink: Color(0xFF16221F),
    inkSoft: Color(0xFF5C6D68),
    line: Color(0xFFDCE6E2),
    primary: Color(0xFF0E5F59),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFCDE7E2),
    onPrimaryContainer: Color(0xFF0E5F59),
  );

  static const dark = _Palette(
    brightness: Brightness.dark,
    ground: Color(0xFF0F1614),
    surface: Color(0xFF18211E),
    surfaceAlt: Color(0xFF212C29),
    ink: Color(0xFFE8EEEB),
    inkSoft: Color(0xFF9FB0AB),
    line: Color(0xFF2C3A35),
    primary: Color(0xFF5BC9BC), // brighter teal for contrast on dark
    onPrimary: Color(0xFF06322E),
    primaryContainer: Color(0xFF234B45),
    onPrimaryContainer: Color(0xFFBDEBE4),
  );
}

ThemeData buildAppTheme(Brightness brightness) {
  final p = brightness == Brightness.dark ? _Palette.dark : _Palette.light;

  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.primary,
    onPrimary: p.onPrimary,
    primaryContainer: p.primaryContainer,
    onPrimaryContainer: p.onPrimaryContainer,
    secondary: AppColors.water,
    onSecondary: Colors.white,
    error: AppColors.over,
    onError: Colors.white,
    surface: p.surface,
    onSurface: p.ink,
    surfaceContainerHighest: p.surfaceAlt,
    onSurfaceVariant: p.inkSoft,
    outline: p.line,
    outlineVariant: p.line,
  );

  TextStyle n(double size, FontWeight w, {double? h, double? ls, Color? c}) =>
      TextStyle(
        fontFamily: 'Nunito',
        fontSize: size,
        fontWeight: w,
        height: h,
        letterSpacing: ls,
        color: c ?? p.ink,
      );

  final textTheme = TextTheme(
    displaySmall: n(34, FontWeight.w800, h: 1.05, ls: -0.5),
    headlineMedium: n(26, FontWeight.w800, h: 1.1, ls: -0.4),
    titleLarge: n(22, FontWeight.w700, h: 1.15, ls: -0.3),
    titleMedium: n(17, FontWeight.w700, ls: -0.2),
    titleSmall: n(14, FontWeight.w700, ls: 0.2, c: p.inkSoft),
    bodyLarge: n(16, FontWeight.w500, h: 1.35),
    bodyMedium: n(15, FontWeight.w500, h: 1.35, c: p.inkSoft),
    labelLarge: n(15, FontWeight.w700, ls: 0.2),
    labelMedium: n(13, FontWeight.w600, ls: 0.3, c: p.inkSoft),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.ground,
    fontFamily: 'Nunito',
    textTheme: textTheme,
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 24),
    appBarTheme: AppBarTheme(
      backgroundColor: p.ground,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: n(22, FontWeight.w800, ls: -0.3),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: n(16, FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.primary,
        minimumSize: const Size(0, 48),
        side: BorderSide(color: p.primary, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: n(15, FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primary,
        textStyle: n(15, FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceAlt,
      labelStyle: n(15, FontWeight.w600, c: p.inkSoft),
      floatingLabelStyle: n(14, FontWeight.w700, c: p.primary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: p.primary, width: 1.6),
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
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titleTextStyle: n(20, FontWeight.w800),
      contentTextStyle: n(15, FontWeight.w500, h: 1.35, c: p.inkSoft),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink, // inverse of ground: dark bar in light, light in dark
      contentTextStyle: n(14, FontWeight.w600, c: p.ground),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.primaryContainer,
      elevation: 0,
      height: 66,
      labelTextStyle:
          WidgetStateProperty.all(n(12, FontWeight.w700, c: p.inkSoft)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? p.primary
              : p.inkSoft)),
    ),
    listTileTheme: ListTileThemeData(iconColor: p.inkSoft, textColor: p.ink),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.primary,
      foregroundColor: p.onPrimary,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surfaceAlt,
      side: BorderSide(color: p.line),
      labelStyle: n(13, FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}
