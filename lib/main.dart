import 'package:flutter/material.dart';

import 'app.dart';
import 'services/preferences_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefsService = PreferencesService();
  final initialThemeMode = await prefsService.loadThemeMode();
  final initialLocale = await prefsService.loadLocale();

  runApp(
    SnapTextApp(
      preferencesService: prefsService,
      initialThemeMode: initialThemeMode,
      initialLocale: initialLocale,
    ),
  );
}
