import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/workout.dart';
import 'live_activity_service.dart';
import 'notification_service.dart';

enum RestState { idle, running, paused, finished }

/// 種目ごとに独立した休憩タイマー1件分の状態。
class RestTimerEntry {
  RestTimerEntry({
    required this.key,
    required this.exercise,
    required this.sessionId,
  });

  /// タイマーを一意に識別するキー（現状は種目名）。
  final String key;

  /// 遷移先の記録画面を復元するための種目情報。
  Exercise exercise;

  /// 遷移先の記録画面を復元するためのセッションID。
  String? sessionId;

  RestState state = RestState.idle;
  int durationSec = 60;
  int remainingSec = 60;
  DateTime? startedAt;
  int pausedRemaining = 0;
  Timer? ticker;
}

/// 休憩タイマーのグローバルシングルトン。種目（キー）ごとに独立したタイマーを複数同時に保持する。
/// DateTime ベースで残り時間を計算するため、バックグラウンド後も正確に動作する。
/// 画面遷移してもタイマーはリセットされない。
class RestTimerService extends ChangeNotifier {
  RestTimerService._();
  static final RestTimerService instance = RestTimerService._();

  final Map<String, RestTimerEntry> _entries = {};

  /// 毎秒の残り時間更新専用の通知。状態変化（開始・停止など）は notifyListeners()。
  /// 秒ごとに画面全体を再構築しないよう、数字表示側は tick だけを購読する。
  final ValueNotifier<int> tick = ValueNotifier<int>(0);

  /// 種目名からタイマーキーを生成する。
  static String keyFor(String exerciseName) => exerciseName;

  /// 現在アクティブ（idle以外）なタイマー一覧。開始が早い順。
  List<RestTimerEntry> get activeEntries =>
      _entries.values.where((e) => e.state != RestState.idle).toList();

  RestTimerEntry? entryFor(String key) => _entries[key];

  // ── オーバーレイ抑制 ──────────────────────────────────
  // 該当種目の記録画面自体にタイマーUIが表示されている間は、
  // その種目分だけ全画面共通オーバーレイとの二重表示を避ける。
  final Set<String> _suppressedKeys = {};
  bool isSuppressed(String key) => _suppressedKeys.contains(key);

  void suppressOverlay(String key) {
    _suppressedKeys.add(key);
    notifyListeners();
  }

  void unsuppressOverlay(String key) {
    _suppressedKeys.remove(key);
    notifyListeners();
  }

  RestTimerEntry _entryFor(Exercise exercise, String? sessionId) {
    final key = keyFor(exercise.name);
    final existing = _entries[key];
    if (existing != null) {
      // 最新の種目・セッション情報に更新（遷移先の復元に使うため）
      existing.exercise = exercise;
      existing.sessionId = sessionId;
      return existing;
    }
    final entry = RestTimerEntry(key: key, exercise: exercise, sessionId: sessionId);
    _entries[key] = entry;
    return entry;
  }

  void setDuration(Exercise exercise, String? sessionId, int sec) {
    final entry = _entryFor(exercise, sessionId);
    entry.durationSec = sec;
    if (entry.state == RestState.idle) {
      entry.remainingSec = sec;
      notifyListeners();
    }
  }

  void start(Exercise exercise, String? sessionId) {
    final entry = _entryFor(exercise, sessionId);
    entry.ticker?.cancel();
    entry.startedAt = DateTime.now();
    entry.remainingSec = entry.durationSec;
    entry.state = RestState.running;
    entry.ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick(entry));
    final endTime = entry.startedAt!.add(Duration(seconds: entry.durationSec));
    NotificationService.instance
        .scheduleRestEnd(entry.key, exercise.name, entry.durationSec);
    NotificationService.instance
        .showRestOngoing(entry.key, exercise.name, endTime);
    LiveActivityService.instance
        .startRest(entry.key, exercise.name, endTime, entry.durationSec);
    notifyListeners();
  }

  void pause(String key) {
    final entry = _entries[key];
    if (entry == null || entry.state != RestState.running) return;
    entry.ticker?.cancel();
    entry.ticker = null;
    entry.pausedRemaining = entry.remainingSec;
    entry.state = RestState.paused;
    NotificationService.instance.cancelRestEnd(key);
    NotificationService.instance.cancelRestOngoing(key);
    LiveActivityService.instance.endRest(key);
    notifyListeners();
  }

  void resume(String key) {
    final entry = _entries[key];
    if (entry == null || entry.state != RestState.paused) return;
    entry.startedAt = DateTime.now().subtract(
      Duration(seconds: entry.durationSec - entry.pausedRemaining),
    );
    entry.state = RestState.running;
    entry.ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick(entry));
    final endTime = DateTime.now().add(Duration(seconds: entry.pausedRemaining));
    NotificationService.instance
        .scheduleRestEnd(key, entry.exercise.name, entry.pausedRemaining);
    NotificationService.instance
        .showRestOngoing(key, entry.exercise.name, endTime);
    LiveActivityService.instance
        .startRest(key, entry.exercise.name, endTime, entry.pausedRemaining);
    notifyListeners();
  }

  void stop(String key) {
    final entry = _entries[key];
    if (entry == null) return;
    entry.ticker?.cancel();
    entry.ticker = null;
    entry.state = RestState.idle;
    entry.remainingSec = entry.durationSec;
    entry.startedAt = null;
    NotificationService.instance.cancelRestEnd(key);
    NotificationService.instance.cancelRestOngoing(key);
    LiveActivityService.instance.endRest(key);
    notifyListeners();
  }

  void _onTick(RestTimerEntry entry) {
    if (entry.state != RestState.running || entry.startedAt == null) return;
    final elapsed = DateTime.now().difference(entry.startedAt!).inSeconds;
    final remaining = entry.durationSec - elapsed;
    if (remaining <= 0) {
      entry.remainingSec = 0;
      entry.state = RestState.finished;
      entry.ticker?.cancel();
      entry.ticker = null;
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      NotificationService.instance.cancelRestOngoing(entry.key);
      LiveActivityService.instance.endRest(entry.key);
      notifyListeners();
      Timer(const Duration(seconds: 5), () {
        if (entry.state == RestState.finished) stop(entry.key);
      });
    } else {
      entry.remainingSec = remaining;
      tick.value++;
    }
  }
}
