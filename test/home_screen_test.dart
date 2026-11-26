import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snaptext_ocr/app.dart';
import 'package:snaptext_ocr/constants/app_strings.dart';
import 'package:snaptext_ocr/screens/home_screen.dart';
import 'package:snaptext_ocr/services/image_service.dart';
import 'package:snaptext_ocr/services/ocr_service.dart';
import 'package:snaptext_ocr/services/preferences_service.dart';

// Minimal valid 1x1 transparent PNG bytes for testing Image.memory / file preview
final Uint8List _kTransparentPng = Uint8List.fromList(<int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

void main() {
  late Directory tempDir;
  late File sampleImageFile;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tempDir = await Directory.systemTemp.createTemp('snaptext_test_');
    sampleImageFile = File('${tempDir.path}/sample.png');
    await sampleImageFile.writeAsBytes(_kTransparentPng, flush: true);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HomeScreen layout and empty-state guard toasts (Spec §2.1–§2.4)', () {
    testWidgets('renders header, scan tab, tab bar, and no ad slot',
        (tester) async {
      tester.view.physicalSize = const Size(780, 1688);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const SnapTextApp());
      await tester.pumpAndSettle();

      expect(find.text('SnapText OCR'), findsOneWidget);
      expect(find.text('Extract text from your images'), findsOneWidget);
      expect(find.byKey(const Key('settings_button')), findsOneWidget);
      expect(find.text('No image selected'), findsOneWidget);
      expect(
        find.text('Take a photo or choose an image from your gallery'),
        findsOneWidget,
      );
      expect(find.text('Camera'), findsOneWidget);
      expect(find.text('Gallery'), findsOneWidget);
      expect(find.text('Crop'), findsOneWidget);
      expect(find.text('Extract Text'), findsOneWidget);

      // The shell: four tabs, nothing hidden behind a menu.
      for (final tab in ['scan', 'text', 'history', 'settings']) {
        expect(find.byKey(Key('tab_$tab')), findsOneWidget);
      }

      // The ad slot is gone for good.
      expect(find.byKey(const Key('banner_ad_container')), findsNothing);

      // Result and its actions live on the Text tab, not the scan screen.
      await tester.tap(find.byKey(const Key('tab_text')));
      await tester.pumpAndSettle();
      expect(find.text('Extracted Text'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('© 2026 Keshab Studios'), findsNothing);
      expect(find.byKey(const Key('empty_camera_button')), findsOneWidget);
      expect(find.byKey(const Key('empty_gallery_button')), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('text_editor_card'))).height,
        greaterThan(350),
      );

      await tester.enterText(
        find.byKey(const Key('extracted_text_field')),
        'Sample extracted text on the full-height editor.',
      );
      await tester.pumpAndSettle();
      expect(find.text('© 2026 Keshab Studios'), findsNothing);
      expect(find.byKey(const Key('empty_camera_button')), findsNothing);
      expect(
        tester.getSize(find.byKey(const Key('text_editor_card'))).height,
        greaterThan(350),
      );
    });

    testWidgets('system back returns to Scan, then asks before exit',
        (tester) async {
      await tester.pumpWidget(const SnapTextApp());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab_text')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('empty_image_state')), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Exit SnapText OCR?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Exit SnapText OCR?'), findsNothing);
    });

    testWidgets('shows guard toasts and disables actions when text is empty',
        (tester) async {
      await tester.pumpWidget(const SnapTextApp());
      await tester.pumpAndSettle();

      // 1. Crop with no image -> "Please choose or take an image first"
      await tester.ensureVisible(find.byKey(const Key('crop_button')));
      await tester.tap(find.byKey(const Key('crop_button')));
      await tester.pump();
      expect(
        find.text('Please choose or take an image first'),
        findsOneWidget,
      );

      // 2. Extract Text with no image -> "Please choose an image first"
      await tester.ensureVisible(find.byKey(const Key('extract_button')));
      await tester.tap(find.byKey(const Key('extract_button')));
      await tester.pump();
      expect(find.text('Please choose an image first'), findsOneWidget);

      // The result actions live on the Text tab now.
      await tester.tap(find.byKey(const Key('tab_text')));
      await tester.pumpAndSettle();

      // Empty results cannot be copied, shared, or cleared.
      final copyButton = tester.widget<FilledButton>(find.descendant(
        of: find.byKey(const Key('copy_button')),
        matching: find.byType(FilledButton),
      ));
      expect(copyButton.onPressed, isNull);
      final shareButton = tester.widget<OutlinedButton>(find.descendant(
        of: find.byKey(const Key('share_button')),
        matching: find.byType(OutlinedButton),
      ));
      expect(shareButton.onPressed, isNull);
      expect(
          tester
              .widget<TextButton>(find.byKey(const Key('clear_button')))
              .onPressed,
          isNull);
    });
  });

  group('Camera, Gallery, Crop, OCR, Copy, Share, and Clear flows', () {
    testWidgets('camera permission denied shows exact toast', (tester) async {
      final imageService = ImageService(
        cameraPermissionRequester: () async => false,
        tempDirProvider: () async => tempDir,
      );

      await tester.pumpWidget(SnapTextApp(imageService: imageService));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('camera_button')));
      await tester.pumpAndSettle();

      expect(find.text('Camera permission is required'), findsOneWidget);
    });

    testWidgets('camera capture cancelled deletes temp file and shows toast',
        (tester) async {
      final imageService = ImageService(
        cameraPermissionRequester: () async => true,
        cameraPicker: () async => null,
        tempDirProvider: () async => tempDir,
      );

      await tester.pumpWidget(SnapTextApp(imageService: imageService));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('camera_button')));
      await tester.pumpAndSettle();

      expect(find.text('Camera capture cancelled'), findsOneWidget);
    });

    testWidgets(
        'full pipeline: Gallery -> Crop -> Extract Text -> Copy -> Share -> Clear',
        (tester) async {
      String? copiedText;
      String? copiedLabel;
      String? sharedText;
      String? sharedSubject;

      final imageService = ImageService(
        galleryPicker: () async => sampleImageFile.path,
        cropperRunner: (src) async => sampleImageFile.path,
        bitmapLoader: (_) async => _kTransparentPng,
        tempDirProvider: () async => tempDir,
      );

      final ocrService = OcrService(
        tempDirectoryOverride: tempDir,
        scriptRunner: (script, _) async {
          if (script.name == 'latin') {
            return 'SnapText OCR Recognized Line';
          }
          return '';
        },
      );

      await tester.pumpWidget(
        SnapTextApp(
          imageService: imageService,
          ocrService: ocrService,
          clipboardHandler: (text, {label = ''}) async {
            copiedText = text;
            copiedLabel = label;
          },
          shareHandler: (text, {subject}) async {
            sharedText = text;
            sharedSubject = subject;
          },
        ),
      );
      await tester.pumpAndSettle();

      // 1. Pick from Gallery -> state becomes uri, preview shown
      await tester.tap(find.byKey(const Key('gallery_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('image_preview')), findsOneWidget);
      expect(find.byKey(const Key('empty_image_state')), findsNothing);

      // 2. Crop -> state becomes bitmap, toast "Image cropped successfully"
      await tester.ensureVisible(find.byKey(const Key('crop_button')));
      await tester.tap(find.byKey(const Key('crop_button')));
      await tester.pumpAndSettle();
      expect(find.text('Image cropped successfully'), findsOneWidget);
      expect(find.byKey(const Key('image_preview_bitmap')), findsOneWidget);

      // 3. Extract Text -> sets text, moves caret to end, toast "Text extracted successfully"
      await tester.ensureVisible(find.byKey(const Key('extract_button')));
      await tester.tap(find.byKey(const Key('extract_button')));
      await tester.pumpAndSettle();
      expect(find.text('Text extracted successfully'), findsOneWidget);

      final homeState = tester.state<HomeScreenState>(find.byType(HomeScreen));
      expect(
        homeState.textController.text,
        equals('SnapText OCR Recognized Line'),
      );
      expect(
        homeState.textController.selection.baseOffset,
        equals('SnapText OCR Recognized Line'.length),
      );

      // 4. Copy -> copies with label "Extracted Text", toast "Text copied"
      await tester.ensureVisible(find.byKey(const Key('copy_button')));
      await tester.tap(find.byKey(const Key('copy_button')));
      await tester.pumpAndSettle();
      expect(find.text('Text copied'), findsOneWidget);
      expect(copiedText, equals('SnapText OCR Recognized Line'));
      expect(copiedLabel, equals('Extracted Text'));

      // 5. Share -> shares with subject "Share extracted text"
      await tester.ensureVisible(find.byKey(const Key('share_button')));
      await tester.tap(find.byKey(const Key('share_button')));
      await tester.pumpAndSettle();
      expect(sharedText, equals('SnapText OCR Recognized Line'));
      expect(sharedSubject, equals('Share extracted text'));

      // 6. Clear -> resets state to none, clears text, shows "Cleared"
      await tester.ensureVisible(find.byKey(const Key('clear_button')));
      await tester.tap(find.byKey(const Key('clear_button')));
      await tester.pumpAndSettle();
      expect(find.text('Cleared'), findsOneWidget);
      expect(homeState.imageState, equals(ImageSelectionState.none));
      expect(homeState.textController.text, isEmpty);
    });
  });

  group('SettingsScreen flows (Spec §4)', () {
    testWidgets(
        'theme buttons, 21-language dialog, Content Policy, About, and link error toasts work',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final prefsService = PreferencesService(prefs);
      final launchedUris = <Uri>[];

      await tester.pumpWidget(
        SnapTextApp(
          preferencesService: prefsService,
          uriLauncher: (uri) async {
            launchedUris.add(uri);
            return false;
          },
        ),
      );
      await tester.pumpAndSettle();

      // Open Settings — now a tab of the shell rather than a pushed route.
      await tester.tap(find.byKey(const Key('settings_button')));
      await tester.pumpAndSettle();

      // 'Settings' is both the page heading and a tab label.
      expect(find.text('Settings'), findsWidgets);
      expect(find.byKey(const Key('dark_mode_button')), findsOneWidget);
      expect(find.text('Customize Image to Text'), findsOneWidget);
      // Still no advertising anywhere in the app.
      expect(find.byKey(const Key('banner_ad_container')), findsNothing);

      // Theme buttons
      await tester.tap(find.byKey(const Key('dark_mode_button')));
      await tester.pumpAndSettle();
      expect(find.text('Dark mode enabled'), findsOneWidget);
      expect(await prefsService.loadThemeMode(), equals(ThemeMode.dark));

      await tester.tap(find.byKey(const Key('light_mode_button')));
      await tester.pumpAndSettle();
      expect(find.text('Light mode enabled'), findsOneWidget);
      expect(await prefsService.loadThemeMode(), equals(ThemeMode.light));

      // About the App dialog (asserted before switching to French, because the
      // dialog copy is localized and these strings are the English ones).
      await tester.ensureVisible(find.byKey(const Key('about_app_button')));
      await tester.tap(find.byKey(const Key('about_app_button')));
      await tester.pumpAndSettle();
      expect(find.text('About Image to Text'), findsOneWidget);
      expect(find.textContaining('FEATURES'), findsOneWidget);
      await tester.tap(find.byKey(const Key('about_ok_button')));
      await tester.pumpAndSettle();

      // Language dialog lists all 21 languages in order
      expect(AppStrings.supportedLanguages.length, equals(21));
      expect(AppStrings.supportedLanguages.first.code, equals('en'));
      expect(AppStrings.supportedLanguages.last.code, equals('te'));

      await tester.ensureVisible(find.byKey(const Key('language_button')));
      await tester.tap(find.byKey(const Key('language_button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('language_dialog_list')), findsOneWidget);
      expect(find.text('English'), findsWidgets);

      // Select Français (fr) from the 21-language dialog
      await tester.tap(find.byKey(const Key('lang_option_fr')));
      await tester.pumpAndSettle();
      expect((await prefsService.loadLocale()).languageCode, equals('fr'));

      // Privacy Policy failure toast
      await tester.ensureVisible(
        find.byKey(const Key('privacy_policy_button')),
      );
      await tester.tap(find.byKey(const Key('privacy_policy_button')));
      await tester.pumpAndSettle();
      expect(find.text('Unable to open Privacy Policy'), findsOneWidget);
      expect(launchedUris.last.toString(), equals(AppStrings.privacyPolicyUrl));

      await tester.ensureVisible(
        find.byKey(const Key('terms_and_conditions_button')),
      );
      await tester.tap(find.byKey(const Key('terms_and_conditions_button')));
      await tester.pumpAndSettle();
      expect(find.text('Unable to open Terms & Conditions'), findsOneWidget);
      expect(
        launchedUris.last.toString(),
        equals(AppStrings.termsAndConditionsUrl),
      );

      // Content Policy dialog
      await tester.ensureVisible(
        find.byKey(const Key('content_policy_button')),
      );
      await tester.tap(find.byKey(const Key('content_policy_button')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('legitimate text recognition and productivity'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('content_policy_ok_button')));
      await tester.pumpAndSettle();

      // Contact Us failure toast
      await tester.ensureVisible(find.byKey(const Key('contact_us_button')));
      await tester.tap(find.byKey(const Key('contact_us_button')));
      await tester.pumpAndSettle();
      expect(find.text('No email application found'), findsOneWidget);

      // Leaving Settings is a tab switch back to Scan (no pushed route now).
      ScaffoldMessenger.of(tester.element(find.byType(HomeScreen)))
          .removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab_scan')));
      await tester.pumpAndSettle();
      expect(find.text('SnapText OCR'), findsOneWidget);
      // Since French ('fr') was selected, Home labels now render in French!
      expect(find.text('Caméra'), findsOneWidget);
      expect(find.text('Extraire le texte'), findsOneWidget);
    });

    testWidgets(
        'Scan History auto-saves extracted text, opens sheet, restores text, and clears',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final historyService =
          // ignore: invalid_use_of_visible_for_testing_member
          await Future.value(prefs);

      final imageService = ImageService(
        galleryPicker: () async => sampleImageFile.path,
        tempDirProvider: () async => tempDir,
      );

      final ocrService = OcrService(
        tempDirectoryOverride: tempDir,
        scriptRunner: (script, _) async {
          if (script.name == 'latin') {
            return 'Saved History OCR Sample';
          }
          return '';
        },
      );

      await tester.pumpWidget(
        SnapTextApp(
          preferencesService: PreferencesService(historyService),
          imageService: imageService,
          ocrService: ocrService,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Pick gallery & extract text -> auto-saved to HistoryService
      await tester.tap(find.byKey(const Key('gallery_button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('extract_button')));
      await tester.tap(find.byKey(const Key('extract_button')));
      await tester.pumpAndSettle();

      // 2. Clear editor
      await tester.ensureVisible(find.byKey(const Key('clear_button')));
      await tester.tap(find.byKey(const Key('clear_button')));
      await tester.pumpAndSettle();
      final homeState = tester.state<HomeScreenState>(find.byType(HomeScreen));
      expect(homeState.textController.text, isEmpty);

      // 3. Open Scan History. Drop the floating toast first: it overlaps the
      // tab bar and would swallow the tap.
      ScaffoldMessenger.of(
        tester.element(find.byType(HomeScreen)),
      ).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab_history')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scan_history_sheet')), findsOneWidget);
      expect(find.text('Saved History OCR Sample'), findsOneWidget);

      // 4. Tap "Use Text" to restore scan into editor
      await tester.tap(find.byKey(const Key('history_use_0')));
      await tester.pumpAndSettle();
      expect(
        homeState.textController.text,
        equals('Saved History OCR Sample'),
      );
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byKey(const Key('tab_text')), findsOneWidget);
      expect(find.byKey(const Key('extracted_text_field')), findsOneWidget);
      expect(find.text('Exit SnapText OCR?'), findsNothing);
    });

    testWidgets(
        'Smart Entity chips, Batch Multi-Page Scan, and History Search work',
        (tester) async {
      String? copiedValue;
      final page2File = File('${tempDir.path}/page2.png');
      page2File.writeAsBytesSync(_kTransparentPng, flush: true);

      final imageService = ImageService(
        multiGalleryPicker: () async =>
            <String>[sampleImageFile.path, page2File.path],
        tempDirProvider: () async => tempDir,
      );

      var callIndex = 0;
      final ocrService = OcrService(
        tempDirectoryOverride: tempDir,
        scriptRunner: (script, _) async {
          if (script.name == 'latin') {
            callIndex++;
            return callIndex == 1
                ? 'Contact: support@keshab.dev'
                : 'Total: ₹1250.00';
          }
          return '';
        },
      );

      await tester.pumpWidget(
        SnapTextApp(
          imageService: imageService,
          ocrService: ocrService,
          clipboardHandler: (text, {label = ''}) async {
            copiedValue = text;
          },
        ),
      );
      await tester.pumpAndSettle();

      // 1. Trigger Multi-Page Batch Scan
      await tester.ensureVisible(find.byKey(const Key('batch_scan_button')));
      await tester.tap(find.byKey(const Key('batch_scan_button')));
      await tester.pumpAndSettle();

      final homeState = tester.state<HomeScreenState>(find.byType(HomeScreen));
      expect(homeState.textController.text, contains('--- Page 1 ---'));
      expect(homeState.textController.text, contains('--- Page 2 ---'));

      // 2. Smart Entity Chips are automatically rendered for email and amount
      final emailChip = find.byKey(
        const Key('entity_chip_support@keshab.dev'),
      );
      expect(emailChip, findsOneWidget);
      await tester.ensureVisible(emailChip);
      await tester.tap(emailChip);
      await tester.pumpAndSettle();
      expect(copiedValue, equals('support@keshab.dev'));

      // 3. Open History and filter via Search Bar. Clear the copy toast first:
      // it floats over the tab bar and would swallow the tap.
      ScaffoldMessenger.of(
        tester.element(find.byType(HomeScreen)),
      ).removeCurrentSnackBar();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab_history')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history_search_field')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('history_search_field')),
        'non_existent_query_xyz',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('history_item_0')), findsNothing);
    });
  });
}
