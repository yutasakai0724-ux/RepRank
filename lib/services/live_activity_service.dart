import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:live_activities/live_activities.dart';

/// iOS Live Activities（ロック画面・Dynamic Island）で
/// 休憩タイマー・ストップウォッチの進行をリアルタイム表示するためのラッパー。
///
/// 前提: Xcode 側で Widget Extension・App Group・Push Notifications capability の
/// セットアップが完了していること（document/release/ios_live_activities.md 参照）。
/// 未セットアップの場合は何もしない（例外を投げずに無視する）。
class LiveActivityService {
  LiveActivityService._();
  static final LiveActivityService instance = LiveActivityService._();

  // Xcode で作成する App Group の ID と一致させること。
  static const _appGroupId = 'group.com.yutasakai.reprank';

  static const _restActivityId = 'rest_timer_activity';
  static const _stopwatchActivityId = 'stopwatch_activity';

  final _liveActivities = LiveActivities();
  bool _initialized = false;
  bool _restActive = false;
  bool _stopwatchActive = false;

  bool get _supported => Platform.isIOS;

  Future<void> initialize() async {
    if (!_supported || _initialized) return;
    try {
      await _liveActivities.init(appGroupId: _appGroupId);
      _initialized = true;
    } catch (e) {
      debugPrint('[LiveActivityService] init failed (未セットアップの可能性): $e');
    }
  }

  // ── 休憩タイマー ──────────────────────────────────────

  Future<void> startRest(DateTime endTime, int durationSec) async {
    if (!_supported || !_initialized) return;
    try {
      final data = {
        'kind': 'rest',
        'endTime': endTime.millisecondsSinceEpoch,
        'durationSec': durationSec,
      };
      if (_restActive) {
        await _liveActivities.updateActivity(_restActivityId, data);
      } else {
        await _liveActivities.createActivity(_restActivityId, data);
        _restActive = true;
      }
    } catch (e) {
      debugPrint('[LiveActivityService] startRest failed: $e');
    }
  }

  Future<void> endRest() async {
    if (!_supported || !_initialized || !_restActive) return;
    try {
      await _liveActivities.endActivity(_restActivityId);
    } catch (e) {
      debugPrint('[LiveActivityService] endRest failed: $e');
    } finally {
      _restActive = false;
    }
  }

  // ── ストップウォッチ ──────────────────────────────────

  Future<void> startStopwatch(DateTime startedAt) async {
    if (!_supported || !_initialized) return;
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
