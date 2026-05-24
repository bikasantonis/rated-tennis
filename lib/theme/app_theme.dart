import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:rated/theme/app_colors.dart';

abstract final class AppTheme {
  // ── Border radius constants ───────────────────────────────────────────────
  static const double radiusGlobal = 12;
  static const double radiusPill = 999;
  static const double radiusButton = 20;

  static final _lightColorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: AppColors.onPrimary,
    primaryContainer: AppColors.primaryContainer,
    secondary: AppColors.secondary,
    onSecondary: AppColors.onSecondary,
    secondaryContainer: AppColors.secondaryContainer,
    tertiary: AppColors.tertiary,
    tertiaryContainer: AppColors.tertiaryContainer,
    surface: AppColors.lightBg,
    onSurface: AppColors.onSurface,
    surfaceContainerHighest: AppColors.surfaceVariant,
    outline: AppColors.outline,
    error: AppColors.error,
    onError: AppColors.onError,
  );

  static final _darkColorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    tertiary: AppColors.tertiaryDark,
    surface: AppColors.darkBg,
    surfaceContainerHighest: AppColors.darkSurface,
  );

  static final _textTheme = TextTheme(
    displayLarge: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w700),
    displayMedium: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w700),
    displaySmall: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w700),
    headlineLarge: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w700),
    headlineMedium: GoogleFonts.barlowCondensed(fontWeight: FontWeight.w600),
    headlineSmall: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
    titleLarge: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w600),
    titleMedium: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w500),
    titleSmall: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w500),
    bodyLarge: GoogleFonts.ibmPlexSans(),
    bodyMedium: GoogleFonts.ibmPlexSans(),
    bodySmall: GoogleFonts.ibmPlexSans(),
    labelLarge: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w500),
    labelMedium: GoogleFonts.ibmPlexSans(fontWeight: FontWeight.w500),
    labelSmall: GoogleFonts.ibmPlexSans(),
  );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: _lightColorScheme,
        textTheme: _textTheme,
        cardTheme: CardThemeData(
          color: AppColors.lightCard,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusGlobal),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusGlobal),
            borderSide: const BorderSide(color: AppColors.outline),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusButton),
            ),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: _darkColorScheme,
        textTheme: _textTheme,
        cardTheme: CardThemeData(
          color: AppColors.darkCard,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusGlobal),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusGlobal),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusButton),
            ),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      );
}
