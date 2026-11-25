import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Represents a single saved OCR extraction in local scan history.
class ScanHistoryItem {
  const ScanHistoryItem({
    required this.id,
    required this.text,
    required this.createdAtIso,
    required this.source,
    required this.score,
  });

  factory ScanHistoryItem.fromJson(Map<String, dynamic> json) {
    return ScanHistoryItem(
      id: (json['id'] as String?) ?? '',
      text: (json['text'] as String?) ?? '',
      createdAtIso: (json['createdAtIso'] as String?) ?? '',
      source: (json['source'] as String?) ?? 'gallery',
      score: (json['score'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String text;
  final String createdAtIso;
  final String source;
  final int score;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'text': text,
        'createdAtIso': createdAtIso,
        'source': source,
        'score': score,
      };
}

/// Persists recent OCR scans locally using [SharedPreferences].
class HistoryService {
  HistoryService([this._prefs]);

  SharedPreferences? _prefs;

  static const String storageKey = 'snaptext_scan_history_v1';
  static const int maxEntries = 50;

  Future<SharedPreferences> _instance() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  Future<List<ScanHistoryItem>> loadHistory() async {
    final prefs = await _instance();
    final rawList = prefs.getStringList(storageKey) ?? const <String>[];
    final items = <ScanHistoryItem>[];
    for (final raw in rawList) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        final item = ScanHistoryItem.fromJson(decoded);
        if (item.text.trim().isNotEmpty) {
          items.add(item);
        }
      } catch (_) {}
    }
    return items;
  }

  Future<List<ScanHistoryItem>> addEntry({
    required String text,
    required String source,
    required int score,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return loadHistory();
    }
    final existing = await loadHistory();
    final now = DateTime.now().toUtc();
    final newItem = ScanHistoryItem(
      id: '${now.microsecondsSinceEpoch}',
      text: trimmed,
      createdAtIso: now.toIso8601String(),
      source: source,
      score: score,
    );

    final updated = <ScanHistoryItem>[
      newItem,
      ...existing.where((item) => item.text != trimmed),
    ].take(maxEntries).toList(growable: false);

    await _saveList(updated);
    return updated;
  }

  Future<List<ScanHistoryItem>> deleteEntry(String id) async {
    final existing = await loadHistory();
    final updated =
        existing.where((item) => item.id != id).toList(growable: false);
    await _saveList(updated);
    return updated;
  }

  Future<void> clearAll() async {
    final prefs = await _instance();
    await prefs.remove(storageKey);
  }

  Future<void> _saveList(List<ScanHistoryItem> items) async {
    final prefs = await _instance();
    final encoded =
        items.map((item) => jsonEncode(item.toJson())).toList(growable: false);
    await prefs.setStringList(storageKey, encoded);
  }
}
