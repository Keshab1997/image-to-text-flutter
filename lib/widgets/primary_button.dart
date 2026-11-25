import 'package:flutter/material.dart';

import '../constants/app_theme.dart';

/// Smart Bento Action Tile for Camera ("Scan Now") and Gallery ("Import Image")
/// matching the selected v2 UI design mockup.
class BentoActionTile extends StatelessWidget {
  const BentoActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1442) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE3DCF7);

    return Material(
      color: cardBg,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.last.withValues(alpha: 0.38),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1A103D),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color:
                            isDark ? Colors.white60 : const Color(0xFF6B628C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glowing pill button used for Crop, Extract Text, Copy, Share, and Clear.
class SmartPillButton extends StatelessWidget {
  const SmartPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.gradientColors,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.height = 48,
    this.elevation = 2,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final List<Color>? gradientColors;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final double height;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ?? Colors.white;
    final hasGradient = gradientColors != null && gradientColors!.length >= 2;

    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: hasGradient
            ? LinearGradient(
                colors: gradientColors!,
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              )
            : null,
        color: hasGradient ? null : (backgroundColor ?? AppTheme.royalViolet),
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1.4)
            : null,
        boxShadow: elevation > 0
            ? [
                BoxShadow(
                  color: (hasGradient
                          ? gradientColors!.last
                          : (backgroundColor ?? Colors.black))
                      .withValues(alpha: 0.32),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppTheme.pillRadius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: fg,
                    ),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 6),
                  Icon(trailingIcon, size: 18, color: fg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
