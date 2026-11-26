# SnapText OCR — Smart AI Image to Text Scanner

**SnapText OCR** (`com.keshabstudios.snaptext`) is a clean-room Flutter implementation of the offline multilingual Android OCR application specified in `docs/IMPLEMENTATION_SPEC.md` and `docs/REVERSE_ENGINEERING_DOCS.md`, redesigned with a custom 3D Robot-Scholar Mascot and modern Material 3 Royal-Violet & Electric-Indigo bento interface.

---

## Key Features

- **On-Device Multilingual OCR**: Runs the five Google ML Kit Text Recognition v2 scripts concurrently (`Latin`, `Chinese`, `Devanagari`, `Japanese`, `Korean`). Bengali OCR is not currently supported.
- **Smart 3D Mascot UI Redesign**:
  - Custom AI-generated 3D Robot-Scholar mascot hero banner (`assets/images/mascot_hero.png`) and circular badge avatar (`assets/images/mascot_avatar.png`).
  - Smart Bento tiles for **Camera** (*Scan Now*) and **Gallery** (*Import Image*).
  - **uCrop Image Cropping** (`image_cropper`) with freestyle crop, grid/frame guides, JPEG 95 quality, and 4096×4096 max output.
  - **Extracted Text Studio Card** with an editable, independently scrollable multiline text field, always-visible scrollbar, automatic end-of-text caret placement, live character counter, and **Copy**, **Share**, and **Clear** actions.
- **Full Settings & Customisation**:
  - **Appearance**: Light Mode, Dark Mode, and System Default with `SharedPreferences` persistence.
  - **App Language**: 21 supported locales (`en`, `fr`, `es`, `de`, `pt`, `it`, `ar`, `zh`, `ja`, `ko`, `hi`, `bn`, `ru`, `id`, `ur`, `vi`, `tr`, `rw`, `sw`, `mr`, `te`) in exact specification order.
  - **Policies & Support**: GitHub Pages-hosted Privacy Policy and Terms & Conditions, Content Policy dialog, Contact Us email launcher, and About dialog.
  - **Ad-free**: No advertising or analytics SDK is initialized or included in the app.

---

## Project Identity

| Field | Value |
|---|---|
| **App Name** | `SnapText OCR` |
| **Android `applicationId` / `namespace`** | `com.keshabstudios.snaptext` |
| **Version** | `1.1.0+4` |
| **Min / Target SDK** | `minSdk 24` / Flutter latest targetSdk |
| **Developer** | Keshab Studios (`Keshab1997`) |

---

## Repository Structure

```text
lib/
  main.dart                    # Entrypoint and persisted theme/locale bootstrap
  app.dart                     # SnapTextApp MaterialApp, 21-locale fallback delegates, navigation
  constants/
    app_strings.dart           # Exact UI copy, toast contract (§2.4), and 21-locale metadata
    app_theme.dart             # Material 3 Light/Dark themes, colours, radii, and tokens
  screens/
    home_screen.dart           # Screen 1 — Mascot hero card, Camera/Gallery/Crop/Extract/Copy/Share/Clear
    settings_screen.dart       # Screen 2 — Appearance, 21-Language dialog, Policies, Support, Banner ad
  services/
    ocr_service.dart           # 5-script concurrent ML Kit pipeline + calculateOcrScore
    image_service.dart         # Exclusive 3-state image model (none / uri / bitmap) + Camera/Gallery/uCrop
    preferences_service.dart   # ThemeMode + Locale persistence via SharedPreferences
  widgets/
    app_toast.dart             # Short (2s) and Long (3.5s) floating toast notifications
    banner_ad_widget.dart      # Lifecycle-aware AdMob Banner widget for Home & Settings
    primary_button.dart        # BentoActionTile & SmartPillButton components
assets/
  images/
    mascot_hero.png            # 3D Robot-Scholar Mascot scanner hero illustration
    mascot_avatar.png          # 3D Robot-Scholar Mascot avatar & launcher icon
l10n/
  app_en.arb ... app_te.arb    # 21 ARB localization files
test/
  ocr_score_test.dart          # Unit tests for calculateOcrScore, tie-breaking, and 5-script OCR service
  home_screen_test.dart        # Widget tests for Home & Settings screens, guards, toasts, and flows
docs/
  IMPLEMENTATION_SPEC.md       # Clean-room implementation specification
  REVERSE_ENGINEERING_DOCS.md  # Static reverse-engineering reference report
```

---

## Setup & Run Instructions

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run fast static preflight check
python3 tool/preflight.py

# 3. Run analyzer and unit/widget test suite
flutter analyze
flutter test

# 4. Run on a connected Android device or emulator
flutter run
```
