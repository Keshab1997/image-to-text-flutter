import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../constants/app_strings.dart';

/// Bottom Banner Ad widget used on both Home and Settings screens (Spec §6.1).
///
/// Manages BannerAd creation, loading, lifecycle pause/resume, and disposal.
/// Safely renders a sleek test-ad bar in widget tests or when native ads
/// have not yet filled.
class BannerAdSlot extends StatefulWidget {
  const BannerAdSlot({
    super.key,
    this.enablePlatformAds = true,
  });

  final bool enablePlatformAds;

  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot>
    with WidgetsBindingObserver {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  bool get _canLoadNativeAd {
    if (!widget.enablePlatformAds || kIsWeb) {
      return false;
    }
    // Skip platform channel ad creation inside flutter_test environment
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_canLoadNativeAd) {
      _loadBannerAd();
    }
  }

  void _loadBannerAd() {
    // TODO(release): Replace AppStrings.admobTestBannerUnitId with Keshab Studios' production banner unit ID before release.
    final ad = BannerAd(
      adUnitId: AppStrings.admobTestBannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          if (!mounted) {
            return;
          }
          setState(() {
            _bannerAd = null;
            _isLoaded = false;
          });
        },
      ),
    );
    _bannerAd = ad;
    ad.load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_canLoadNativeAd) {
      return;
    }
    if (state == AppLifecycleState.resumed && _bannerAd == null) {
      _loadBannerAd();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bannerAd?.dispose();
    _bannerAd = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoaded && _bannerAd != null) {
      return Container(
        key: const Key('banner_ad_container'),
        width: double.infinity,
        height: _bannerAd!.size.height.toDouble(),
        alignment: Alignment.center,
        color: isDark ? const Color(0xFF120B2E) : const Color(0xFFEDE7F6),
        child: SizedBox(
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd!),
        ),
      );
    }

    return Container(
      key: const Key('banner_ad_container'),
      width: double.infinity,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF140C32) : const Color(0xFFEDE7F6),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFD1C4E9),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF5E35B1).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'AD',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: isDark ? const Color(0xFFB388FF) : const Color(0xFF5E35B1),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'SnapText OCR • Google Test Banner',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
