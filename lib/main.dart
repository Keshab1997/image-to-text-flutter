import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'app.dart';
import 'services/preferences_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise Google Mobile Ads SDK at startup (per IMPLEMENTATION_SPEC.md §6.1)
  if (!kIsWeb &&
      !Platform.environment.containsKey('FLUTTER_TEST') &&
      (Platform.isAndroid || Platform.isIOS)) {
    try {
      await MobileAds.instance.initialize();
    } catch (_) {
      // Non-fatal if Play services are unavailable on device/emulator.
    }
  }

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
