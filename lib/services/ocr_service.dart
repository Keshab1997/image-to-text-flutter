import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tesseract_ocr/ocr_engine_config.dart';
import 'package:tesseract_ocr/tesseract_ocr.dart';

final RegExp _unicodeLetterOrDigit = RegExp(r'^[\p{L}\p{Nd}]$', unicode: true);

/// Checks whether [rune] is a Unicode letter or decimal digit
/// (equivalent to Java's `Character.isLetterOrDigit`).
bool isUnicodeLetterOrDigit(int rune) {
  if ((rune >= 0x30 && rune <= 0x39) || // 0-9
      (rune >= 0x41 && rune <= 0x5A) || // A-Z
      (rune >= 0x61 && rune <= 0x7A)) {
    // a-z
    return true;
  }
  if (rune < 0x80) {
    return false;
  }
  return _unicodeLetterOrDigit.hasMatch(String.fromCharCode(rune));
}

/// Checks whether [rune] is Unicode whitespace
/// (equivalent to Kotlin's `Char.isWhitespace()`).
bool isUnicodeWhitespace(int rune) {
  if (rune == 0x20 || (rune >= 0x09 && rune <= 0x0D)) {
    return true;
  }
  if (rune >= 0x1C && rune <= 0x1F) {
    return true;
  }
  if (rune == 0x85 ||
      rune == 0xA0 ||
      rune == 0x1680 ||
      (rune >= 0x2000 && rune <= 0x200A) ||
      rune == 0x2028 ||
      rune == 0x2029 ||
      rune == 0x202F ||
      rune == 0x205F ||
      rune == 0x3000) {
    return true;
  }
  return false;
}

/// Exact best-result scoring function from IMPLEMENTATION_SPEC.md §3.
///
/// - CJK (19968..40959), Hiragana/Katakana (12352..12447),
///   Katakana (12448..12543), Hangul (44032..55215),
///   Devanagari (2304..2431): +5 per character
/// - Other Unicode letters or digits (including Latin, Bengali U+0980..U+09FF, etc.): +2
/// - Whitespace: +1
/// - Plus `text.length` (UTF-16 code unit length, matching Kotlin `text.length`).
int calculateOcrScore(String text) {
  var score = 0;
  for (final c in text.runes) {
    if ((c >= 19968 && c < 40960) || // CJK
        (c >= 12352 && c < 12448) || // Hiragana / Katakana
        (c >= 12448 && c < 12544) || // Katakana
        (c >= 44032 && c < 55216) || // Hangul
        (c >= 2304 && c < 2432)) {
      // Devanagari
      score += 5;
    } else if (isUnicodeLetterOrDigit(c)) {
      score += 2;
    } else if (isUnicodeWhitespace(c)) {
      score += 1;
    }
  }
  return score + text.length;
}

/// Picks the non-blank trimmed result with the highest [calculateOcrScore].
/// Ties always go to the FIRST result in [results].
/// Returns `null` if [results] has no non-empty strings.
String? selectBestOcrResult(Iterable<String> results) {
  String? bestText;
  int? bestScore;

  for (final raw in results) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final score = calculateOcrScore(trimmed);
    if (bestScore == null || score > bestScore) {
      bestScore = score;
      bestText = trimmed;
    }
  }
  return bestText;
}

/// Abstraction over a single script recognizer for testability.
typedef ScriptRecognizerRunner = Future<String> Function(
  TextRecognitionScript script,
  InputImage inputImage,
);

typedef BengaliTesseractRunner = Future<String> Function(String imagePath);

/// On-device OCR: five ML Kit scripts plus Tesseract for Bengali text.
class OcrService {
  OcrService({
    ScriptRecognizerRunner? scriptRunner,
    BengaliTesseractRunner? bengaliRunner,
    Directory? tempDirectoryOverride,
  })  : _scriptRunner = scriptRunner ?? _defaultScriptRunner,
        _bengaliRunner = bengaliRunner ??
            (scriptRunner == null ? _defaultBengaliRunner : _skipBengaliRunner),
        _tempDirectoryOverride = tempDirectoryOverride;

  final ScriptRecognizerRunner _scriptRunner;
  final BengaliTesseractRunner _bengaliRunner;
  final Directory? _tempDirectoryOverride;

  /// The exact 5 ML Kit scripts specified in IMPLEMENTATION_SPEC.md §3.
  static const List<TextRecognitionScript> supportedScripts = [
    TextRecognitionScript.latin,
    TextRecognitionScript.chinese,
    TextRecognitionScript.devanagiri,
    TextRecognitionScript.japanese,
    TextRecognitionScript.korean,
  ];

  static Future<String> _defaultScriptRunner(
    TextRecognitionScript script,
    InputImage inputImage,
  ) async {
    final recognizer = TextRecognizer(script: script);
    try {
      final recognized = await recognizer.processImage(inputImage);
      return recognized.text;
    } finally {
      await recognizer.close();
    }
  }

  static Future<String> _defaultBengaliRunner(String imagePath) {
    return TesseractOcr.extractText(
      imagePath,
      config: const OCRConfig(
        language: 'ben',
        engine: OCREngine.tesseract,
      ),
    );
  }

  static Future<String> _skipBengaliRunner(String _) async => '';

  static final RegExp _bengaliScript = RegExp(r'[\u0980-\u09FF]');

  /// Runs five ML Kit scripts plus on-device Bengali OCR when an image path is
  /// available. Bengali OCR can correct unsupported-script results, but it
  /// must not replace a stronger Latin result with a Bengali false positive.
  Future<String?> recognizeBestText(InputImage inputImage) async {
    final futures = <Future<String?>>[
      ...supportedScripts.map((script) async {
        try {
          final rawText = await _scriptRunner(script, inputImage);
          final trimmed = rawText.trim();
          return trimmed.isNotEmpty ? trimmed : null;
        } catch (_) {
          // Individual recogniser failures are ignored per Spec §3.
          return null;
        }
      }),
    ];

    final imagePath = inputImage.filePath;
    if (imagePath != null) {
      futures.add(() async {
        try {
          final rawText = await _bengaliRunner(imagePath);
          final trimmed = rawText.trim();
          return trimmed.isNotEmpty ? trimmed : null;
        } catch (_) {
          // Bengali OCR is optional; preserve the existing recognizers' result.
          return null;
        }
      }());
    }

    final resolved = await Future.wait<String?>(futures);
    final validResults = resolved.whereType<String>().toList(growable: false);
    final bengaliResults = validResults
        .where((result) => _bengaliScript.hasMatch(result))
        .toList(growable: false);
    if (bengaliResults.isEmpty) {
      return selectBestOcrResult(validResults);
    }

    final bestBengali = selectBestOcrResult(bengaliResults)!;
    final latinResult = resolved.isEmpty ? null : resolved.first;
    if (latinResult != null &&
        calculateOcrScore(latinResult) >= calculateOcrScore(bestBengali)) {
      return latinResult;
    }
    return bestBengali;
  }

  /// Extracts text from an image file path (state `uri`).
  Future<String?> extractFromFilePath(String path) async {
    final file = File(path);
    if (!file.existsSync()) {
      throw FileSystemException('Image file does not exist', path);
    }
    final inputImage = InputImage.fromFilePath(path);
    return recognizeBestText(inputImage);
  }

  /// Extracts text across multiple image paths in order (Batch Multi-Page Scan)
  /// and combines non-empty pages into a single formatted document.
  Future<String?> extractFromMultipleFilePaths(List<String> paths) async {
    if (paths.isEmpty) return null;
    final pageSections = <String>[];
    for (var i = 0; i < paths.length; i++) {
      final pageText = await extractFromFilePath(paths[i]);
      if (pageText != null && pageText.trim().isNotEmpty) {
        if (paths.length == 1) {
          pageSections.add(pageText.trim());
        } else {
          pageSections.add('--- Page ${i + 1} ---\n${pageText.trim()}');
        }
      }
    }
    if (pageSections.isEmpty) return null;
    return pageSections.join('\n\n');
  }

  /// Extracts text from an in-memory bitmap (state `bitmap`, rotation 0).
  Future<String?> extractFromBitmapBytes(Uint8List bitmapBytes) async {
    if (bitmapBytes.isEmpty) {
      throw ArgumentError('Bitmap bytes are empty');
    }
    final dir = _tempDirectoryOverride ?? await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final tempFile = File('${dir.path}/ocr_bitmap_$ts.jpg');
    tempFile.writeAsBytesSync(bitmapBytes, flush: true);
    try {
      final inputImage = InputImage.fromFilePath(tempFile.path);
      return await recognizeBestText(inputImage);
    } finally {
      if (tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }
    }
  }
}
