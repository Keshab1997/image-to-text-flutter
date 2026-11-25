import 'package:flutter/material.dart';

/// Represents one of the 21 supported application languages in exact spec order.
class AppLanguageOption {
  const AppLanguageOption({
    required this.code,
    required this.nativeName,
  });

  final String code;
  final String nativeName;
}

/// Central copy, runtime toast contract, policy text, and 21-locale dictionary.
class AppStrings {
  const AppStrings._();

  // Brand & App Identity
  static const String appName = 'SnapText OCR';
  static const String legacySpecTitle = 'Image to Text';
  static const String packageName = 'com.keshabstudios.snaptext';
  static const String appVersion = '1.1.0';
  static const String developerName = 'Keshab Studios';
  static const String supportEmail = 'keshabstudios@gmail.com';
  static const String footerCopyright = '© 2026 Keshab Studios';

  // Privacy Policy URL
  static const String privacyPolicyUrl =
      'https://sites.google.com/view/privacypolicy-imagetotext/privacy-of-image-to-text';

  // AdMob Official Test IDs (per Spec §6.1)
  // TODO(release): Replace with Keshab Studios' production AdMob App ID and Banner Unit ID before Play Store release.
  static const String admobTestAppId =
      'ca-app-pub-3940256099942544~3347511713';
  static const String admobTestBannerUnitId =
      'ca-app-pub-3940256099942544/6300978111';

  // Home Screen Copy
  static const String mainSubtitle = 'Extract text from your images';
  static const String smartScannerBadge = 'Smart AI Text Scanner';
  static const String noImageSelected = 'No image selected';
  static const String chooseImageHint =
      'Take a photo or choose an image from your gallery';
  static const String heroDropPrompt =
      'Tap or drop a photo to scan text instantly';
  static const String camera = 'Camera';
  static const String cameraSub = 'Scan Now';
  static const String gallery = 'Gallery';
  static const String gallerySub = 'Import Image';
  static const String crop = 'Crop';
  static const String cropToolbarTitle = 'Crop Image';
  static const String extractText = 'Extract Text';
  static const String extractedText = 'Extracted Text';
  static const String extractedTextHint = 'Extracted text will appear here...';
  static const String copy = 'Copy';
  static const String share = 'Share';
  static const String clear = 'Clear';
  static const String settings = 'Settings';

  // Share & Clipboard Metadata (per Spec §2.4)
  static const String clipboardLabel = 'Extracted Text';
  static const String shareChooserTitle = 'Share extracted text';

  // Settings Screen Copy (per Spec §4)
  static const String settingsTitle = 'Settings';
  static const String settingsSubtitle = 'Customize Image to Text';
  static const String appearance = 'Appearance';
  static const String appearanceDescription = 'Choose how the app looks';
  static const String lightMode = 'Light Mode';
  static const String darkMode = 'Dark Mode';
  static const String systemDefault = 'System Default';
  static const String language = 'Language';
  static const String languageDescription =
      'Choose your preferred app language';
  static const String appLanguage = 'App Language';
  static const String policies = 'Policies';
  static const String policiesDescription =
      'Learn about privacy and responsible use';
  static const String privacyPolicy = 'Privacy Policy';
  static const String contentPolicy = 'Content Policy';
  static const String support = 'Support';
  static const String supportDescription =
      'Get help or learn more about the app';
  static const String contactUs = 'Contact Us';
  static const String aboutApp = 'About the App';
  static const String back = 'Back';
  static const String ok = 'OK';
  static const String cancel = 'Cancel';

  // Exact Toast Messages Contract (per Spec §2.4 — case & punctuation sensitive)
  static const String toastCameraPermissionRequired =
      'Camera permission is required';
  static const String toastPhotoCaptured = 'Photo captured successfully';
  static const String toastCameraCancelled = 'Camera capture cancelled';
  static String toastCameraOpenError(String message) =>
      'Could not open camera: $message';
  static const String toastCropNoImage =
      'Please choose or take an image first';
  static const String toastCropNoOutput = 'Could not get cropped image';
  static String toastCropFailed(String? message) =>
      'Crop failed: ${(message == null || message.trim().isEmpty) ? 'Unknown error' : message}';
  static const String toastCropSuccess = 'Image cropped successfully';
  static String toastCropDecodeError(String message) =>
      'Could not load cropped image: $message';
  static const String toastExtractNoImage = 'Please choose an image first';
  static const String toastNoTextDetected = 'No text was detected';
  static const String toastTextExtracted = 'Text extracted successfully';
  static String toastProcessImageError(String message) =>
      'Unable to process image: $message';
  static const String toastCopyEmpty = 'There is no text to copy';
  static const String toastTextCopied = 'Text copied';
  static const String toastShareEmpty = 'There is no text to share';
  static const String toastCleared = 'Cleared';
  static const String toastLightModeEnabled = 'Light mode enabled';
  static const String toastDarkModeEnabled = 'Dark mode enabled';
  static const String toastSystemModeEnabled = 'System mode enabled';
  static const String toastPrivacyPolicyError = 'Unable to open Privacy Policy';
  static const String toastNoEmailApp = 'No email application found';

  // Dialog & Support Texts (per Spec §4)
  static const String contentPolicyMessage =
      'SnapText OCR (Image to Text) is designed for legitimate text recognition and productivity purposes.\n'
      'You are responsible for the images and content you process using the app.\n'
      'Please do not use Image to Text to process, distribute, or share content that violates applicable laws or the rights of other people.\n'
      'Do not use the app for harassment, abuse, fraud, or any other harmful activity.\n'
      'Please respect copyright, privacy, intellectual property, and other applicable rights.\n'
      'By using Image to Text, you agree to use the application responsibly and lawfully.';

  static const String contactEmailSubject = 'Image to Text Support';
  static const String contactEmailBody =
      'Hello Keshab Studios,\n\n'
      'I need help with the SnapText OCR (Image to Text) app.\n\n'
      'My question or issue:\n\n\n'
      'Thank you.';

  static const String aboutDialogTitle = 'About Image to Text';
  static String aboutDialogMessage({String version = appVersion}) =>
      'SnapText OCR — Image to Text (v$version)\n\n'
      'Extract text quickly and easily from images using Optical Character Recognition (OCR).\n\n'
      'FEATURES\n\n'
      '• Take a photo with your camera\n'
      '• Choose an image from your gallery\n'
      '• Crop an image before text recognition\n'
      '• Extract text from images\n'
      '• Edit the extracted text\n'
      '• Copy the extracted text\n'
      '• Share the extracted text\n\n'
      'Developed by $developerName\n\n'
      'Contact:\n'
      '$supportEmail\n\n'
      '$footerCopyright';

  // Exact 21 Languages in Spec §4 Order
  static const List<AppLanguageOption> supportedLanguages = [
    AppLanguageOption(code: 'en', nativeName: 'English'),
    AppLanguageOption(code: 'fr', nativeName: 'Français'),
    AppLanguageOption(code: 'es', nativeName: 'Español'),
    AppLanguageOption(code: 'de', nativeName: 'Deutsch'),
    AppLanguageOption(code: 'pt', nativeName: 'Português'),
    AppLanguageOption(code: 'it', nativeName: 'Italiano'),
    AppLanguageOption(code: 'ar', nativeName: 'العربية'),
    AppLanguageOption(code: 'zh', nativeName: '中文'),
    AppLanguageOption(code: 'ja', nativeName: '日本語'),
    AppLanguageOption(code: 'ko', nativeName: '한국어'),
    AppLanguageOption(code: 'hi', nativeName: 'हिन्दी'),
    AppLanguageOption(code: 'bn', nativeName: 'বাংলা'),
    AppLanguageOption(code: 'ru', nativeName: 'Русский'),
    AppLanguageOption(code: 'id', nativeName: 'Bahasa Indonesia'),
    AppLanguageOption(code: 'ur', nativeName: 'اردو'),
    AppLanguageOption(code: 'vi', nativeName: 'Tiếng Việt'),
    AppLanguageOption(code: 'tr', nativeName: 'Türkçe'),
    AppLanguageOption(code: 'rw', nativeName: 'Kinyarwanda'),
    AppLanguageOption(code: 'sw', nativeName: 'Kiswahili'),
    AppLanguageOption(code: 'mr', nativeName: 'मराठी'),
    AppLanguageOption(code: 'te', nativeName: 'తెలుగు'),
  ];

  static List<Locale> get supportedLocales =>
      supportedLanguages.map((lang) => Locale(lang.code)).toList(growable: false);

  static AppLanguageOption languageForCode(String code) {
    for (final option in supportedLanguages) {
      if (option.code == code) {
        return option;
      }
    }
    return supportedLanguages.first;
  }
}
