import 'package:flutter/material.dart';

class AppTheme {
  static const _brandPrimary = Color(0xFF0C4EA3);
  static const _brandSecondary = Color(0xFF0AA6E6);
  static const _surface = Color(0xFFF3F5FA);

  static ThemeData get light {
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _brandPrimary,
        brightness: Brightness.light,
      ).copyWith(
        primary: _brandPrimary,
        secondary: _brandSecondary,
        surface: Colors.white,
      ),
      useMaterial3: true,
    );

    final textTheme = base.textTheme.apply(
      displayColor: const Color(0xFF1C2433),
      bodyColor: const Color(0xFF344054),
    );

    return base.copyWith(
      scaffoldBackgroundColor: _surface,
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        margin: EdgeInsets.zero,
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        dismissDirection: DismissDirection.up,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: _brandPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: _brandPrimary.withValues(alpha: .12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        height: 68,
        elevation: 10,
        surfaceTintColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _brandPrimary);
          }
          return const IconThemeData(color: Color(0xFF98A2B3));
        }),
      ),
    );
  }
}
