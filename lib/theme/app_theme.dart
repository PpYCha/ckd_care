import 'package:flutter/material.dart';

/// Saturated accent + status colors. These read well on both light and dark
/// grounds, so they stay constant across themes; the neutral/structural colors
/// come from the per-brightness [ColorScheme] instead.
class AppColors {
  static const water = Color(0xFF3E9BD6); // fluid blue
  static const good = Color(0xFF5DAE4E); // within limit / taken (grass green)
  static const warn = Color(0xFFE79A28); // caution / low stock (amber)
  static const over = Color(0xFFD9705F); // over limit / skipped (soft coral)

  // Per-module accents (the reference color-codes each area of the app).
  static const food = Color(0xFF5DAE4E); // green
  static const medicine = Color(0xFFE79A28); // amber
  static const dialysis = Color(0xFF7B5FD0); // purple

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
    required this.shadow,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
  });

  final Brightness brightness;
  final Color ground, surface, surfaceAlt, ink, inkSoft, line, shadow;
  final Color primary, onPrimary, primaryContainer, onPrimaryContainer;

  static const light = _Palette(
    brightness: Brightness.light,
    ground: Color(0xFFFBF6EA), // warm cream
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFBF1DE), // warm tint for fields/chips
    ink: Color(0xFF33413A), // soft charcoal-green
    inkSoft: Color(0xFF7C877F),
    line: Color(0xFFEDE3CE), // warm hairline
    shadow: Color(0x14332A16), // soft warm drop shadow
    primary: Color(0xFF5DAE4E), // friendly grass green
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDFF1D3),
    onPrimaryContainer: Color(0xFF2F6B26),
  );

  static const dark = _Palette(
    brightness: Brightness.dark,
    ground: Color(0xFF1B1712), // warm charcoal
    surface: Color(0xFF262019),
    surfaceAlt: Color(0xFF302921),
    ink: Color(0xFFEDE6DA),
    inkSoft: Color(0xFFACA595),
    line: Color(0xFF3A3229),
    shadow: Color(0x33000000),
    primary: Color(0xFF7FC96F), // brighter green for contrast on dark
    onPrimary: Color(0xFF10300B),
    primaryContainer: Color(0xFF2E4A28),
    onPrimaryContainer: Color(0xFFCDEAC2),
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
    shadow: p.shadow,
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
    titleLarge: n(22, FontWeight.w800, h: 1.15, ls: -0.3),
    titleMedium: n(17, FontWeight.w700, ls: -0.2),
    titleSmall: n(14, FontWeight.w800, ls: 0.3, c: p.inkSoft),
    bodyLarge: n(16, FontWeight.w500, h: 1.35),
    bodyMedium: n(15, FontWeight.w500, h: 1.35, c: p.inkSoft),
    labelLarge: n(15, FontWeight.w700, ls: 0.2),
    labelMedium: n(13, FontWeight.w600, ls: 0.3, c: p.inkSoft),
  );

  // Soft, friendly card: rounded, faint warm shadow, no hard border.
  const cardRadius = 22.0;

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
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: n(22, FontWeight.w800, ls: -0.3),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      elevation: 3,
      shadowColor: p.shadow,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: p.onPrimary,
        minimumSize: const Size(0, 54),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: n(16, FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.primary,
        minimumSize: const Size(0, 50),
        side: BorderSide(color: p.primary, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: n(15, FontWeight.w800),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.primary,
        textStyle: n(15, FontWeight.w800),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceAlt,
      labelStyle: n(15, FontWeight.w600, c: p.inkSoft),
      floatingLabelStyle: n(14, FontWeight.w800, c: p.primary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: p.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.over, width: 1.4),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.over, width: 1.6),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: n(20, FontWeight.w800),
      contentTextStyle: n(15, FontWeight.w500, h: 1.35, c: p.inkSoft),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink, // inverse of ground: dark bar in light, light in dark
      contentTextStyle: n(14, FontWeight.w700, c: p.ground),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.primaryContainer,
      elevation: 0,
      height: 68,
      labelTextStyle:
          WidgetStateProperty.all(n(12, FontWeight.w700, c: p.inkSoft)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? p.onPrimaryContainer
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
      labelStyle: n(13, FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
