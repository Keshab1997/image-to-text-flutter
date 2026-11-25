import 'package:flutter/material.dart';

enum DetectedEntityKind {
  email(Icons.alternate_email_rounded, Color(0xFF7C4DFF)),
  phone(Icons.call_rounded, Color(0xFF00BFA5)),
  url(Icons.link_rounded, Color(0xFF2979FF)),
  amount(Icons.currency_rupee_rounded, Color(0xFFFF6D00)),
  date(Icons.event_rounded, Color(0xFFEC407A));

  const DetectedEntityKind(this.icon, this.color);
  final IconData icon;
  final Color color;
}

class DetectedEntity {
  const DetectedEntity({
    required this.kind,
    required this.value,
  });

  final DetectedEntityKind kind;
  final String value;
}

/// Offline zero-token smart entity detector and OCR text formatter for SnapText OCR.
class SmartEntityService {
  const SmartEntityService._();

  static final RegExp _emailRegex = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
  );

  static final RegExp _urlRegex = RegExp(
    r'(?:https?:\/\/|www\.)[^\s,;)]+',
    caseSensitive: false,
  );

  static final RegExp _phoneRegex = RegExp(
    r'(?:\+?\d{1,3}[\s-]?)?(?:\(?\d{3,5}\)?[\s-]?)?\d{3,5}[\s-]?\d{4}',
  );

  static final RegExp _amountRegex = RegExp(
    r'(?:₹|৳|\$|€|£|Rs\.?|INR|BDT|USD)\s?\d+(?:[.,]\d{1,2})?',
    caseSensitive: false,
  );

  static final RegExp _dateRegex = RegExp(
    r'\b(?:\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}|\d{4}[\/\-]\d{1,2}[\/\-]\d{1,2})\b',
  );

  static List<DetectedEntity> detectEntities(String text) {
    if (text.trim().isEmpty) return const <DetectedEntity>[];
    final seen = <String>{};
    final out = <DetectedEntity>[];

    void collect(
      RegExp regex,
      DetectedEntityKind kind, {
      int minDigits = 0,
    }) {
      for (final match in regex.allMatches(text)) {
        final value = match.group(0)?.trim() ?? '';
        if (value.isEmpty) continue;
        if (minDigits > 0) {
          final digits =
              value.runes.where((r) => r >= 0x30 && r <= 0x39).length;
          if (digits < minDigits) continue;
        }
        if (seen.add('${kind.name}:$value')) {
          out.add(DetectedEntity(kind: kind, value: value));
        }
      }
    }

    collect(_emailRegex, DetectedEntityKind.email);
    collect(_urlRegex, DetectedEntityKind.url);
    collect(_amountRegex, DetectedEntityKind.amount);
    collect(_dateRegex, DetectedEntityKind.date);
    collect(_phoneRegex, DetectedEntityKind.phone, minDigits: 8);

    return out;
  }

  /// Cleans redundant whitespace, broken OCR line spacing, and zero-width
  /// artifacts while preserving paragraph structure.
  static String cleanOcrText(String raw) {
    final lines = raw
        .replaceAll('\u200B', '')
        .replaceAll('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n')
        .map((l) => l.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim())
        .toList(growable: false);

    return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}
