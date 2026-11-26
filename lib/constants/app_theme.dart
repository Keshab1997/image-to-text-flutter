import 'package:flutter/material.dart';

/// Design tokens and Material 3 Light/Dark themes for SnapText OCR.
///
/// One accent colour (orange) on a neutral grey/white base. Everything in the
/// app draws from these tokens — a feature widget should never need a literal
/// hex value. Keeping the palette this small is the point: the previous theme
/// carried 64 distinct colours (purples, indigos, teals, lavenders, blues),
/// which read as noise rather than hierarchy.
class AppTheme {
  const AppTheme._();

  // ── Accent: the only saturated colour in the app ──────────────────────────
  /// Primary action colour. Used for the main button, active states, links.
  static const Color accent = Color(0xFFF97316);

  /// Slightly deeper orange for text/icons on light surfaces where [accent]
  /// alone would not carry enough contrast.
  static const Color accentDark = Color(0xFFEA580C);

  /// Pale orange wash for selected chips, tints and highlight fills.
  static const Color accentSoft = Color(0xFFFFF1E6);

  /// Text/icon colour drawn on top of [accent].
  static const Color onAccent = Color(0xFFFFFFFF);

  // ── Semantic ─────────────────────────────────────────────────────────────
  static const Color danger = Color(0xFFDC2626);
  static const Color success = Color(0xFF16A34A);

  // ── Neutral — light ──────────────────────────────────────────────────────
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF7F7F8);
  static const Color lightBorder = Color(0xFFE4E4E7);
  static const Color lightText = Color(0xFF18181B);
  static const Color lightTextMuted = Color(0xFF71717A);

  // ── Neutral — dark ───────────────────────────────────────────────────────
  static const Color darkBg = Color(0xFF121214);
  static const Color darkSurface = Color(0xFF1B1B1F);
  static const Color darkBorder = Color(0xFF2C2C31);
  static const Color darkText = Color(0xFFF4F4F5);
  static const Color darkTextMuted = Color(0xFFA1A1AA);

  // Convenience: the tokens that flip with brightness.
  static Color bg(bool isDark) => isDark ? darkBg : lightBg;
  static Color surface(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color border(bool isDark) => isDark ? darkBorder : lightBorder;
  static Color text(bool isDark) => isDark ? darkText : lightText;
  static Color textMuted(bool isDark) =>
      isDark ? darkTextMuted : lightTextMuted;

  /// Text accent tuned per brightness so it stays legible in both themes.
  static Color accentText(bool isDark) => isDark ? accent : accentDark;

  // ── Radii & dimensions ───────────────────────────────────────────────────
  static const double imageCardRadius = 16.0;
  static const double textCardRadius = 16.0;
  static const double buttonRadius = 12.0;
  static const double pillRadius = 12.0;
  static const double screenPadding = 16.0;
  static const double buttonGap = 10.0;

  /// Empty/selected image preview height. Deliberately modest — a 300dp hero
  /// pushed the actual actions below the fold on a 390×844 phone.
  static const double imageCardHeight = 200.0;
  static const double textCardHeight = 200.0;

  // ── Rounded-rect helper so cards/buttons never drift apart ───────────────
  static RoundedRectangleBorder get cardShape => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(imageCardRadius),
      );

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      surface: bg(isDark),
      onSurface: text(isDark),
      error: danger,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg(isDark),
      splashFactory: InkSparkle.splashFactory,
    );

    TextStyle t(double size, FontWeight weight, {Color? color}) => TextStyle(
          fontSize: size,
          fontWeight: weight,
          color: color ?? text(isDark),
          height: 1.3,
        );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        // Screen title
        titleLarge: t(20, FontWeight.w700),
        // Section heading
        titleMedium: t(15, FontWeight.w600),
        // Body / field text
        bodyLarge: t(15, FontWeight.w400),
        bodyMedium: t(13.5, FontWeight.w400, color: textMuted(isDark)),
        bodySmall: t(12, FontWeight.w400, color: textMuted(isDark)),
        // Buttons
        labelLarge: t(15, FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface(isDark),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(imageCardRadius),
          side: BorderSide(color: border(isDark)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border(isDark),
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          minimumSize: const Size(0, 48),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text(isDark),
          minimumSize: const Size(0, 48),
          side: BorderSide(color: border(isDark)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentText(isDark),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface(isDark),
        side: BorderSide(color: border(isDark)),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: text(isDark),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF2A2A30) : const Color(0xFF2A2A30),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bg(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(imageCardRadius),
        ),
      ),
    );
  }
}
