import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_localizations.dart';
import '../constants/app_strings.dart';
import '../constants/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/banner_ad_widget.dart';

typedef ExternalUriLauncher = Future<bool> Function(Uri uri);

/// Screen 2 — Settings Screen of SnapText OCR.
///
/// Implements the exact sections, dialogs, theme persistence, 21-language
/// selector, live localization, and bottom-only SafeArea insets specified in IMPLEMENTATION_SPEC.md §4.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.currentThemeMode,
    required this.currentLocale,
    required this.onThemeModeChanged,
    required this.onLocaleChanged,
    this.uriLauncher,
  });

  final ThemeMode currentThemeMode;
  final Locale currentLocale;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<Locale> onLocaleChanged;
  final ExternalUriLauncher? uriLauncher;

  static Future<bool> _defaultLaunchUri(Uri uri) async {
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final uri = Uri.parse(AppStrings.privacyPolicyUrl);
    final launcher = uriLauncher ?? _defaultLaunchUri;
    try {
      final launched = await launcher(uri);
      if (!context.mounted) return;
      if (!launched) {
        AppToast.showLong(context, AppStrings.toastPrivacyPolicyError);
      }
    } catch (_) {
      if (!context.mounted) return;
      AppToast.showLong(context, AppStrings.toastPrivacyPolicyError);
    }
  }

  Future<void> _openContactEmail(BuildContext context) async {
    final query =
        'subject=${Uri.encodeComponent(AppStrings.contactEmailSubject)}'
        '&body=${Uri.encodeComponent(AppStrings.contactEmailBody)}';
    final uri = Uri.parse('mailto:${AppStrings.supportEmail}?$query');
    final launcher = uriLauncher ?? _defaultLaunchUri;
    try {
      final launched = await launcher(uri);
      if (!context.mounted) return;
      if (!launched) {
        AppToast.showLong(context, AppStrings.toastNoEmailApp);
      }
    } catch (_) {
      if (!context.mounted) return;
      AppToast.showLong(context, AppStrings.toastNoEmailApp);
    }
  }

  Future<void> _showLanguageDialog(BuildContext context) async {
    final currentCode = currentLocale.languageCode;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            l10n.appLanguage,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          contentPadding: const EdgeInsets.only(top: 12),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              key: const Key('language_dialog_list'),
              itemCount: AppStrings.supportedLanguages.length,
              itemBuilder: (context, index) {
                final option = AppStrings.supportedLanguages[index];
                final isSelected = option.code == currentCode;
                return ListTile(
                  key: Key('lang_option_${option.code}'),
                  leading: Icon(
                    isSelected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: isSelected
                        ? AppTheme.accent
                        : Theme.of(context).hintColor,
                  ),
                  title: Text(
                    option.nativeName,
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  subtitle: Text(
                    option.code,
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: () {
                    onLocaleChanged(Locale(option.code));
                    Navigator.of(dialogContext).pop();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              key: const Key('language_cancel_button'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showContentPolicyDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(
            l10n.contentPolicy,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const SingleChildScrollView(
            child: Text(
              AppStrings.contentPolicyMessage,
              style: TextStyle(height: 1.45),
            ),
          ),
          actions: [
            TextButton(
              key: const Key('content_policy_ok_button'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  'assets/images/mascot_avatar.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.smart_toy_rounded),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  AppStrings.aboutDialogTitle,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              AppStrings.aboutDialogMessage(),
              style: const TextStyle(height: 1.45),
            ),
          ),
          actions: [
            TextButton(
              key: const Key('about_ok_button'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.ok),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final activeLanguage =
        AppStrings.languageForCode(currentLocale.languageCode);

    return Scaffold(
      // Spec §4: Apply bottom-only safe-area inset padding
      body: SafeArea(
        top: false,
        left: false,
        right: false,
        bottom: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSettingsHeader(context, isDark, l10n),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Group 1: Appearance
                    _buildSectionCard(
                      isDark: isDark,
                      title: l10n.appearance,
                      subtitle: l10n.appearanceDescription,
                      icon: Icons.palette_rounded,
                      children: [
                        _buildSettingsButton(
                          key: const Key('light_mode_button'),
                          label: l10n.lightMode,
                          icon: Icons.light_mode_rounded,
                          isSelected: currentThemeMode == ThemeMode.light,
                          isDark: isDark,
                          onPressed: () {
                            onThemeModeChanged(ThemeMode.light);
                            AppToast.showShort(
                              context,
                              AppStrings.toastLightModeEnabled,
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        _buildSettingsButton(
                          key: const Key('dark_mode_button'),
                          label: l10n.darkMode,
                          icon: Icons.dark_mode_rounded,
                          isSelected: currentThemeMode == ThemeMode.dark,
                          isDark: isDark,
                          onPressed: () {
                            onThemeModeChanged(ThemeMode.dark);
                            AppToast.showShort(
                              context,
                              AppStrings.toastDarkModeEnabled,
                            );
                          },
                        ),
                        const SizedBox(height: 6),
                        _buildSettingsButton(
                          key: const Key('system_mode_button'),
                          label: l10n.systemDefault,
                          icon: Icons.brightness_auto_rounded,
                          isSelected: currentThemeMode == ThemeMode.system,
                          isDark: isDark,
                          onPressed: () {
                            onThemeModeChanged(ThemeMode.system);
                            AppToast.showShort(
                              context,
                              AppStrings.toastSystemModeEnabled,
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Group 2: Language
                    _buildSectionCard(
                      isDark: isDark,
                      title: l10n.language,
                      subtitle: l10n.languageDescription,
                      icon: Icons.translate_rounded,
                      children: [
                        _buildSettingsButton(
                          key: const Key('language_button'),
                          label: l10n.appLanguage,
                          trailingBadge: activeLanguage.nativeName,
                          icon: Icons.language_rounded,
                          isDark: isDark,
                          onPressed: () => _showLanguageDialog(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Group 3: Policies
                    _buildSectionCard(
                      isDark: isDark,
                      title: l10n.policies,
                      subtitle: l10n.policiesDescription,
                      icon: Icons.verified_user_rounded,
                      children: [
                        _buildSettingsButton(
                          key: const Key('privacy_policy_button'),
                          label: l10n.privacyPolicy,
                          icon: Icons.privacy_tip_rounded,
                          isDark: isDark,
                          onPressed: () => _openPrivacyPolicy(context),
                        ),
                        const SizedBox(height: 6),
                        _buildSettingsButton(
                          key: const Key('content_policy_button'),
                          label: l10n.contentPolicy,
                          icon: Icons.gavel_rounded,
                          isDark: isDark,
                          onPressed: () => _showContentPolicyDialog(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Group 4: Support
                    _buildSectionCard(
                      isDark: isDark,
                      title: l10n.support,
                      subtitle: l10n.supportDescription,
                      icon: Icons.support_agent_rounded,
                      children: [
                        _buildSettingsButton(
                          key: const Key('contact_us_button'),
                          label: l10n.contactUs,
                          icon: Icons.mail_outline_rounded,
                          isDark: isDark,
                          onPressed: () => _openContactEmail(context),
                        ),
                        const SizedBox(height: 6),
                        _buildSettingsButton(
                          key: const Key('about_app_button'),
                          label: l10n.aboutApp,
                          icon: Icons.info_outline_rounded,
                          isDark: isDark,
                          onPressed: () => _showAboutDialog(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Back button (closes Settings)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        key: const Key('back_button'),
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: Text(
                          l10n.back,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppTheme.buttonRadius),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                AppStrings.footerCopyright,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted(isDark),
                ),
              ),
            ),
            const BannerAdSlot(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsHeader(
    BuildContext context,
    bool isDark,
    AppLocalizations l10n,
  ) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, 14),
      decoration: BoxDecoration(
        color: AppTheme.bg(isDark),
        border: Border(bottom: BorderSide(color: AppTheme.border(isDark))),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(shape: BoxShape.circle),
            child: ClipOval(
              child: Image.asset(
                'assets/images/mascot_avatar.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.settingsTitle,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.settingsSubtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface(isDark),
        borderRadius: BorderRadius.circular(AppTheme.imageCardRadius),
        border: Border.all(color: AppTheme.border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color:
                      AppTheme.accentText(isDark),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.text(isDark),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13.5,
                        color:
                            AppTheme.textMuted(isDark),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingsButton({
    required Key key,
    required String label,
    required IconData icon,
    required bool isDark,
    required VoidCallback onPressed,
    bool isSelected = false,
    String? trailingBadge,
  }) {
    // Selected = pale accent wash with an accent outline. A solid accent block
    // here shouted louder than the actual screen content.
    final bgColor = isSelected ? AppTheme.accentSoft : AppTheme.surface(isDark);
    final fgColor =
        isSelected ? AppTheme.accentText(isDark) : AppTheme.text(isDark);

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        key: key,
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          side: BorderSide(
            color: isSelected ? AppTheme.accent : AppTheme.border(isDark),
            width: isSelected ? 1.5 : 1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: fgColor),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: fgColor,
                ),
              ),
            ),
            if (trailingBadge != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  trailingBadge,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color:
                        AppTheme.accentText(isDark),
                  ),
                ),
              )
            else if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: AppTheme.accentText(isDark),
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: fgColor.withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }
}
