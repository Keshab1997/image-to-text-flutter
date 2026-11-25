import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_strings.dart';

/// Persists and restores user choices for [ThemeMode] and app [Locale].
class PreferencesService {
  PreferencesService([this._prefs]);

  SharedPreferences? _prefs;

  static const String themeModeKey = 'snaptext_theme_mode';
  static const String localeCodeKey = 'snaptext_locale_code';

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<ThemeMode> loadThemeMode() async {
    final prefs = await _instance();
    final raw = prefs.getString(themeModeKey);
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    final prefs = await _instance();
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(themeModeKey, value);
  }

  Future<Locale> loadLocale() async {
    final prefs = await _instance();
    final code = prefs.getString(localeCodeKey) ?? 'en';
    final valid = AppStrings.supportedLanguages.any((l) => l.code == code);
    return Locale(valid ? code : 'en');
  }

  Future<void> saveLocale(Locale locale) async {
    final prefs = await _instance();
    await prefs.setString(localeCodeKey, locale.languageCode);
  }
}
