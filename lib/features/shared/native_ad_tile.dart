import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/theme/app_colors.dart';
import '../../services/ads_service.dart';

/// M32 — Shared Native AdMob tile.
///
/// Sebelumnya widget ini didefinisikan lokal di `notifications_screen.dart`.
/// M32 mengangkatnya jadi widget bersama supaya tab **History** juga bisa
/// menyisipkan native ad tanpa duplikasi kode.
class NativeAdTile extends StatefulWidget {
  const NativeAdTile({super.key});

  @override
  State<NativeAdTile> createState() => _NativeAdTileState();
}

class _NativeAdTileState extends State<NativeAdTile> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _ad = NativeAd(
      adUnitId: AdsService.nativeNotifUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: AppColors.surfaceElevated,
        cornerRadius: 12,
      ),
    )..load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minHeight: 320, maxHeight: 400),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: AdWidget(ad: _ad!),
    );
  }
}
