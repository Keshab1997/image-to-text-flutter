import 'package:flutter/material.dart';

/// Design tokens and Material 3 Light/Dark themes for SnapText OCR.
/// Combines the exact spec radii/elevations/typography with the selected
/// 3D Robot-Scholar Mascot Royal-Violet & Electric-Indigo visual redesign.
class AppTheme {
  const AppTheme._();

  // Brand Palette (matching chosen mockup v2 + spec tokens)
  static const Color royalViolet = Color(0xFF5E35B1);
  static const Color electricIndigo = Color(0xFF651FFF);
  static const Color glowingPurple = Color(0xFF7C4DFF);
  static const Color deepCosmic = Color(0xFF140936);
  static const Color midnightCard = Color(0xFF1E1147);
  static const Color settingsFabBlue = Color(0xFF1976D2);
  static const Color settingsFabStroke = Color(0xFF64B5F6);

  // Action Accent Colors (from mockup v2)
  static const Color cameraOrangeStart = Color(0xFFFF9800);
  static const Color cameraOrangeEnd = Color(0xFFFF5722);
  static const Color galleryTealStart = Color(0xFF00BFA5);
  static const Color galleryTealEnd = Color(0xFF00ACC1);
  static const Color copyPurpleStart = Color(0xFF7C4DFF);
  static const Color copyPurpleEnd = Color(0xFF651FFF);
  static const Color shareTealStart = Color(0xFF1DE9B6);
  static const Color shareTealEnd = Color(0xFF00BFA5);
  static const Color clearOrangeStart = Color(0xFFFFAB40);
  static const Color clearOrangeEnd = Color(0xFFFF6D00);

  // Spec Radii & Dimensions (§5)
  static const double imageCardRadius = 20.0;
  static const double textCardRadius = 16.0;
  static const double buttonRadius = 14.0;
  static const double pillRadius = 24.0;
  static const double settingsFabSize = 56.0;
  static const double settingsFabRadius = 28.0;

  static const double imageCardHeight = 300.0;
  static const double textCardHeight = 260.0;
  static const double screenPadding = 20.0;
  static const double buttonGap = 8.0;

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: royalViolet,
      brightness: Brightness.light,
      primary: royalViolet,
      secondary: galleryTealEnd,
      surface: const Color(0xFFF6F4FC),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF3EFFB),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(imageCardRadius),
        ),
        color: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: deepCosmic,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: glowingPurple,
      brightness: Brightness.dark,
      primary: glowingPurple,
      secondary: shareTealStart,
      surface: const Color(0xFF18103A),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0E0826),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(imageCardRadius),
        ),
        color: const Color(0xFF1A113C),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2D1E66),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1C1240),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    );
  }
}
