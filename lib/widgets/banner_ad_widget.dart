import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

/// 画面下部に表示するバナー広告ウィジェット。
/// ロード失敗時は高さ 0 になり UI に影響しない。
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  Future<void> _loadAd() async {
    await AdService.instance.initialize();
    final ad = AdService.instance.createBanner(
      onLoaded: (ad) {
        if (mounted) setState(() => _loaded = true);
      },
      onFailedToLoad: (ad, error) {
        // ignore: avoid_print
        print('[BannerAd] FAILED: $error');
        ad.dispose();
        if (mounted) setState(() => _loaded = false);
      },
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _ad == null) return const SizedBox.shrink();
    return SizedBox(
      width: _ad!.size.width.toDouble(),
      height: _ad!.size.height.toDouble(),
      child: AdWidget(ad: _ad!),
    );
  }
}
