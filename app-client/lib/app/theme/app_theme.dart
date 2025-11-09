import 'package:flutter/material.dart';

class AppTheme {
  static const Color _brand = Color(0xFF0A4D78);
  static const Color _accent = Color(0xFF23C9B6);
  static const Color _lightCanvas = Color(0xFFF0F6FF);
  static const Color _darkCanvas = Color(0xFF140F2B);
  static const double _cornerRadius = 22;

  static ThemeData get light => _base(Brightness.light);
  static ThemeData get dark => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: brightness,
      primary: isDark ? const Color(0xFF78B6FF) : _brand,
      secondary: isDark ? const Color(0xFF82F5D6) : _accent,
    );

    final Color glassSurface = isDark
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFF96B6FF).withOpacity(0.45);
    final Color scaffold = isDark ? _darkCanvas : _lightCanvas;
    final Color cardBorder = isDark
        ? Colors.white.withOpacity(0.08)
        : const Color(0xFF2757A5).withOpacity(0.35);

    final TextTheme textTheme = Typography.englishLike2018.apply(
      fontSizeFactor: 1.02,
      displayColor: isDark ? Colors.white : const Color(0xFF0D1E33),
      bodyColor: isDark ? Colors.white70 : const Color(0xFF1A2A3D),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      splashColor: scheme.primary.withOpacity(0.08),
      highlightColor: scheme.primary.withOpacity(0.05),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.primary,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      textTheme: textTheme,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isDark
            ? glassSurface
            : const Color(0xFF0D2C5C).withOpacity(0.08),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cornerRadius),
          side: isDark
              ? BorderSide(color: Colors.white.withOpacity(0.05))
              : BorderSide(color: cardBorder),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: glassSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_cornerRadius),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 70,
        backgroundColor: Colors.transparent,
        indicatorColor: scheme.primary.withOpacity(0.12),
        surfaceTintColor: Colors.transparent,
        labelTextStyle: MaterialStateProperty.all(
          textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.primary.withOpacity(isDark ? 0.18 : 0.12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: isDark ? Colors.white : scheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.white.withOpacity(0.92),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_cornerRadius),
          borderSide: BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_cornerRadius),
          borderSide: BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_cornerRadius),
          borderSide: BorderSide(color: scheme.primary.withOpacity(0.6)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surface.withOpacity(isDark ? 0.9 : 0.95),
        behavior: SnackBarBehavior.floating,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withOpacity(0.4),
        thickness: 1,
        space: 32,
      ),
      iconTheme: IconThemeData(color: scheme.primary),
    );
  }
}
