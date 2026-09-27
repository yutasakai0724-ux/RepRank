import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';
import 'user_preferences.dart';

/// iOS Live Activities（ロック画面・Dynamic Island）で
/// 休憩タイマー・ストップウォッチの進行をリアルタイム表示するためのラッパー。
/// 休憩タイマーは種目ごとに独立した Activity を複数同時に保持できる。
///
/// 前提: Xcode 側で Widget Extension・App Group・Push Notifications capability の
/// セットアップが完了していること（document/release/ios_live_activities.md 参照）。
/// 未セットアップの場合は何もしない（例外を投げずに無視する）。
class LiveActivityService {
  LiveActivityService._();
  static final LiveActivityService instance = LiveActivityService._();

  // Xcode で作成する App Group の ID と一致させること。
  static const _appGroupId = 'group.com.yutasakai.reprank';

  static const _stopwatchActivityId = 'stopwatch_activity';

  final _liveActivities = LiveActivities();
  bool _initialized = false;

  /// 休憩タイマーの Activity ID（種目キーごと）の生存管理。
  final Set<String> _activeRestActivityIds = {};
  bool _stopwatchActive = false;

  bool get _supported => Platform.isIOS;

  String _restActivityId(String key) => 'rest_timer_activity_$key';

  Future<void> initialize() async {
    if (!_supported || _initialized) return;
    try {
      await _liveActivities.init(appGroupId: _appGroupId);
      _initialized = true;
    } catch (e) {
      debugPrint('[LiveActivityService] init failed (未セットアップの可能性): $e');
    }
  }

  // ── 休憩タイマー（種目ごと） ──────────────────────────────

  Future<void> startRest(
      String key, String exerciseName, DateTime endTime, int durationSec) async {
    if (!_supported || !_initialized) return;
    if (!await UserPreferences.instance.getRestNotification()) return;
    final activityId = _restActivityId(key);
    try {
      final data = {
        'kind': 'rest',
        'exerciseName': exerciseName,
        'endTime': endTime.millisecondsSinceEpoch,
        'durationSec': durationSec,
      };
      if (_activeRestActivityIds.contains(activityId)) {
        await _liveActivities.updateActivity(activityId, data);
      } else {
        await _liveActivities.createActivity(activityId, data);
        _activeRestActivityIds.add(activityId);
      }
    } catch (e) {
      debugPrint('[LiveActivityService] startRest failed: $e');
    }
  }

  Future<void> endRest(String key) async {
    final activityId = _restActivityId(key);
    if (!_supported || !_initialized || !_activeRestActivityIds.contains(activityId)) {
      return;
    }
    try {
      await _liveActivities.endActivity(activityId);
    } catch (e) {
      debugPrint('[LiveActivityService] endRest failed: $e');
    } finally {
      _activeRestActivityIds.remove(activityId);
    }
  }

  // ── ストップウォッチ（ワークアウト全体で1つ） ──────────────

  Future<void> startStopwatch(DateTime startedAt) async {
    if (!_supported || !_initialized) return;
    if (!await UserPreferences.instance.getRestNotification()) return;
    try {
      final data = {
        'kind': 'stopwatch',
        'startTime': startedAt.millisecondsSinceEpoch,
      };
      if (_stopwatchActive) {
        await _liveActivities.updateActivity(_stopwatchActivityId, data);
      } else {
        await _liveActivities.createActivity(_stopwatchActivityId, data);
        _stopwatchActive = true;
      }
    } catch (e) {
      debugPrint('[LiveActivityService] startStopwatch failed: $e');
    }
  }

  Future<void> endStopwatch() async {
    if (!_supported || !_initialized || !_stopwatchActive) return;
    try {
      await _liveActivities.endActivity(_stopwatchActivityId);
    } catch (e) {
      debugPrint('[LiveActivityService] endStopwatch failed: $e');
    } finally {
      _stopwatchActive = false;
    }
  }
}
