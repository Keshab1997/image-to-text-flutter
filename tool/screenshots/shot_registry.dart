// This file belongs to THIS project (the installer never replaces it).
// It lists the screens the local screenshot harness renders, dressed in the
// app's real theme. Run: python3 tool/local_screenshots.py --shot home
// ignore: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:snaptext_ocr/constants/app_strings.dart';
import 'package:snaptext_ocr/constants/app_theme.dart';
import 'package:snaptext_ocr/screens/home_screen.dart';
import 'package:snaptext_ocr/widgets/app_tab_bar.dart';
import 'package:snaptext_ocr/screens/settings_screen.dart';

import 'dart:io';

import 'shot_framework.dart';

/// `<sdk>/bin/cache/dart-sdk/bin/dart` -> `<sdk>`, so the font path can be found
/// without hard-coding one machine's layout.
String _sdkRoot() {
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 5; i++) {
    dir = dir.parent;
  }
  return dir.path;
}

// Flutter's test renderer has no system font, so text would otherwise come out
// as black boxes. Roboto ships with the SDK next to the icon font; point the
// registry at it explicitly.
final ShotEnv env = ShotEnv(
  fontAssets: <String, String>{
    'Roboto': '${Platform.environment['FLUTTER_ROOT'] ?? _sdkRoot()}'
        '/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
  },
  app: (Shot shot, Widget home) => MaterialApp(
    title: AppStrings.appName,
    debugShowCheckedModeBanner: false,
    theme: shot.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
    home: home,
  ),
);

/// Home shell, parked on the Text tab. The framework photographs whatever the
/// widget ends up showing, so a one-line state poke is enough.
class _TextTabScreen extends StatefulWidget {
  const _TextTabScreen();

  @override
  State<_TextTabScreen> createState() => _TextTabScreenState();
}

class _TextTabScreenState extends State<_TextTabScreen> {
  final GlobalKey<HomeScreenState> _key = GlobalKey<HomeScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Switching tab is a state detail of the shell, so poke it the way a tap
      // would: through the public state object the app already exposes.
      _key.currentState?.switchTabForShot(AppTab.text);
    });
  }

  @override
  Widget build(BuildContext context) => HomeScreen(
        key: _key,
        onOpenSettings: () {},
      );
}

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
    name: 'text',
    // Open the Text tab before the camera runs so it gets photographed too.
    build: () => _TextTabScreen(),
    dark: false,
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
