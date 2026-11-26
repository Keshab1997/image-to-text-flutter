import 'package:flutter/material.dart';

import '../constants/app_localizations.dart';
import '../constants/app_theme.dart';
import '../services/history_service.dart';

/// Bottom sheet displaying saved local OCR scans with live keyword search,
/// one-tap restore, copy, and delete.
class ScanHistorySheet extends StatefulWidget {
  const ScanHistorySheet({
    super.key,
    required this.historyService,
    required this.onSelectText,
    required this.onCopyText,
  });

  final HistoryService historyService;
  final ValueChanged<String> onSelectText;
  final ValueChanged<String> onCopyText;

  @override
  State<ScanHistorySheet> createState() => _ScanHistorySheetState();
}

class _ScanHistorySheetState extends State<ScanHistorySheet> {
  final TextEditingController _searchController = TextEditingController();
  List<ScanHistoryItem> _items = const <ScanHistoryItem>[];
  String _searchQuery = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await widget.historyService.loadHistory();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _deleteItem(String id) async {
    final updated = await widget.historyService.deleteEntry(id);
    if (!mounted) return;
    setState(() {
      _items = updated;
    });
  }

  Future<void> _clearAll() async {
    await widget.historyService.clearAll();
    if (!mounted) return;
    setState(() {
      _items = const <ScanHistoryItem>[];
    });
  }

  List<ScanHistoryItem> get _filteredItems {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items
        .where((item) => item.text.toLowerCase().contains(q))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final filtered = _filteredItems;

    return Container(
      key: const Key('scan_history_sheet'),
      height: MediaQuery.sizeOf(context).height * 0.76,
      decoration: BoxDecoration(
        color: AppTheme.bg(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.black26,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color:
                        AppTheme.accentText(isDark),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.scanHistory,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.text(isDark),
                    ),
                  ),
                ),
                if (_items.isNotEmpty)
                  TextButton.icon(
                    key: const Key('history_clear_all_button'),
                    onPressed: _clearAll,
                    icon: const Icon(
                      Icons.delete_sweep_rounded,
                      size: 18,
                      color: AppTheme.danger,
                    ),
                    label: Text(
                      l10n.clear,
                      style: const TextStyle(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                IconButton(
                  key: const Key('history_close_button'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: TextField(
                key: const Key('history_search_field'),
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search saved scans...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surface(isDark),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? _buildEmptyState(isDark, l10n)
                    : ListView.separated(
                        key: const Key('history_list_view'),
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          return _buildHistoryCard(
                            context,
                            item: item,
                            index: index,
                            isDark: isDark,
                            l10n: l10n,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/images/mascot_avatar.png',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.history_toggle_off_rounded,
                  size: 56,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.noHistoryYet,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppTheme.text(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context, {
    required ScanHistoryItem item,
    required int index,
    required bool isDark,
    required AppLocalizations l10n,
  }) {
    return Container(
      key: Key('history_item_$index'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface(isDark),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.border(isDark),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.text.length} chars • score ${item.score}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color:
                        AppTheme.accentText(isDark),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                key: Key('history_delete_$index'),
                visualDensity: VisualDensity.compact,
                onPressed: () => _deleteItem(item.id),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 19,
                  color: AppTheme.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: AppTheme.text(isDark),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  key: Key('history_use_$index'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onSelectText(item.text);
                  },
                  icon: const Icon(Icons.edit_note_rounded, size: 18),
                  label: Text(l10n.useText),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: Key('history_copy_$index'),
                onPressed: () => widget.onCopyText(item.text),
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: Text(l10n.copy),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
