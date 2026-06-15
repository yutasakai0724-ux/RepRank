import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Firebase 初期化と Crashlytics / Analytics 設定を一元管理する。
///
/// **重要**: 実機/シミュレーターで動かすには iOS の `Runner/GoogleService-Info.plist` が必要。
/// `flutterfire configure` で生成される。詳細は RELEASE.md 参照。
class FirebaseInit {
  static bool _isReady = false;
  static bool get isReady => _isReady;

  static FirebaseAnalytics? _analytics;

  /// Analytics インスタンス（Firebase 未設定時は null）
  static FirebaseAnalytics? get analytics => _analytics;

  /// アプリ起動時に呼ぶ。失敗してもアプリは継続動作する。
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp();
      _isReady = true;
      _setupCrashlytics();
      _setupAnalytics();
      debugPrint('[Firebase] initialized');
    } catch (e, st) {
      // GoogleService-Info.plist が無い等の理由で失敗 → ローカルのみで動作継続
      debugPrint('[Firebase] not configured, continuing without it: $e');
      debugPrint('$st');
      _isReady = false;
    }
  }

  /// Flutter / Dart の未処理エラーを Crashlytics に転送
  static void _setupCrashlytics() {
    if (kDebugMode) {
      // デバッグビルドでは Crashlytics 送信を無効化
      FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
      return;
    }
    FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

    // Flutter フレームワーク内の致命的エラー
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Dart ランタイムの非同期エラー
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  /// Analytics 初期化（デバッグビルドでは収集無効化）
  static void _setupAnalytics() {
    _analytics = FirebaseAnalytics.instance;
    if (kDebugMode) {
      // デバッグ時は送信しない
      _analytics!.setAnalyticsCollectionEnabled(false);
    } else {
      _analytics!.setAnalyticsCollectionEnabled(true);
    }
  }
}
