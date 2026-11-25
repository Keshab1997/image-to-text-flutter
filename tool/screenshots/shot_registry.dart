// This file belongs to THIS project (the installer never replaces it).
// It lists the screens the local screenshot harness renders, dressed in the
// app's real theme. Run: python3 tool/local_screenshots.py --shot home
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:snaptext_ocr/constants/app_strings.dart';
import 'package:snaptext_ocr/constants/app_theme.dart';
import 'package:snaptext_ocr/screens/home_screen.dart';
import 'package:snaptext_ocr/screens/settings_screen.dart';

import 'shot_framework.dart';

final ShotEnv env = ShotEnv(
  app: (Shot shot, Widget home) => MaterialApp(
    title: AppStrings.appName,
    debugShowCheckedModeBanner: false,
    theme: shot.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
    home: home,
  ),
);

final List<Shot> shots = <Shot>[
  Shot(
    name: 'home',
    build: () => HomeScreen(onOpenSettings: () {}),
    dark: false,
  ),
  Shot(
    name: 'home_dark',
    build: () => HomeScreen(onOpenSettings: () {}),
    dark: true,
  ),
  Shot(
    name: 'settings',
    build: () => SettingsScreen(
      currentThemeMode: ThemeMode.light,
      currentLocale: const Locale('en'),
      onThemeModeChanged: (_) {},
      onLocaleChanged: (_) {},
    ),
    dark: false,
  ),
  Shot(
    name: 'settings_dark',
    build: () => SettingsScreen(
      currentThemeMode: ThemeMode.dark,
      currentLocale: const Locale('en'),
      onThemeModeChanged: (_) {},
      onLocaleChanged: (_) {},
    ),
    dark: true,
  ),
];
