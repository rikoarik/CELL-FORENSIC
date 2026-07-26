import 'package:cell_forensic/shared/design_tokens.dart';
import 'package:flutter/material.dart';

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: DesignTokens.blue,
      brightness: Brightness.light,
      primary: DesignTokens.navy,
      secondary: DesignTokens.blue,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: DesignTokens.surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: DesignTokens.surface,
        foregroundColor: DesignTokens.navy,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: DesignTokens.navy,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontWeight: FontWeight.w800,
          color: DesignTokens.navy,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w700,
          color: DesignTokens.navy,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w700,
          color: DesignTokens.navy,
        ),
        bodyLarge: TextStyle(height: 1.5, color: DesignTokens.inkMuted),
        bodyMedium: TextStyle(height: 1.45, color: DesignTokens.inkMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(DesignTokens.touchMin, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DesignTokens.radiusButton),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: DesignTokens.blue,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DesignTokens.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DesignTokens.blue, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusCard),
          side: const BorderSide(color: DesignTokens.border),
        ),
      ),
    );
  }
}
