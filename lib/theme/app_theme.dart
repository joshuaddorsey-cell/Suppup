import 'package:flutter/material.dart';

abstract final class SuppupColors {
  static const ink = Color(0xFF17342F);
  static const forest = Color(0xFF1F6B57);
  static const mint = Color(0xFFDDF3E8);
  static const coral = Color(0xFFF57E65);
  static const sunshine = Color(0xFFFFCC63);
  static const cream = Color(0xFFFFFAF1);
  static const surface = Color(0xFFFFFFFF);
  static const muted = Color(0xFF61756F);
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: SuppupColors.forest,
      brightness: Brightness.light,
      primary: SuppupColors.forest,
      secondary: SuppupColors.coral,
      surface: SuppupColors.surface,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: SuppupColors.cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: SuppupColors.ink,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: SuppupColors.surface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: SuppupColors.ink,
          fontSize: 30,
          height: 1.05,
          fontWeight: FontWeight.w900,
        ),
        titleLarge: TextStyle(
          color: SuppupColors.ink,
          fontSize: 21,
          fontWeight: FontWeight.w900,
        ),
        titleMedium: TextStyle(
          color: SuppupColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        bodyMedium: TextStyle(
          color: SuppupColors.muted,
          fontSize: 14,
          height: 1.35,
        ),
      ),
    );
  }
}
