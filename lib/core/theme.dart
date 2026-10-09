import 'package:flutter/material.dart';

/// Paleta del portal web (`src/app/globals.css` de htl-elevadores), para que
/// la app y la vista web del técnico se vean iguales.
class AppColors {
  const AppColors._({
    required this.background,
    required this.foreground,
    required this.card,
    required this.muted,
    required this.mutedForeground,
    required this.border,
    required this.destructive,
  });

  final Color background;
  final Color foreground;
  final Color card;
  final Color muted;
  final Color mutedForeground;
  final Color border;
  final Color destructive;

  static const primary = Color(0xFF0066CC);
  static const primaryHover = Color(0xFF0055AA);

  // Colores de estado y de tipo de servicio (los mismos tonos de Tailwind).
  static const emerald = Color(0xFF10B981);
  static const emeraldText = Color(0xFF059669);
  static const amber = Color(0xFFF59E0B);
  static const amberText = Color(0xFFD97706);
  static const red = Color(0xFFEF4444);
  static const redText = Color(0xFFDC2626);
  static const violetText = Color(0xFF7C3AED);

  static const light = AppColors._(
    background: Color(0xFFF8F9FA),
    foreground: Color(0xFF0F172A),
    card: Color(0xFFFFFFFF),
    muted: Color(0xFFF1F5F9),
    mutedForeground: Color(0xFF64748B),
    border: Color(0xFFE2E8F0),
    destructive: Color(0xFFEF4444),
  );

  static const dark = AppColors._(
    background: Color(0xFF09090B),
    foreground: Color(0xFFFAFAFA),
    card: Color(0xFF111114),
    muted: Color(0xFF1E1E22),
    mutedForeground: Color(0xFFA1A1AA),
    border: Color(0xFF27272A),
    destructive: Color(0xFFF87171),
  );

  /// Azul para texto: en oscuro se aclara para que se lea sobre fondo negro.
  static Color link(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? const Color(0xFF60A5FA) : primary;

  static AppColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final isDark = brightness == Brightness.dark;

  // Esquema explícito: `fromSeed` teñía fondos y tarjetas de azul oscuro y
  // la app se veía apagada.
  final scheme = ColorScheme(
    brightness: brightness,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.10),
    onPrimaryContainer: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
    secondary: AppColors.primary,
    onSecondary: Colors.white,
    tertiary: AppColors.emerald,
    onTertiary: Colors.white,
    error: c.destructive,
    onError: Colors.white,
    surface: c.card,
    onSurface: c.foreground,
    onSurfaceVariant: c.mutedForeground,
    surfaceContainerLowest: c.card,
    surfaceContainerLow: c.card,
    surfaceContainer: c.muted,
    surfaceContainerHigh: c.muted,
    surfaceContainerHighest: c.muted,
    outline: c.border,
    outlineVariant: c.border,
    surfaceTint: Colors.transparent,
    inverseSurface: c.foreground,
    onInverseSurface: c.background,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Montserrat',
    scaffoldBackgroundColor: c.background,
    splashFactory: InkRipple.splashFactory,
  );

  final text = base.textTheme.apply(bodyColor: c.foreground, displayColor: c.foreground);
  final rounded8 = RoundedRectangleBorder(borderRadius: BorderRadius.circular(10));

  return base.copyWith(
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 22),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 18),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600, fontSize: 14),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14),
      bodySmall: text.bodySmall?.copyWith(fontSize: 12, color: c.mutedForeground),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.card,
      foregroundColor: c.foreground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: c.foreground,
      ),
      shape: Border(bottom: BorderSide(color: c.border)),
    ),
    cardTheme: CardThemeData(
      color: c.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.border),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.mutedForeground,
      titleTextStyle: TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: c.foreground,
      ),
      subtitleTextStyle: TextStyle(fontFamily: 'Montserrat', fontSize: 12, color: c.mutedForeground),
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: c.muted,
        disabledForegroundColor: c.mutedForeground,
        minimumSize: const Size.fromHeight(50),
        shape: rounded8,
        textStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.foreground,
        backgroundColor: c.card,
        side: BorderSide(color: c.border),
        shape: rounded8,
        minimumSize: const Size(0, 44),
        textStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: isDark ? const Color(0xFF60A5FA) : AppColors.primary,
        shape: rounded8,
        textStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(color: c.mutedForeground),
      hintStyle: TextStyle(color: c.mutedForeground),
      prefixIconColor: c.mutedForeground,
      suffixIconColor: c.mutedForeground,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c.border)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titleTextStyle: TextStyle(
        fontFamily: 'Montserrat',
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: c.foreground,
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.card,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.foreground,
      contentTextStyle: TextStyle(fontFamily: 'Montserrat', color: c.background, fontWeight: FontWeight.w500),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: BorderSide(color: c.mutedForeground, width: 1.5),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: AppColors.primary,
        selectedForegroundColor: Colors.white,
        side: BorderSide(color: c.border),
        textStyle: const TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.w600),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: c.muted,
    ),
    badgeTheme: const BadgeThemeData(backgroundColor: AppColors.primary, textColor: Colors.white),
  );
}
