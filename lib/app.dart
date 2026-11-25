import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'constants/app_strings.dart';
import 'constants/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/image_service.dart';
import 'services/ocr_service.dart';
import 'services/preferences_service.dart';

/// Fallback MaterialLocalizations delegate so every one of the 21 spec locales
/// (including `rw` Kinyarwanda) resolves cleanly without framework warnings.
class _FallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _FallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    if (GlobalMaterialLocalizations.delegate.isSupported(locale)) {
      return GlobalMaterialLocalizations.delegate.load(locale);
    }
    return DefaultMaterialLocalizations.load(const Locale('en'));
  }

  @override
  bool shouldReload(_FallbackMaterialLocalizationsDelegate old) => false;
}

class _FallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _FallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    if (GlobalCupertinoLocalizations.delegate.isSupported(locale)) {
      return GlobalCupertinoLocalizations.delegate.load(locale);
    }
    return DefaultCupertinoLocalizations.load(const Locale('en'));
  }

  @override
  bool shouldReload(_FallbackCupertinoLocalizationsDelegate old) => false;
}

/// Root MaterialApp widget for SnapText OCR.
class SnapTextApp extends StatefulWidget {
  const SnapTextApp({
    super.key,
    this.preferencesService,
    this.imageService,
    this.ocrService,
    this.shareHandler,
    this.clipboardHandler,
    this.uriLauncher,
    this.initialThemeMode = ThemeMode.system,
    this.initialLocale = const Locale('en'),
  });

  final PreferencesService? preferencesService;
  final ImageService? imageService;
  final OcrService? ocrService;
  final ShareTextCallback? shareHandler;
  final ClipboardCopyCallback? clipboardHandler;
  final ExternalUriLauncher? uriLauncher;
  final ThemeMode initialThemeMode;
  final Locale initialLocale;

  @override
  State<SnapTextApp> createState() => SnapTextAppState();
}

class SnapTextAppState extends State<SnapTextApp> {
  late final PreferencesService _prefsService =
      widget.preferencesService ?? PreferencesService();
  late ThemeMode _themeMode = widget.initialThemeMode;
  late Locale _locale = widget.initialLocale;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  Future<void> updateThemeMode(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    await _prefsService.saveThemeMode(mode);
  }

  Future<void> updateLocale(Locale locale) async {
    setState(() {
      _locale = locale;
    });
    await _prefsService.saveLocale(locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      locale: _locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        _FallbackMaterialLocalizationsDelegate(),
        _FallbackCupertinoLocalizationsDelegate(),
        GlobalWidgetsLocalizations.delegate,
      ],
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale != null) {
          for (final supported in supportedLocales) {
            if (supported.languageCode == locale.languageCode) {
              return supported;
            }
          }
        }
        return const Locale('en');
      },
      home: Builder(
        builder: (navContext) {
          return HomeScreen(
            imageService: widget.imageService,
            ocrService: widget.ocrService,
            shareHandler: widget.shareHandler,
            clipboardHandler: widget.clipboardHandler,
            onOpenSettings: () {
              Navigator.of(navContext).push(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsScreen(
                    currentThemeMode: _themeMode,
                    currentLocale: _locale,
                    onThemeModeChanged: updateThemeMode,
                    onLocaleChanged: updateLocale,
                    uriLauncher: widget.uriLauncher,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
