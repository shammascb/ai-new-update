import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _seedColor = Color(0xFFF3A64A);
  static const _darkBackground = Color(0xFF101113);
  static const _darkSurface = Color(0xFF1C1E22);

  static ThemeData get dark => _buildTheme(
        brightness: Brightness.dark,
        scaffoldBackground: _darkBackground,
        surface: _darkSurface,
      );

  static ThemeData get light => _buildTheme(
        brightness: Brightness.light,
        scaffoldBackground: const Color(0xFFF4F7F5),
        surface: Colors.white,
      );

  static ThemeData _buildTheme({
    required Brightness brightness,
    required Color scaffoldBackground,
    required Color surface,
  }) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBackground,
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBackground,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.22),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: _seedColor.withValues(alpha: 0.14),
        elevation: 0,
      ),
      textTheme: Typography.material2021().black.apply(
            bodyColor: colorScheme.onSurface,
            displayColor: colorScheme.onSurface,
          ),
    );
  }
}
