# Image to Text — Flutter rebuild

This repository holds the **hand-off documentation** for rebuilding the Android app
"Image to Text" (`com.tricksconnect.imagetotext`, version 1.1) as a **Flutter** app.
The Flutter source code is **not** here yet — it is to be written by the implementing
agent from the specification in this repo.

## Start here (for the implementing agent)

1. Read **`docs/IMPLEMENTATION_SPEC.md`** — the complete build spec: screens, flows,
   exact copy, OCR algorithm, settings behaviour, acceptance criteria, suggested file
   layout and build order. This is your primary instruction file.
2. Use **`docs/REVERSE_ENGINEERING_DOCS.md`** as the evidence/reference document. It
   records how the target app was reverse engineered and every behaviour observed in
   the original APK (layouts, strings, toasts, manifest, dependencies).
3. Implement the app at the repository root (`lib/`, `android/`, `l10n/`, `test/`).

## Ground rules

- Flutter stable / Dart 3+. Build a clean-room implementation from the spec.
- **Do not copy** any source code, resources, assets, or strings files out of the
  original APK. Rebuild everything from the written specification.
- Use a **new, unique `applicationId`**. Do not reuse `com.tricksconnect.imagetotext`.
- Keep the app name "Image to Text" unless the repository owner says otherwise.
- OCR must be 100% **on-device** with the five ML Kit scripts in the spec; no backend
  or API key is needed for the core feature.
- Banner ads on **both** screens are part of "works the same as the original".
  Use Google's test IDs during development and leave a clear TODO for replacing them
  with the owner's IDs before release. Only omit ads if the owner explicitly asks.
- Do not reproduce the original PairIP licensing/anti-tamper layer.

## Definition of done

- Every acceptance criterion in `docs/IMPLEMENTATION_SPEC.md` is satisfied.
- `flutter analyze` reports no issues; `flutter test` passes.
- This README is updated with setup/run instructions once the app exists.

## Repository contents

| Path | Purpose |
|---|---|
| `docs/IMPLEMENTATION_SPEC.md` | Build specification — **read first** |
| `docs/REVERSE_ENGINEERING_DOCS.md` | Reverse-engineering evidence and full app reference |

---

*Documentation prepared from static reverse engineering (jadx + apktool) of
`Image to Text_1.1.apk`. No dynamic analysis, patching, or repackaging was performed.*
