import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/app_strings.dart';
import '../constants/app_theme.dart';
import '../widgets/app_toast.dart';
import '../widgets/banner_ad_widget.dart';

typedef ExternalUriLauncher = Future<bool> Function(Uri uri);

/// Screen 2 — Settings Screen of SnapText OCR.
///
/// Implements the exact sections, dialogs, theme persistence, 21-language
/// selector, and bottom-only SafeArea insets specified in IMPLEMENTATION_SPEC.md §4.
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
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            AppStrings.appLanguage,
            style: TextStyle(fontWeight: FontWeight.w800),
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
                return RadioListTile<String>(
                  key: Key('lang_option_${option.code}'),
                  value: option.code,
                  groupValue: currentCode,
                  activeColor: AppTheme.royalViolet,
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
                  onChanged: (selectedCode) {
                    if (selectedCode != null) {
                      onLocaleChanged(Locale(selectedCode));
                    }
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
              child: const Text(AppStrings.cancel),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showContentPolicyDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            AppStrings.contentPolicy,
            style: TextStyle(fontWeight: FontWeight.w800),
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
              child: const Text(AppStrings.ok),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAboutDialog(BuildContext context) async {
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
              child: const Text(AppStrings.ok),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            _buildSettingsHeader(context, isDark),
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
                      title: AppStrings.appearance,
                      subtitle: AppStrings.appearanceDescription,
                      icon: Icons.palette_rounded,
                      children: [
                        _buildSettingsButton(
                          key: const Key('light_mode_button'),
                          label: AppStrings.lightMode,
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
                          label: AppStrings.darkMode,
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
                          label: AppStrings.systemDefault,
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
                      title: AppStrings.language,
                      subtitle: AppStrings.languageDescription,
                      icon: Icons.translate_rounded,
                      children: [
                        _buildSettingsButton(
                          key: const Key('language_button'),
                          label: AppStrings.appLanguage,
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
                      title: AppStrings.policies,
                      subtitle: AppStrings.policiesDescription,
                      icon: Icons.verified_user_rounded,
                      children: [
                        _buildSettingsButton(
                          key: const Key('privacy_policy_button'),
                          label: AppStrings.privacyPolicy,
                          icon: Icons.privacy_tip_rounded,
                          isDark: isDark,
                          onPressed: () => _openPrivacyPolicy(context),
                        ),
                        const SizedBox(height: 6),
                        _buildSettingsButton(
                          key: const Key('content_policy_button'),
                          label: AppStrings.contentPolicy,
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
                      title: AppStrings.support,
                      subtitle: AppStrings.supportDescription,
                      icon: Icons.support_agent_rounded,
                      children: [
                        _buildSettingsButton(
                          key: const Key('contact_us_button'),
                          label: AppStrings.contactUs,
                          icon: Icons.mail_outline_rounded,
                          isDark: isDark,
                          onPressed: () => _openContactEmail(context),
                        ),
                        const SizedBox(height: 6),
                        _buildSettingsButton(
                          key: const Key('about_app_button'),
                          label: AppStrings.aboutApp,
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
                        label: const Text(
                          AppStrings.back,
                          style: TextStyle(
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
                  color: isDark ? Colors.white70 : const Color(0xFF42366E),
                ),
              ),
            ),
            const BannerAdSlot(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsHeader(BuildContext context, bool isDark) {
    final topPad = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.fromLTRB(20, topPad + 14, 20, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF28175E), Color(0xFF170D3B)]
              : const [Color(0xFF512DA8), Color(0xFF673AB7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF80D8FF),
                width: 2,
              ),
            ),
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
                const Text(
                  AppStrings.settingsTitle,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppStrings.settingsSubtitle,
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
        color: isDark ? const Color(0xFF1B123E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE3DCF7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.royalViolet.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isDark
                      ? const Color(0xFFB388FF)
                      : AppTheme.royalViolet,
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
                        color: isDark ? Colors.white : const Color(0xFF1A103D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13.5,
                        color:
                            isDark ? Colors.white60 : const Color(0xFF6B628C),
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
    final bgColor = isSelected
        ? AppTheme.royalViolet
        : (isDark ? const Color(0xFF261A54) : const Color(0xFFF3EFFB));
    final fgColor = isSelected
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF22164C));

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        key: key,
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: isSelected ? 2 : 0,
          backgroundColor: bgColor,
          foregroundColor: fgColor,
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
                  color: AppTheme.royalViolet.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  trailingBadge,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? const Color(0xFFB388FF)
                        : AppTheme.royalViolet,
                  ),
                ),
              )
            else if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: Colors.white,
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
