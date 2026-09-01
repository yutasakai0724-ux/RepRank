import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google AdMob 広告の管理サービス。
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ── 広告ユニット ID ────────────────────────────────────────────
  static const _testBannerUnitId   = 'ca-app-pub-3940256099942544/2934735716';
  static const _testRewardedUnitId = 'ca-app-pub-3940256099942544/1712485313';

  // Android 本番
  static const _androidBannerUnitId   = 'ca-app-pub-3054041824701944/9875798666';
  static const _androidRewardedUnitId = 'ca-app-pub-3054041824701944/8231544506';

  // iOS 本番
  static const _iosBannerUnitId   = 'ca-app-pub-3054041824701944/3779758632';
  static const _iosRewardedUnitId = 'ca-app-pub-3054041824701944/5092840309';

  static String get _bannerUnitId {
    if (kDebugMode && !Platform.isIOS) return _testBannerUnitId;
    return Platform.isIOS ? _iosBannerUnitId : _androidBannerUnitId;
  }

  static String get _rewardedUnitId {
    if (kDebugMode && !Platform.isIOS) return _testRewardedUnitId;
    return Platform.isIOS ? _iosRewardedUnitId : _androidRewardedUnitId;
  }

  bool _initialized = false;

  // ── 初期化 ────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    // ignore: avoid_print
    print('[AdService] initialized. bannerUnitId=$_bannerUnitId');
  }

  // ── バナー広告 ─────────────────────────────────────────────────

  /// バナー広告を作成して返す（呼び出し元で dispose すること）
  BannerAd createBanner({
    required void Function(Ad ad) onLoaded,
    required void Function(Ad ad, LoadAdError error) onFailedToLoad,
  }) {
    // ignore: avoid_print
    print('[AdService] createBanner unitId=$_bannerUnitId');
    return BannerAd(
      adUnitId: _bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          // ignore: avoid_print
          print('[AdService] banner loaded');
          onLoaded(ad);
        },
        onAdFailedToLoad: (ad, error) {
          // ignore: avoid_print
          print('[AdService] banner FAILED code=${error.code} msg=${error.message} domain=${error.domain}');
          onFailedToLoad(ad, error);
        },
      ),
    );
  }

  // ── リワード広告 ───────────────────────────────────────────────

  /// リワード広告をロードする
  Future<void> loadRewarded({
    required void Function(RewardedAd ad) onLoaded,
    required void Function(LoadAdError error) onFailed,
  }) async {
    if (!_initialized) return;
    if (_rewardedUnitId.isEmpty) return;
    await RewardedAd.load(
      adUnitId: _rewardedUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          // ignore: avoid_print
          print('[AdService] rewarded loaded');
          onLoaded(ad);
        },
        onAdFailedToLoad: (error) {
          // ignore: avoid_print
          print('[AdService] rewarded FAILED code=${error.code} msg=${error.message}');
          onFailed(error);
        },
      ),
    );
  }
}
