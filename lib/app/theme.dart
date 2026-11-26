import 'package:material_ui/material_ui.dart';

/// Tactical obsidian HUD visual theme for FluxVision.
abstract final class FluxTheme {
  static const Color background = Color(0xFF080C12);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceGlass = Color(0xC7111827);
  static const Color border = Color(0xFF1E293B);
  static const Color cyanAccent = Color(0xFF00E5FF);
  static const Color anomalyAmber = Color(0xFFFF6B00);
  static const Color criticalRed = Color(0xFFFF3355);
  static const Color nominalGreen = Color(0xFF22E58B);
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textMuted = Color(0xFF94A3B8);

  static const TextStyle monoNumeric = TextStyle(
    fontFamily: 'monospace',
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    color: textPrimary,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.4,
  );

  static ThemeData dark() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        surface: surface,
        primary: cyanAccent,
        secondary: anomalyAmber,
        error: criticalRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: border),
        ),
      ),
    );
  }
}
