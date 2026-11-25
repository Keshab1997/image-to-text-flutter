# Reverse Engineering Report — "Image to Text" (Android OCR App)

> Goal: understand the target app completely and produce the specification needed to
> rebuild the same app in **Flutter**. This document is the reverse-engineering
> deliverable only; no source code of the clone has been written here.

---

## 1. App identity & build metadata

| Field | Value |
|---|---|
| APK file | `Image to Text_1.1.apk` (24,291,449 bytes) |
| Package | `com.tricksconnect.imagetotext` |
| App label | `Image to Text` |
| Version | `1.1` (versionCode `4`) |
| minSdk / targetSdk | `24` / `36` (compile SDK 36 / Android 16) |
| Implementation language | **Kotlin** (native Android, `MainActivity.kt`, `SettingsActivity.kt`) — *not* Flutter |
| Application class | `com.pairip.application.Application` (PairIP licence guard) |
| Developer (per About screen) | Eugene Luckyson — `eluckyon@gmail.com` |
| Privacy policy | `https://sites.google.com/view/privacypolicy-imagetotext/privacy-of-image-to-text` |
| Main launcher | `com.tricksconnect.imagetotext.MainActivity` |
| Other activity | `com.tricksconnect.imagetotext.SettingsActivity` (not exported) |
| Theme | `Theme.ImageToText` → `Theme.Material3.DayNight.NoActionBar` |

There is **no `lib/*.so`** in the APK — all app logic is in Java/Kotlin DEX. OCR runs
fully on-device; there is no custom backend/API for text recognition.

---

## 2. Tooling & evidence (reproducible commands)

Tools used from the local toolchain (`tool-index.md`), all available on this machine:

```bash
# Java/Kotlin decompilation
/Users/keshabsarkar/tools/jadx/bin/jadx -d jadx_out "/Users/keshabsarkar/Downloads/Image to Text_1.1.apk"
# Resource/smali decode
/Users/keshabsarkar/tools/bin/apktool d -f "/Users/keshabsarkar/Downloads/Image to Text_1.1.apk" -o apktool_out
```

Artifacts produced in `reverse_engineering/`:

- `jadx_out/sources/com/tricksconnect/imagetotext/` — the **only app-owned classes**:
  `MainActivity.java` (934 lines), `SettingsActivity.java` (285 lines), `R.java`.
  (13,391 other Java files are AndroidX / Material / Google / uCrop / Kotlin libs.)
- `apktool_out/AndroidManifest.xml`, `apktool_out/apktool.yml`,
  `apktool_out/res/layout/activity_main.xml`, `activity_settings.xml`,
  `apktool_out/res/values/strings.xml`, `apktool_out/res/xml/*.xml`
- `apktool_out/assets/mlkit-google-ocr-models/**` — bundled ML Kit OCR model files.

`jadx` finished with 99 non-fatal warnings (obfuscated library classes); the app's own
classes decompiled cleanly. No patching, repacking, Frida hooking, or device install
was performed — analysis was purely static.

---

## 3. Permissions & manifest facts

Declared permissions:

- `android.permission.CAMERA` — take photo
- `android.permission.INTERNET`, `ACCESS_NETWORK_STATE` — ads
- `com.google.android.gms.permission.AD_ID`, `ACCESS_ADSERVICES_AD_ID`,
  `ACCESS_ADSERVICES_ATTRIBUTION`, `ACCESS_ADSERVICES_TOPICS` — AdMob / Privacy Sandbox
- `WAKE_LOCK`, `FOREGROUND_SERVICE` — ads/WorkManager internals
- `com.android.vending.CHECK_LICENSE` + app-specific
  `com.tricksconnect.imagetotext.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`

Components:

- `MainActivity` — exported, `MAIN` + `LAUNCHER`
- `SettingsActivity` — not exported
- `com.yalantis.ucrop.UCropActivity` — portrait image cropper
- `androidx.core.content.FileProvider`, authority `com.tricksconnect.imagetotext.fileprovider`
  - paths (from `res/xml/file_paths.xml`): `cache-path` (`.`), `files-path` (`.`),
    `external-files-path` (`.`)
- ML Kit: `MlKitComponentDiscoveryService`, `MlKitInitProvider`
- Ads: `AdActivity`, `AdService`, `MobileAdsInitProvider`, `OutOfContextTestingActivity`,
  `NotificationHandlerActivity`
- `androidx.startup.InitializationProvider` (EmojiCompat, WorkManager, ProcessLifecycle,
  ProfileInstaller), Room `MultiInstanceInvalidationService`, WorkManager services/receivers
- PairIP: `com.pairip.licensecheck.LicenseActivity`

AdMob IDs (both are **Google's official test IDs** — the shipped app is not serving
real ads):

- App ID: `ca-app-pub-3940256099942544~3347511713`
- Banner unit (both screens): `ca-app-pub-3940256099942544/6300978111`

PairIP guard: `Application.attachBaseContext()` calls
`LicenseClient.checkLicense(context)` before `super` — a Play licensing/anti-tamper
layer. It is **not** part of the app's user-facing functionality and can be omitted
in a clean-room Flutter rebuild.

---

## 4. Screen 1 — MainActivity (home)

### 4.1 View hierarchy (`res/layout/activity_main.xml`)

```
LinearLayout (vertical, background=?android:colorBackground)
├── Header (horizontal, padding 20dp, top/bottom 12dp)
│   ├── Title TextView: "Image to Text" — 28sp, bold, ?textColorPrimary
│   ├── Subtitle TextView: "Extract text from your images" — 14sp, ?textColorSecondary
│   └── settingsButton: 56×56dp circular MaterialButton, tint #1976d2, stroke #64b5f6,
│                        icon ic_settings 30dp white, contentDescription "Settings"
├── NestedScrollView (weight=1, fillViewport=true)
│   └── LinearLayout (padding 20dp)
│       ├── MaterialCardView 300dp tall, cornerRadius 20dp, elevation 2dp
│       │   └── FrameLayout
│       │       ├── emptyImageView (LinearLayout, centered, initially VISIBLE)
│       │       │   ├── ImageView 64dp @android:drawable/ic_menu_gallery, alpha 0.55
│       │       │   ├── "No image selected" 18sp bold
│       │       │   └── "Take a photo or choose an image from your gallery" 14sp
│       │       └── imagePreview ImageView (initially GONE, fitCenter, adjustViewBounds)
│       ├── Row: [cameraButton "Camera"] [galleryButton "Gallery"]  (weight=1 each,
│       │        material buttons, 15sp, sentence case, cornerRadius 14dp,
│       │        icons ic_menu_camera / ic_menu_gallery)
│       ├── Row: [cropButton "Crop"] [extractButton "Extract Text"]
│       ├── progressBar (ProgressBar, centered, initially GONE)
│       ├── "Extracted Text" TextView 20sp bold
│       ├── MaterialCardView 260dp tall, cornerRadius 16dp
│       │   └── resultText EditText: hint "Extracted text will appear here...",
│       │       16sp, multiline, gravity start|top, vertical scrollbar always,
│       │       inputType=textCapSentences|textMultiLine, selectable, focusable,
│       │       ScrollingMovementMethod, touch listener to keep scroll inside
│       ├── Row: [copyButton "Copy"] [shareButton "Share"]
│       └── clearButton "Clear" (OutlinedButton, full width)
├── copyrightText: "© 2026 Eugene Luckyson" 15sp bold, centered
└── adView: AdView BANNER, test unit ID
```

Insets: `ViewCompat.setOnApplyWindowInsetsListener` applies system-bar insets as
padding on the root content view (all sides).

### 4.2 State fields

- `selectedImageUri : Uri?` — URI of a gallery/camera image
- `selectedBitmap : Bitmap?` — decoded bitmap after cropping (crop result is stored here)
- `cameraImageUri : Uri?` — URI created for the camera capture
- `imagePreview`, `emptyImageView`, `resultText`, `progressBar`, `adView`

Only one of `selectedImageUri` / `selectedBitmap` is active at a time (the other is
nulled when one is set).

### 4.3 Activity Result contracts

| Launcher | Contract | Behaviour |
|---|---|---|
| `galleryLauncher` | `GetContent()` | launches `"image/*"`; on result sets `selectedImageUri`, clears `selectedBitmap` and `cameraImageUri`, shows preview, hides empty view, clears result text |
| `cameraLauncher` | `TakePicture()` | on success (`true` + uri): sets `selectedImageUri`, clears bitmap, shows preview/hides empty, clears text, toast **"Photo captured successfully"**; on failure: deletes the temp URI if non-null, toast **"Camera capture cancelled"** |
| `cameraPermissionLauncher` | `RequestPermission()` | granted → `openCamera()`; denied → toast **"Camera permission is required"** (length LONG) |
| `cropLauncher` | `StartActivityForResult()` | `RESULT_OK` → `UCrop.getOutput(data)` → `loadCroppedImage(uri)`; else toast "Could not get cropped image". `RESULT_CANCELED` (96) → toast `"Crop failed: " + error.message` (or "Unknown error") |

### 4.4 Button behaviours

**Camera** (`openCamera`):
- if `CAMERA` permission not granted → request it
- else create `File(cacheDir, "camera_" + System.currentTimeMillis() + ".jpg")`,
  get URI via `FileProvider.getUriForFile(this, "com.tricksconnect.imagetotext.fileprovider", file)`,
  store in `cameraImageUri`, launch `TakePicture`
- on exception: `cameraImageUri = null`, toast `"Could not open camera: " + message` (LONG)

**Gallery**: `galleryLauncher.launch("image/*")`.

**Crop** (`openCrop`):
- `getCurrentImageUri()` returns `selectedImageUri` if present, otherwise if
  `selectedBitmap != null` it writes the bitmap to `cacheDir/camera_<ts>.jpg` at JPEG
  quality 95 and returns a `Uri.fromFile(...)`.
- If no image: toast **"Please choose or take an image first"** (SHORT).
- uCrop options: `freeStyleCropEnabled=true`, `showCropGrid=true`, `showCropFrame=true`,
  toolbar title **"Crop Image"**, compression JPEG quality 95,
  `hideBottomControls=false`, `withMaxResultSize(4096, 4096)`,
  output `cacheDir/cropped_<ts>.jpg`.
- `loadCroppedImage(uri)`: opens input stream, `BitmapFactory.decodeStream`, closes
  stream; sets `selectedBitmap = bitmap`, `selectedImageUri = null`, `cameraImageUri = null`,
  shows preview, hides empty view, clears result, toast **"Image cropped successfully"**.
  Errors → toast `"Could not load cropped image: " + message` (LONG).

**Settings** button: `startActivity(Intent(this, SettingsActivity))`.

**Extract Text** (`extractText`):
- guard: if both `selectedImageUri` and `selectedBitmap` are null → toast
  **"Please choose an image first"** (SHORT), return.
- show `progressBar`
- `InputImage`: if `selectedBitmap != null` → `InputImage.fromBitmap(bitmap, 0)`;
  else `InputImage.fromFilePath(this, selectedImageUri)`
- call `runMultilingualOcr(image)`
- on exception: hide progress, toast `"Unable to process image: " + message` (LONG)

**Copy** (`copyText`): if result is blank → toast **"There is no text to copy"**;
else `ClipboardManager.setPrimaryClip(ClipData.newPlainText("Extracted Text", text))`,
toast **"Text copied"**.

**Share** (`shareText`): if blank → toast **"There is no text to share"**; else
`Intent(ACTION_SEND).setType("text/plain").putExtra(EXTRA_TEXT, text)`,
`startActivity(Intent.createChooser(intent, "Share extracted text"))`.

**Clear** (`clearAll`): nulls all three image state fields, clears preview drawable,
hides preview, shows empty view, clears text, hides progress, toast **"Cleared"**.

Lifecycle: `onPause → adView.pause()`, `onResume → adView.resume()`,
`onDestroy → adView.destroy()`.

Ad setup: `MobileAds.initialize(...)` → on completion `loadBannerAd()` builds an
`AdRequest`, attaches a verbose `AdListener` that logs to Logcat tag
`ImageToTextAdMob` (`TEST BANNER AD LOADED SUCCESSFULLY`, error code/message/domain,
impression/click/close), then `adView.loadAd(request)` and logs "Requested test banner ad".

---

## 5. OCR engine — the core logic

### 5.1 Five recognisers run concurrently (`runMultilingualOcr`)

```kotlin
val results = mutableListOf<String>()
val recognizers = listOf(
    TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS),       // Latin
    TextRecognition.getClient(ChineseTextRecognizerOptions.Builder().build()),
    TextRecognition.getClient(DevanagariTextRecognizerOptions.Builder().build()),
    TextRecognition.getClient(JapaneseTextRecognizerOptions.Builder().build()),
    TextRecognition.getClient(KoreanTextRecognizerOptions.Builder().build())
)
val completed = IntRef(0)
recognizers.forEach { recognizer ->
    recognizer.process(image)
        .addOnSuccessListener { text ->
            val trimmed = text.text.trim()
            if (!trimmed.isBlank()) results.add(trimmed)
            completed.element++
            if (completed.element == recognizers.size) {
                recognizers.forEach { it.close() }
                showBestOcrResult(results)
            }
        }
        .addOnFailureListener {
            completed.element++
            if (completed.element == recognizers.size) {
                recognizers.forEach { it.close() }
                showBestOcrResult(results)
            }
        }
}
```

Failure of one recogniser is ignored; results from the others still count. All five
are closed when the fifth callback fires. The result list is an unsynchronised
`ArrayList` appended from callbacks — a minor race in the original, to be avoided
in the Flutter rewrite.

**Language note:** although the APK bundles legacy ML Kit model assets including
`Beng_ctc` (Bengali) and Devanagari/Chinese/Japanese/Korean, the running code uses
only the five public ML Kit Text Recognition v2 script options listed above. There
is **no Bengali recogniser option** — Bengali text would be handled by the Latin
model at best. The bundled Bengali model is unused by the app code.

### 5.2 Choosing the best result (`showBestOcrResult` + `calculateOcrScore`)

```kotlin
private fun calculateOcrScore(text: String): Int {
    var score = 0
    for (c in text) {
        when {
            c in '\u4E00'..'\u9FFF' ||   // 19968..40959 CJK
            c in '\u3040'..'\u30BF' ||   // 12352..12447 Hiragana/Katakana
            c in '\u30C0'..'\u30FF' ||   // 12448..12543 Katakana
            c in '\uAC00'..'\uD7AF' ||   // 44032..55215 Hangul
            c in '\u0900'..'\u097F' -> score += 5   // 2304..2431 Devanagari
            c.isLetterOrDigit() -> score += 2
            c.isWhitespace() -> score += 1
        }
    }
    return score + text.length
}
```

`showBestOcrResult(results)`:
- hide progress bar
- if `results.isEmpty()` → clear result text + toast **"No text was detected"** (SHORT)
- else pick the string with the highest `calculateOcrScore` (first one wins ties),
  set it into `resultText`, move cursor to end, toast **"Text extracted successfully"**

Note: Bengali characters (U+0980–U+09FF) fall into the generic `isLetterOrDigit`
branch (+2), not the +5 CJK/Devanagari branch — so the scoring heuristic implicitly
favours CJK/Devanagari results over Bengali ones.

---

## 6. Screen 2 — SettingsActivity

Layout (`res/layout/activity_settings.xml`): vertical `LinearLayout`; header
"Settings" (26sp bold) + "Customize Image to Text" (14sp); divider; a
`NestedScrollView` containing grouped sections; copyright "© 2026 Eugene Luckyson";
banner AdView (same test unit ID). Root insets applied to **bottom only**.

| Section | Row (button id) | Action |
|---|---|---|
| **Appearance** / "Choose how the app looks" | `lightModeButton` "Light Mode" | `AppCompatDelegate.setDefaultNightMode(MODE_NIGHT_NO = 1)`, toast "Light mode enabled" |
| | `darkModeButton` "Dark Mode" | `setDefaultNightMode(MODE_NIGHT_YES = 2)`, toast "Dark mode enabled" |
| | `systemModeButton` "System Default" | `setDefaultNightMode(MODE_NIGHT_FOLLOW_SYSTEM = -1)`, toast "System mode enabled" |
| **Language** / "Choose your preferred app language" | `languageButton` "App Language" | single-choice AlertDialog |
| **Policies** / "Learn about privacy and responsible use" | `privacyButton` "Privacy Policy" | `ACTION_VIEW` the Google Sites privacy URL; on failure toast "Unable to open Privacy Policy" (LONG) |
| | `contentPolicyButton` "Content Policy" | AlertDialog titled "Content Policy" with `content_policy_message`, button "OK" |
| **Support** / "Get help or learn more about the app" | `contactButton` "Contact Us" | `ACTION_SENDTO` `mailto:eluckyon@gmail.com`, subject "Image to Text Support", body from `contact_email_body`; on failure toast "No email application found" |
| | `aboutButton` "About the App" | AlertDialog "About Image to Text" with `about_message` formatted with version name (fallback "1.0") and contact email |
| — | `backButton` "Back" | `finish()` |

### Language dialog

21 choices, with tags (order matters for parity):

```
English(en), Français(fr), Español(es), Deutsch(de), Português(pt), Italiano(it),
العربية(ar), 中文(zh), 日本語(ja), 한국어(ko), हिन्दी(hi), বাংলা(bn), Русский(ru),
Bahasa Indonesia(id), اردو(ur), Tiếng Việt(vi), Türkçe(tr), Kinyarwanda(rw),
Kiswahili(sw), मराठी(mr), తెలుగు(te)
```

The currently applied locale (from `AppCompatDelegate.getApplicationLocales()[0].language`)
is preselected; choosing an item calls
`AppCompatDelegate.setApplicationLocales(LocaleListCompat.forLanguageTags(tag))`
(AppCompat applies locale change automatically) and dismisses. Negative button "Cancel".

`res/xml/locales_config.xml` declares the same set (Indonesian declared as `in`
there, `id` in code). **Important:** the APK contains only the default English
`values/strings.xml` — there are no translated `values-<lang>` directories — so in
practice the in-app strings stay in English regardless of the chosen locale.

---

## 7. Full user-visible copy (default / English, from `values/strings.xml`)

Core app strings:

| key | text |
|---|---|
| `app_name` / `main_title` | Image to Text |
| `main_subtitle` | Extract text from your images |
| `no_image_selected` | No image selected |
| `choose_image_hint` | Take a photo or choose an image from your gallery |
| `camera` / `gallery` / `crop` | Camera / Gallery / Crop |
| `extract_text` | Extract Text |
| `extracted_text` | Extracted Text |
| `extracted_text_hint` | Extracted text will appear here... |
| `copy` / `share` / `clear` | Copy / Share / Clear |
| `settings` / `settings_title` | Settings / Settings |
| `settings_subtitle` | Customize Image to Text |
| `appearance` / `appearance_description` | Appearance / Choose how the app looks |
| `light_mode` / `dark_mode` / `system_default` | Light Mode / Dark Mode / System Default |
| `light_mode_enabled` / `dark_mode_enabled` / `system_mode_enabled` | Light mode enabled / Dark mode enabled / System mode enabled |
| `language` / `language_description` / `app_language` | Language / Choose your preferred app language / App Language |
| `policies` / `policies_description` | Policies / Learn about privacy and responsible use |
| `privacy_policy` / `content_policy` | Privacy Policy / Content Policy |
| `support` / `support_description` | Support / Get help or learn more about the app |
| `contact_us` / `about_app` / `back` | Contact Us / About the App / Back |
| `ok` / `cancel` | OK / Cancel |
| `unable_to_open_privacy_policy` | Unable to open Privacy Policy |
| `no_email_application` | No email application found |
| `contact_email_subject` | Image to Text Support |
| `contact_email_body` | Hello Tricks Connect,\n\nI need help with the Image to Text app.\n\nMy question or issue:\n\n\nThank you. |
| `content_policy_message` | Image to Text is designed for legitimate text recognition and productivity purposes. You are responsible for the images and content you process using the app. Please do not use Image to Text to process, distribute, or share content that violates applicable laws or the rights of other people. Do not use the app for harassment, abuse, fraud, or any other harmful activity. Please respect copyright, privacy, intellectual property, and other applicable rights. By using Image to Text, you agree to use the application responsibly and lawfully. |
| `about_title` | About Image to Text |
| `about_message` | Image to Text — Extract text quickly and easily from images using Optical Character Recognition (OCR). FEATURES • Take a photo with your camera • Choose an image from your gallery • Crop an image before text recognition • Extract text from images • Edit the extracted text • Copy the extracted text • Share the extracted text. Developed by Eugene Luckyson. Contact: %2$s. © 2026 Eugene Luckyson |
| `developed_by` | Developed by Eugene Luckyson |
| `footer` | Image to Text • © 2026 Eugene Luckyson |

Runtime toasts (hardcoded in Kotlin, not in strings.xml) are listed in §4.3–4.4.

---

## 8. Visual design tokens

- Theme: Material 3 DayNight, `NoActionBar`.
- Primary blue used on the settings FAB: `#1976d2`, stroke `#64b5f6`, white icon.
- Corner radii: preview card 20dp, text card 16dp, buttons 14dp, FAB 28dp (circular).
- Elevation: preview card 2dp, text card 1dp, FAB 6dp.
- Spacing: screen padding 20dp, button row gaps 6dp, section margins 10–20dp.
- Typography: title 28sp bold, subtitle/body-secondary 14sp, section heading 18–20sp bold,
  buttons 15sp (sentence case), extracted text 16sp, copyright 15sp bold.
- Dark mode: system Material 3 `?android:colorBackground` / `?textColorPrimary` /
  `?textColorSecondary` — i.e. no custom colours; Flutter should use standard
  Material 3 light/dark colour schemes.

---

## 9. Third-party SDKs (dependency inventory)

| Concern | Library / SDK |
|---|---|
| OCR | Google ML Kit Text Recognition v2 (Latin, Chinese, Devanagari, Japanese, Korean) — models bundled in assets |
| Image cropping | uCrop (`com.yalantis:ucrop`) |
| Ads | Google Mobile Ads (AdMob), test IDs |
| UI | AndroidX AppCompat, Material Components (Material3), ConstraintLayout, CardView, RecyclerView |
| Architecture | Kotlin coroutines, AndroidX WorkManager, Room, Lifecycle/Startup, ProfileInstaller |
| File sharing | AndroidX Core FileProvider |
| Licensing / anti-tamper | PairIP (`com.pairip.application.Application`, `LicenseClient.checkLicense`) |
| Language | AppCompatDelegate per-app locales (`LocaleListCompat`) |

---

## 10. Flutter rebuild specification (feature parity guide)

The clone is a fresh implementation — no original source/assets/copy beyond the
functional spec above should be reused. Recommended stack and mapping:

### 10.1 Suggested packages

| Need | Flutter package | Notes |
|---|---|---|
| Camera + gallery | `image_picker` | `ImageSource.camera` / `.gallery`; handles the FileProvider/URI plumbing for you. Request `CAMERA` permission at runtime. |
| Crop | `image_cropper` | On Android it wraps **uCrop** — closest possible parity. Configure `freeStyleCropEnabled: true`, `showCropGrid: true`, `showCropFrame: true`, `JPEG` quality 95, max size 4096×4096, toolbar title "Crop Image". |
| OCR | `google_mlkit_text_recognition` | Provides exactly the five script options used by the target: `TextRecognitionScript.latin`, `.chinese`, `.devanagari`, `.japanese`, `.korean`. Run all five on the same `InputImage`, gather non-blank `recognisedText.trim()` results. |
| Ads (optional) | `google_mobile_ads` | Use test IDs during development; replace with your own app ID / banner unit for release. Can be omitted entirely for an ad-free clone. |
| Clipboard | `Clipboard` from `flutter/services` | label/annotation "Extracted Text". |
| Share | `share_plus` | `Share.share(text, subject: ...)` gives the OS chooser. |
| Theme | `ThemeMode` + `shared_preferences` | light / dark / system; persist the choice (original relies on AppCompat's system persistence). |
| Localisation | `flutter_localizations` + `intl` (ARB files) or `easy_localization` | 21 locale tags from §6. Note the original ships no translations — you can actually implement them for a better clone. |
| Temp files | `path_provider` | `getTemporaryDirectory()` ≈ Android `cacheDir`; file names `camera_<ts>.jpg`, `cropped_<ts>.jpg`. |

### 10.2 Behaviour checklist (must match)

1. Home shows title + subtitle + circular settings button; empty image card with
   gallery icon, "No image selected" and hint; two button rows (Camera/Gallery,
   Crop/Extract Text); progress spinner; editable, scrollable extracted-text card;
   Copy/Share row; full-width outlined Clear button; copyright; banner ad.
2. Camera: permission flow, capture to temp file, preview, success/cancel toasts.
3. Gallery: pick `image/*`, preview, clear previous result.
4. Crop: open cropper on the current image (re-encoding the in-memory bitmap to a
   temp file first if needed), replace image state with cropped bitmap, clear result.
5. Extract: guard for no image, spinner, build InputImage, run 5 OCR recognisers,
   collect non-blank trimmed results, close recognisers, pick best by the exact
   scoring function in §5.2, show result, move caret to end, toast.
6. Best-result scoring: CJK/Hiragana/Katakana/Hangul/Devanagari +5 each; other
   letters/digits +2; whitespace +1; final `score += text.length`.
7. Copy / Share / Clear with the exact toasts and guards.
8. Settings: three theme buttons, language dialog (21 items, current locale
   preselected), privacy URL, content-policy dialog, contact email intent, about
   dialog with version, back. Banner ad on settings too.
9. Lifecycle: pause/resume/destroy the ad view if ads are implemented.
10. Insets: apply system-bar padding; on settings apply bottom padding only.

### 10.3 Deliberate improvements you may make (documented divergence)

- Make the OCR result aggregation thread-safe (use isolates/completer or a
  synchronized collection) — the original mutates an `ArrayList` from callbacks.
- Add real translations for the 21 declared locales (original has none).
- Add a Bengali OCR path if you need Bengali support (e.g. an external OCR engine);
  the original's bundled `Beng_ctc` ML Kit legacy model is not wired into its code.
- Replace PairIP license guard with your own release hardening if desired; it is
  not a functional requirement of the app.
- Use your own AdMob IDs, or ship ad-free.

---

## 11. Limitations of this analysis

- Static analysis only; no dynamic Frida hooking or on-device run was done, so
  runtime-only behaviour (exact ML Kit model download/pinning, ad fill, PairIP
  response) was not observed.
- `jadx` reported 99 warnings on obfuscated third-party classes; app-owned classes
  were fully recovered, so the functional spec above is complete.
- The licence guard internals (`com.pairip.*`) were only inspected at the entry
  point; they are out of scope for a clean-room Flutter rebuild.
