import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Google AdMob 広告の管理サービス。
///
/// 本番リリース前に AdMob Console で取得した実際のユニット ID に差し替える。
/// ⚠️ テスト用 ID は審査に出す前に必ず本番 ID へ変更すること。
class AdService {
  AdService._();
  static final AdService instance = AdService._();

  // ── 広告ユニット ID ────────────────────────────────────────────
  // TODO: AdMob Console の実際のユニット ID に差し替える
  static const _testBannerUnitId = 'ca-app-pub-3940256099942544/2934735716';
  static const _testRewardedUnitId = 'ca-app-pub-3940256099942544/1712485313';

  // 本番用（AdMob Console で取得後に入力）
  static const _prodBannerUnitId =
      'ca-app-pub-3054041824701944/6551672883'; // TODO: 入力
  static const _prodRewardedUnitId =
      'ca-app-pub-3054041824701944/3925509547'; // TODO: 入力

  static String get _bannerUnitId =>
      kDebugMode ? _testBannerUnitId : _prodBannerUnitId;
  static String get _rewardedUnitId =>
      kDebugMode ? _testRewardedUnitId : _prodRewardedUnitId;

  bool _initialized = false;

  // ── 初期化 ────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (!Platform.isIOS) return;
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
    debugPrint('[AdService] initialized');
  }

  // ── バナー広告 ─────────────────────────────────────────────────

  /// バナー広告を作成して返す（呼び出し元で dispose すること）
  BannerAd createBanner({
    required void Function(Ad, LoadAdError) onFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: _bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => debugPrint('[AdService] banner loaded'),
        onAdFailedToLoad: onFailedToLoad,
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
          debugPrint('[AdService] rewarded loaded');
          onLoaded(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint('[AdService] rewarded failed: $error');
          onFailed(error);
        },
      ),
    );
  }
}
