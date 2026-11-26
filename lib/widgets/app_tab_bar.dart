import 'package:flutter/material.dart';

import '../constants/app_theme.dart';

/// The four destinations. Order is the order they appear in the bar.
enum AppTab { scan, text, history, settings }

/// Floating, detached bottom bar: dark glass slab with the active tab marked by
/// an accent pill behind its icon. Deliberately one row, four labels, no
/// overflow menu — every destination is one tap from anywhere.
class AppTabBar extends StatelessWidget {
  const AppTabBar({
    super.key,
    required this.current,
    required this.onSelect,
  });

  final AppTab current;
  final ValueChanged<AppTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1B1F) : Colors.white,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isDark ? const Color(0xFF35353B) : const Color(0xFFE4E4E7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            for (final tab in AppTab.values)
              Expanded(
                child: _TabButton(
                  tab: tab,
                  selected: tab == current,
                  accent: accent,
                  isDark: isDark,
                  onTap: () => onSelect(tab),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  final AppTab tab;
  final bool selected;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  static const _labels = <AppTab, String>{
    AppTab.scan: 'Scan',
    AppTab.text: 'Text',
    AppTab.history: 'History',
    AppTab.settings: 'Settings',
  };

  static const _icons = <AppTab, IconData>{
    AppTab.scan: Icons.camera_alt_outlined,
    AppTab.text: Icons.notes_rounded,
    AppTab.history: Icons.history_rounded,
    AppTab.settings: Icons.settings_outlined,
  };

  static const _activeIcons = <AppTab, IconData>{
    AppTab.scan: Icons.camera_alt_rounded,
    AppTab.text: Icons.notes_rounded,
    AppTab.history: Icons.history_rounded,
    AppTab.settings: Icons.settings_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final muted = isDark ? const Color(0xFF8B8B94) : const Color(0xFF71717A);
    final color = selected ? accent : muted;

    return Semantics(
      button: true,
      selected: selected,
      label: _labels[tab],
      child: InkWell(
        key: Key('tab_${tab.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                selected ? _activeIcons[tab]! : _icons[tab]!,
                size: 21,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _labels[tab]!,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin accent rule + label used as a section eyebrow.
class SectionEyebrow extends StatelessWidget {
  const SectionEyebrow({super.key, required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppTheme.textMuted(isDark),
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}
