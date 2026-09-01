import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'live_activity_service.dart';
import 'notification_service.dart';

enum RestState { idle, running, paused, finished }

/// 休憩タイマーのグローバルシングルトン。
/// DateTime ベースで残り時間を計算するため、バックグラウンド後も正確に動作する。
/// 画面遷移してもタイマーはリセットされない。
class RestTimerService extends ChangeNotifier {
  RestTimerService._();
  static final RestTimerService instance = RestTimerService._();

  RestState _state = RestState.idle;
  int _durationSec = 60;
  int _remainingSec = 60;
  DateTime? _startedAt;
  int _pausedRemaining = 0;
  Timer? _ticker;

  RestState get state => _state;
  int get remainingSec => _remainingSec;
  int get durationSec => _durationSec;

  // ── オーバーレイ抑制 ──────────────────────────────────
  // 記録画面自体に休憩タイマーUIが表示されている間は、
  // 全画面共通オーバーレイとの二重表示を避けるため抑制する。
  int _suppressCount = 0;
  bool get overlaySuppressed => _suppressCount > 0;

  void suppressOverlay() {
    _suppressCount++;
    notifyListeners();
  }

  void unsuppressOverlay() {
    if (_suppressCount > 0) _suppressCount--;
    notifyListeners();
  }

  void setDuration(int sec) {
    _durationSec = sec;
    if (_state == RestState.idle) {
      _remainingSec = sec;
      notifyListeners();
    }
  }

  void start() {
    _ticker?.cancel();
    _startedAt = DateTime.now();
    _remainingSec = _durationSec;
    _state = RestState.running;
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
    final endTime = _startedAt!.add(Duration(seconds: _durationSec));
    NotificationService.instance.scheduleRestEnd(_durationSec);
    NotificationService.instance.showRestOngoing(endTime);
    LiveActivityService.instance.startRest(endTime, _durationSec);
    notifyListeners();
  }

  void pause() {
    if (_state != RestState.running) return;
    _ticker?.cancel();
    _ticker = null;
    _pausedRemaining = _remainingSec;
    _state = RestState.paused;
    NotificationService.instance.cancelRestEnd();
    NotificationService.instance.cancelRestOngoing();
    LiveActivityService.instance.endRest();
    notifyListeners();
  }

  void resume() {
    if (_state != RestState.paused) return;
    _startedAt = DateTime.now().subtract(
      Duration(seconds: _durationSec - _pausedRemaining),
    );
    _state = RestState.running;
    _ticker = Timer.periodic(const Duration(seconds: 1), _onTick);
    final endTime = DateTime.now().add(Duration(seconds: _pausedRemaining));
    NotificationService.instance.scheduleRestEnd(_pausedRemaining);
    NotificationService.instance.showRestOngoing(endTime);
    LiveActivityService.instance.startRest(endTime, _pausedRemaining);
    notifyListeners();
  }

  void stop() {
    _ticker?.cancel();
    _ticker = null;
    _state = RestState.idle;
    _remainingSec = _durationSec;
    _startedAt = null;
    NotificationService.instance.cancelRestEnd();
    NotificationService.instance.cancelRestOngoing();
    LiveActivityService.instance.endRest();
    notifyListeners();
  }

  void _onTick(Timer _) {
    if (_state != RestState.running || _startedAt == null) return;
    final elapsed = DateTime.now().difference(_startedAt!).inSeconds;
    final remaining = _durationSec - elapsed;
    if (remaining <= 0) {
      _remainingSec = 0;
      _state = RestState.finished;
      _ticker?.cancel();
      _ticker = null;
      HapticFeedback.heavyImpact();
      SystemSound.play(SystemSoundType.alert);
      NotificationService.instance.cancelRestOngoing();
      LiveActivityService.instance.endRest();
      notifyListeners();
      Timer(const Duration(seconds: 5), () {
        if (_state == RestState.finished) stop();
      });
    } else {
      _remainingSec = remaining;
      notifyListeners();
    }
  }
}
