import 'package:flutter/foundation.dart';
import 'firebase_init.dart';

/// Firebase Analytics イベント送信を一元管理するサービス。
///
/// Firebase が未設定の場合はすべて無視する（例外を投げない）。
/// イベント名・パラメータは Firebase Console / GA4 で確認できる。
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  // ── 画面ビュー ──────────────────────────────────────────────────

  /// 画面表示を記録する
  Future<void> logScreenView(String screenName) async {
    try {
      await FirebaseInit.analytics?.logScreenView(screenName: screenName);
      debugPrint('[Analytics] screen_view: $screenName');
    } catch (e) {
      debugPrint('[Analytics] logScreenView failed: $e');
    }
  }

  // ── ワークアウト ─────────────────────────────────────────────────

  /// 新しいワークアウトセッション開始
  Future<void> logWorkoutStarted() async {
    try {
      await FirebaseInit.analytics?.logEvent(name: 'workout_started');
      debugPrint('[Analytics] workout_started');
    } catch (e) {
      debugPrint('[Analytics] logWorkoutStarted failed: $e');
    }
  }

  /// ワークアウトセッション保存完了
  Future<void> logWorkoutCompleted({
    required int exerciseCount,
    required double totalVolume,
  }) async {
    try {
      await FirebaseInit.analytics?.logEvent(
        name: 'workout_completed',
        parameters: {
          'exercise_count': exerciseCount,
          'total_volume_kg': totalVolume.round(),
        },
      );
      debugPrint('[Analytics] workout_completed exercises=$exerciseCount volume=${totalVolume.round()}kg');
    } catch (e) {
      debugPrint('[Analytics] logWorkoutCompleted failed: $e');
    }
  }

  /// 種目の記録保存
  Future<void> logExerciseRecorded({
    required String exerciseName,
    required int setCount,
  }) async {
    try {
      await FirebaseInit.analytics?.logEvent(
        name: 'exercise_recorded',
        parameters: {
          'exercise_name': exerciseName,
          'set_count': setCount,
        },
      );
      debugPrint('[Analytics] exercise_recorded: $exerciseName ($setCount sets)');
    } catch (e) {
      debugPrint('[Analytics] logExerciseRecorded failed: $e');
    }
  }

  // ── 機能使用 ──────────────────────────────────────────────────────

  /// ストップウォッチ操作（start / stop / reset）
  Future<void> logStopwatchAction(String action) async {
    try {
      await FirebaseInit.analytics?.logEvent(
        name: 'stopwatch_action',
        parameters: {'action': action},
      );
      debugPrint('[Analytics] stopwatch_action: $action');
    } catch (e) {
      debugPrint('[Analytics] logStopwatchAction failed: $e');
    }
  }

  /// 匿名統計共有トグル変更
  Future<void> logShareStatsToggled(bool enabled) async {
    try {
      await FirebaseInit.analytics?.logEvent(
        name: 'share_stats_toggled',
        parameters: {'enabled': enabled ? 1 : 0},
      );
      debugPrint('[Analytics] share_stats_toggled: $enabled');
    } catch (e) {
      debugPrint('[Analytics] logShareStatsToggled failed: $e');
    }
  }
}
