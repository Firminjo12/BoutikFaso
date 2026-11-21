import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF17633A);
  static const primaryDark = Color(0xFF104B2B);
  static const accent = Color(0xFFF2A51A);
  static const background = Color(0xFFF5F7F8);
  static const surface = Colors.white;
  static const surfaceTint = Color(0xFFE8F7EE);
  static const text = Color(0xFF1E2933);
  static const muted = Color(0xFF687581);
  static const border = Color(0xFFE2E8EC);
  static const success = Color(0xFF168447);
  static const warning = Color(0xFFE99A12);
  static const error = Color(0xFFD83939);
}

abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: AppColors.text,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: AppColors.text),
        bodyMedium: TextStyle(color: AppColors.muted),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.surfaceTint,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            color: isSelected ? AppColors.primary : AppColors.muted,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          );
        }),
      ),
    );
  }
}
