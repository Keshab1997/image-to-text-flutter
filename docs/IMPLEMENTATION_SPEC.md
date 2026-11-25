# Implementation Specification — "Image to Text" in Flutter

This is the build spec for a clean-room Flutter reimplementation of the Android app
analysed in `REVERSE_ENGINEERING_DOCS.md`. Everything the user can see or do is
specified here. Where this spec and the reference report differ, **this spec wins**.

---

## 0. Product summary

An offline OCR utility. The user picks or takes a photo, optionally crops it, taps
**Extract Text**, and the app recognises text in five scripts with Google ML Kit,
picks the best result, and shows it in an editable box that can be copied or shared.
A Settings screen controls theme and app language and holds policy/about links.

Target behaviour: **parity with the original v1.1**, unless a documented improvement
in §9 is deliberately chosen.

---

## 1. Project setup

```bash
flutter create image_to_text
cd image_to_text
```

- Flutter stable, Dart 3+.
- Choose a **new unique applicationId** (e.g. `com.<your-domain>.imagetotext`). Do not
  use `com.tricksconnect.imagetotext`.
- Android `minSdkVersion 24`, target/current compile SDK (flagship target used 36).
- App label: **Image to Text**.
- Request `CAMERA` permission at runtime; `INTERNET` is needed only if ads are kept.

### Dependencies (use current stable versions compatible with your Flutter SDK)

| Purpose | Package |
|---|---|
| Camera / gallery | `image_picker` |
| Crop | `image_cropper` (wraps uCrop on Android — closest parity) |
| OCR | `google_mlkit_text_recognition` |
| Share | `share_plus` |
| Clipboard | `Clipboard` from `flutter/services` (no extra package) |
| Temp files | `path_provider` |
| Persist theme/locale choice | `shared_preferences` |
| Localisation | `flutter_localizations` (SDK) + `intl` |
| Ads (optional) | `google_mobile_ads` |
| Permissions (optional, image_picker handles most) | `permission_handler` |

### Suggested structure

```
lib/
  main.dart                    # app, ThemeMode, locale delegates, routes
  app.dart                     # MaterialApp config
  screens/
    home_screen.dart           # Screen 1
    settings_screen.dart       # Screen 2
  services/
    ocr_service.dart           # 5 recognisers + best-result scoring
    image_service.dart         # pick/capture/crop/temp-file helpers
    preferences_service.dart   # theme + locale persistence
  widgets/
    primary_button.dart        # shared Material 3 button style if useful
  constants/
    app_strings.dart           # UI copy (or use l10n ARB instead)
    app_theme.dart             # colours, radii, typography
l10n/
  app_en.arb ... app_bn.arb    # 21 locales from §5.3
test/
  ocr_score_test.dart          # unit test for the scoring function
  home_screen_test.dart        # widget tests for guards/toasts
```

---

## 2. Screen 1 — Home

### 2.1 Layout (top → bottom)

1. **Header** — padding 20dp horizontal, 12dp vertical:
   - Title `Image to Text`, 28sp bold
   - Subtitle `Extract text from your images`, 14sp secondary
   - Right: circular icon button 56×56dp, blue `#1976d2`, stroke `#64b5f6`, white
     settings icon 30dp, tooltip/accessibility label `Settings` → opens Settings.
2. **Scrollable body** (padding 20dp):
   - **Image card**: 300dp tall, radius 20dp, elevation 2dp.
     - Empty state (visible initially): gallery icon 64dp at 55% opacity, bold
       `No image selected` 18sp, then `Take a photo or choose an image from your
       gallery` 14sp secondary, centred.
     - `ImagePreview` (hidden until an image exists): `fitCenter`, 300dp area.
   - **Row 1**: `Camera` and `Gallery` buttons, equal width, 6dp gap.
   - **Row 2**: `Crop` and `Extract Text` buttons, equal width, 6dp gap.
   - Centred progress spinner (hidden by default).
   - Heading `Extracted Text`, 20sp bold.
   - **Text card**: 260dp tall, radius 16dp; inside it an **editable, scrollable**
     text field, hint `Extracted text will appear here...`, 16sp, top-left gravity,
     multiline, caret at end after extraction.
   - **Row 3**: `Copy`, `Share` buttons, equal width.
   - Full-width outlined `Clear` button.
3. **Footer** — `© 2026 Eugene Luckyson`, 15sp bold, centred.
4. Optional banner ad at the very bottom.

Buttons: 15sp, sentence case, radius 14dp. Camera/Gallery carry system camera/gallery
icons. Apply system-bar insets as padding on the root view.

### 2.2 State model

Use one of three states, never two at once:

| State | Meaning |
|---|---|
| `none` | no image; empty state shown, preview hidden |
| `uri` | picked/captured image referenced by a file URI |
| `bitmap` | cropped image held in memory (URI cleared) |

Setting an image clears the extracted text. Clearing resets all state and text.

### 2.3 Flows and exact messages

**Camera**
- If permission denied → request it; if still denied, toast **"Camera permission is required"** (long).
- Otherwise capture to `temp/camera_<epochMillis>.jpg`, show preview (state `uri`),
  clear text, toast **"Photo captured successfully"**.
- If capture is cancelled → delete the temp file if created, toast **"Camera capture cancelled"**.
- On error → toast `"Could not open camera: <message>"` (long).

**Gallery**
- Pick from `image/*`. On success set state `uri`, show preview, hide empty state,
  clear text. Cancellation = silent.

**Crop**
- If state `none` → toast **"Please choose or take an image first"**, return.
- If state `bitmap`, first save it to `camera_<epochMillis>.jpg` (JPEG 95) and crop that.
- Cropper options: freestyle enabled, grid + frame shown, toolbar title **"Crop Image"**,
  JPEG quality 95, bottom controls visible, max result size 4096×4096.
- Success: decode result, set state `bitmap`, show preview, clear text, toast
  **"Image cropped successfully"**.
- Failure: toast `"Crop failed: <message>"` or **"Could not get cropped image"**.
- Decode error: toast `"Could not load cropped image: <message>"` (long).

**Extract Text**
- If state `none` → toast **"Please choose an image first"**, return.
- Show spinner. Build `InputImage` from the bitmap (rotation 0) or from the URI.
- Run the OCR pipeline in §3. Hide spinner when finished.
- No recognised text → clear the field, toast **"No text was detected"**.
- Otherwise set best text, move caret to end, toast **"Text extracted successfully"**.
- On exception → hide spinner, toast `"Unable to process image: <message>"` (long).

**Copy**
- Blank → toast **"There is no text to copy"**.
- Else copy with label `Extracted Text`, toast **"Text copied"**.

**Share**
- Blank → toast **"There is no text to share"**.
- Else share as plain text via the OS chooser titled **"Share extracted text"**.

**Clear**
- Reset image state, empty preview, show empty state, clear text, hide spinner,
  toast **"Cleared"**.

---

## 3. OCR pipeline (core algorithm — implement exactly)

Run **five** recognisers on the same image, concurrently where possible:

```dart
const scripts = [
  TextRecognitionScript.latin,
  TextRecognitionScript.chinese,
  TextRecognitionScript.devanagari,
  TextRecognitionScript.japanese,
  TextRecognitionScript.korean,
];
```

For each recogniser:
- `processImage(image)`, then `text = recognisedText.text.trim()`.
- If `text.isNotEmpty`, append it to the results list.
- Failures are ignored.
- When all five have finished, close every recogniser and choose the best result.

Collect results in a thread-safe way (the original mutates an `ArrayList` from
callbacks — do not copy that race; use `Future.wait` or synchronized state).

### Best-result scoring (exact)

```dart
int calculateOcrScore(String text) {
  var score = 0;
  for (final c in text.runes) {
    if ((c >= 19968 && c < 40960) ||   // CJK
        (c >= 12352 && c < 12448) ||   // Hiragana / Katakana
        (c >= 12448 && c < 12544) ||   // Katakana
        (c >= 44032 && c < 55216) ||   // Hangul
        (c >= 2304  && c < 2432)) {    // Devanagari
      score += 5;
    } else if (_isLetterOrDigit(c)) {
      score += 2;
    } else if (_isWhitespace(c)) {
      score += 1;
    }
  }
  return score + text.length;
}
```

- Pick the result with the highest score; ties go to the **first** result.
- Use Unicode-aware letter/digit and whitespace checks (Dart `Runes` /
  `unicode` semantics equivalent to Java `Character.isLetterOrDigit` and
  `Char.isWhitespace`).
- Note: Bengali (U+0980–U+09FF) is *not* in the +5 ranges — it falls under
  letter/digit (+2). Preserve that quirk for parity.

Add a unit test that asserts the scores of representative strings (Latin, CJK,
Devanagari, whitespace-only) and the tie-breaking rule.

---

## 4. Screen 2 — Settings

Header: **Settings** (26sp bold) + **Customize Image to Text** (14sp), divider,
scrollable body, footer copyright, optional banner ad. Apply **bottom-only** safe-area
inset padding.

| Group heading / subtitle | Rows (full-width buttons, 6dp gaps) |
|---|---|
| **Appearance** / *Choose how the app looks* | `Light Mode`, `Dark Mode`, `System Default` |
| **Language** / *Choose your preferred app language* | `App Language` |
| **Policies** / *Learn about privacy and responsible use* | `Privacy Policy`, `Content Policy` |
| **Support** / *Get help or learn more about the app* | `Contact Us`, `About the App` |
| — | `Back` (closes Settings) |

**Theme actions** (persist the choice):
- Light → toast **"Light mode enabled"**
- Dark → toast **"Dark mode enabled"**
- System → toast **"System mode enabled"**

**App Language** — single-choice dialog with these 21 entries in this order:

```
en English, fr Français, es Español, de Deutsch, pt Português, it Italiano,
ar العربية, zh 中文, ja 日本語, ko 한국어, hi हिन्दी, bn বাংলা, ru Русский,
id Bahasa Indonesia, ur اردو, vi Tiếng Việt, tr Türkçe, rw Kinyarwanda,
sw Kiswahili, mr मराठी, te తెలుగు
```

Preselect the currently applied locale (default `en`); selecting one changes the
app locale immediately and persists it. Cancel button: **"Cancel"**.

**Privacy Policy** → open
`https://sites.google.com/view/privacypolicy-imagetotext/privacy-of-image-to-text`
in a browser; on failure toast **"Unable to open Privacy Policy"** (long).

**Content Policy** → dialog title **"Content Policy"**, message below, button **"OK"**:

> Image to Text is designed for legitimate text recognition and productivity purposes.
> You are responsible for the images and content you process using the app.
> Please do not use Image to Text to process, distribute, or share content that violates
> applicable laws or the rights of other people.
> Do not use the app for harassment, abuse, fraud, or any other harmful activity.
> Please respect copyright, privacy, intellectual property, and other applicable rights.
> By using Image to Text, you agree to use the application responsibly and lawfully.

**Contact Us** → `mailto:eluckyon@gmail.com`, subject **"Image to Text Support"**, body:

```
Hello Tricks Connect,

I need help with the Image to Text app.

My question or issue:


Thank you.
```

On failure toast **"No email application found"**.

**About the App** → dialog title **"About Image to Text"**, button **"OK"**, message:

```
Image to Text

Extract text quickly and easily from images using Optical Character Recognition (OCR).

FEATURES

• Take a photo with your camera
• Choose an image from your gallery
• Crop an image before text recognition
• Extract text from images
• Edit the extracted text
• Copy the extracted text
• Share the extracted text

Developed by Eugene Luckyson

Contact:
<eluckyon@gmail.com>

© 2026 Eugene Luckyson
```

Use the real app version where the original used `1.0` fallback.

---

## 5. Design tokens

- Theme: Material 3, DayNight, no action bar. Use standard M3 light/dark colours
  driven by `?android:colorBackground` equivalents (`Theme.of(context).colorScheme`).
- Settings FAB: `#1976d2` fill, `#64b5f6` stroke, white icon.
- Radii: image card 20, text card 16, buttons 14, icon button 28 (circular).
- Elevation: image card 2, text card 1, icon button 6.
- Spacing: screen padding 20, button gaps 6, section margins 10–20.
- Type: title 28/bold, subtitle 14, section heading 18–20/bold, buttons 15,
  extracted text 16, copyright 15/bold.

---

## 6. Additional user-visible strings

`Image to Text`, `Extract text from your images`, `No image selected`,
`Take a photo or choose an image from your gallery`, `Camera`, `Gallery`, `Crop`,
`Extract Text`, `Extracted Text`, `Extracted text will appear here...`, `Copy`,
`Share`, `Clear`, `Settings`, `Customize Image to Text`, `Appearance`,
`Choose how the app looks`, `Light Mode`, `Dark Mode`, `System Default`,
`Light mode enabled`, `Dark mode enabled`, `System mode enabled`, `Language`,
`Choose your preferred app language`, `App Language`, `Policies`,
`Learn about privacy and responsible use`, `Privacy Policy`, `Content Policy`,
`Support`, `Get help or learn more about the app`, `Contact Us`,
`About the App`, `Back`, `OK`, `Cancel`, `Unable to open Privacy Policy`,
`No email application found`, `© 2026 Eugene Luckyson`.

Runtime toasts are listed in §2.3/§4. Put all of them in ARB/localisation files.

---

## 7. Out of scope (do not rebuild)

- PairIP licensing / anti-tamper checks (Play-store protection only).
- The original's AdMob **test** IDs (`ca-app-pub-3940256099942544~3347511713` /
  `.../6300978111`) — use your own IDs or omit ads.
- Room/WorkManager/Startup/ProfileInstaller plumbing — implementation detail of the
  native app, not a user-facing feature.
- The unused bundled legacy `Beng_ctc` ML Kit asset — not wired into the original code.

---

## 8. Acceptance criteria

- [ ] App builds and runs on Android; `flutter analyze` and `flutter test` pass.
- [ ] Home layout matches §2.1 and all buttons are present and labelled exactly.
- [ ] Camera permission flow, capture, gallery pick, crop and preview work as in §2.3.
- [ ] Extract runs all five ML Kit scripts and picks the best result with the exact
      scoring function in §3; unit test covers the scoring and tie-break.
- [ ] Result box is editable and scrollable; caret moves to end after extraction.
- [ ] Copy / Share / Clear guards and toasts match exactly.
- [ ] Settings theme buttons change theme and persist across restarts.
- [ ] Language dialog lists all 21 entries in order and persists the selection.
- [ ] Privacy / Content Policy / Contact / About dialogs and links match §4.
- [ ] No backend or API key required for OCR; works offline once installed.
- [ ] No code/assets copied from the original APK.

---

## 9. Recommended build order (thin vertical slice first)

1. Scaffold Flutter project, theme, l10n, app shell and navigation.
2. Home screen UI + empty state + `none` state guards.
3. Gallery pick → preview → Extract with **Latin only** → show result (first working slice).
4. Add camera flow and cropper.
5. Add the remaining four recognisers and the exact scoring function + unit tests.
6. Copy / Share / Clear.
7. Settings screen: theme, language, dialogs, links.
8. Optional ads, then polish, `analyze`, `test`, acceptance review.

---

## 10. Documented improvements allowed (divergences)

- Thread-safe OCR result collection (fix the original's race).
- Real translations for the 21 locales (the original ships English strings only).
- Add a Bengali OCR path if desired (the original has none).
- Rebranding assets/colours while preserving layout and behaviour, if the owner wants
  a distinct identity.
