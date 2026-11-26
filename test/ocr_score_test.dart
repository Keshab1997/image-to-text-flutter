import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:snaptext_ocr/services/ocr_service.dart';

void main() {
  group('calculateOcrScore — Spec §3 exact scoring algorithm', () {
    test('scores Latin letters, digits, and spaces accurately', () {
      // 'Hello 123' -> 8 letters/digits (*2 = 16) + 1 space (*1 = 1) + length 9 = 26
      expect(calculateOcrScore('Hello 123'), equals(26));
    });

    test('scores CJK characters (+5 per rune + length)', () {
      // '你好世界' -> 4 CJK runes in 19968..40959 (*5 = 20) + length 4 = 24
      expect(calculateOcrScore('你好世界'), equals(24));
    });

    test('scores Devanagari characters (+5 per rune + length)', () {
      // 'कमल' -> 3 Devanagari runes in 2304..2431 (*5 = 15) + length 3 = 18
      expect(calculateOcrScore('कमल'), equals(18));
    });

    test('scores Japanese Hiragana and Katakana (+5 per rune + length)', () {
      // 'あいうア' -> 3 Hiragana (12352..12447) + 1 Katakana (12448..12543) = 4 * 5 + 4 = 24
      expect(calculateOcrScore('あいうア'), equals(24));
    });

    test('scores Korean Hangul (+5 per rune + length)', () {
      // '한글' -> 2 Hangul runes in 44032..55215 (*5 = 10) + length 2 = 12
      expect(calculateOcrScore('한글'), equals(12));
    });

    test(
        'preserves Bengali quirk (U+0980..U+09FF scored as letter/digit +2, not +5)',
        () {
      // 'কখগ' -> 3 Bengali letters (*2 = 6) + length 3 = 9
      expect(calculateOcrScore('কখগ'), equals(9));
    });

    test('scores whitespace-only strings (+1 per whitespace + length)', () {
      // '  \n\t' -> 4 whitespace runes (*1 = 4) + length 4 = 8
      expect(calculateOcrScore('  \n\t'), equals(8));
    });

    test('scores punctuation-only strings by length only', () {
      expect(calculateOcrScore('...'), equals(3));
    });
  });

  group('selectBestOcrResult — tie-breaking and trimming', () {
    test('picks the highest-scoring trimmed result', () {
      final results = [
        'Hi', // 2*2 + 2 = 6
        '你好世界', // 4*5 + 4 = 24
        'Hello', // 5*2 + 5 = 15
      ];
      expect(selectBestOcrResult(results), equals('你好世界'));
    });

    test('breaks ties in favour of the FIRST result', () {
      // 'abc' and 'xyz' both have score 3*2 + 3 = 9
      final results = ['  abc  ', 'xyz'];
      expect(selectBestOcrResult(results), equals('abc'));
    });

    test('returns null when all results are empty or whitespace', () {
      expect(selectBestOcrResult(['', '   ', '\n\t']), isNull);
    });
  });

  group('OcrService — 5-script concurrent execution', () {
    test('runs all 5 scripts and ignores individual failures', () async {
      final calledScripts = <TextRecognitionScript>[];
      final service = OcrService(
        scriptRunner: (script, image) async {
          calledScripts.add(script);
          if (script == TextRecognitionScript.chinese) {
            throw Exception('Model download simulated error');
          }
          if (script == TextRecognitionScript.latin) {
            return '  Extracted Latin line  ';
          }
          if (script == TextRecognitionScript.devanagiri) {
            return 'नमस्ते भारत';
          }
          return '';
        },
      );

      final fakeImage = InputImage.fromFilePath('/tmp/non_existent_dummy.jpg');
      final best = await service.recognizeBestText(fakeImage);

      expect(
        calledScripts,
        containsAll(OcrService.supportedScripts),
      );
      expect(calledScripts.length, equals(5));
      // Devanagari 'नमस्ते भारत' scores higher than 'Extracted Latin line'
      expect(best, equals('नमस्ते भारत'));
    });
  });
}
