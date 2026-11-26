import 'dart:ui';
import 'package:flutter/material.dart';

/// Industrial scientific instrument design system for FluxVision.
/// Follows a disciplined 60-30-10 neutral-first palette with optical carbon
/// surfaces, crisp hairline dividers, and calibrated phosphor accents.
abstract final class FluxTheme {
  // 60% Neutral Optical Canvas
  static const Color background = Color(0xFF090B0E);
  static const Color surface = Color(0xFF11151B);
  static const Color surfaceElevated = Color(0xFF181D26);
  static const Color surfaceGlass = Color(0xDE0C0F14);

  // 30% Structural Hairlines & Typography Neutrals
  static const Color border = Color(0xFF232A36);
  static const Color borderSubtle = Color(0xFF1A202B);
  static const Color textPrimary = Color(0xFFF3F5F7);
  static const Color textSecondary = Color(0xFFA0AAB8);
  static const Color textMuted = Color(0xFF6B7687);

  // 10% Calibrated Instrument Accents (restrained phosphor, zero neon soup)
  static const Color cyanAccent = Color(0xFF38BDF8);
  static const Color anomalyAmber = Color(0xFFE8922D);
  static const Color criticalRed = Color(0xFFEF5350);
  static const Color nominalGreen = Color(0xFF34D399);

  // Nested Radius Scale (r_inner = r_outer - padding)
  static const double radiusOuter = 16.0;
  static const double radiusControl = 10.0;
  static const double radiusSubtle = 6.0;

  static const TextStyle monoNumeric = TextStyle(
    fontFamily: 'monospace',
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    color: textPrimary,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const TextStyle microLabel = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: textMuted,
    letterSpacing: 0.3,
  );

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      surface: surface,
      primary: textPrimary,
      onPrimary: background,
      secondary: cyanAccent,
      onSecondary: background,
      error: criticalRed,
      outline: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: colorScheme,
      dividerColor: borderSubtle,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: textPrimary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: borderSubtle,
        labelColor: textPrimary,
        unselectedLabelColor: textMuted,
        labelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusOuter),
          side: const BorderSide(color: border, width: 0.8),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusOuter),
          side: const BorderSide(color: border, width: 0.8),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
          letterSpacing: -0.2,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          borderSide: const BorderSide(color: textPrimary, width: 1.2),
        ),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 13),
        hintStyle: const TextStyle(color: textMuted, fontSize: 13),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: textPrimary,
          foregroundColor: background,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: const BorderSide(color: border, width: 1.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusControl),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: textSecondary,
          minimumSize: const Size(44, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceElevated,
        contentTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusControl),
          side: const BorderSide(color: border),
        ),
      ),
    );
  }
}
