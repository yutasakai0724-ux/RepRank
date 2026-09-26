import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'session_manager.dart';
import 'stopwatch_service.dart';

/// トレーニング時間の記録を管理するシングルトン。
///
/// - ストップウォッチカードの「トレーニング開始／終了」で開始・終了時刻を記録する。
/// - 「最後にセットを記録した時刻」から一定時間（設定値）記録がなければ自動終了し、
///   終了時刻は最後の記録の時刻にする（クールダウン分などは加えない）。
/// - 開始したのに記録が1件も付かなかった場合は、時間を記録しない。
/// - 状態は SharedPreferences に保存し、アプリ終了後も引き継ぐ。
///   iOS は通知時刻にアプリの処理を実行できないため、自動終了の判定は
///   アプリ内タイマーと、起動時／復帰時の [resolveIfExpired] で行う。
class TrainingTimeService extends ChangeNotifier {
  TrainingTimeService._();
  static final TrainingTimeService instance = TrainingTimeService._();

  static const _kEnabled = 'training_time_enabled';
  static const _kMinutes = 'training_time_auto_end_min';
  static const _kSuppressPrompt = 'training_time_suppress_start_prompt';
  static const _kStart = 'training_time_running_start';
  static const _kLastRecord = 'training_time_last_record';

  /// 自動終了までの時間として選べる値（分）
  static const autoEndChoices = [30, 45, 60, 90, 120, 180];

  bool _enabled = false;
  int _autoEndMinutes = 60;
  bool _suppressStartPrompt = false;
  DateTime? _startAt;
  DateTime? _lastRecordAt;
  Timer? _expiryTimer;
  bool _loaded = false;

  /// 「タイマーでトレーニング時間を記録」のオンオフ（初期オフ）。
  /// ストップウォッチカードのトグルと、設定画面のスイッチは同じ値を操作する。
  /// 記録中（トレーニング開始〜終了の間）は変更できない。
  bool get enabled => _enabled;
  int get autoEndMinutes => _autoEndMinutes;
  bool get suppressStartPrompt => _suppressStartPrompt;
  bool get isRunning => _startAt != null;
  DateTime? get startAt => _startAt;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    _enabled = p.getBool(_kEnabled) ?? false;
    _autoEndMinutes = p.getInt(_kMinutes) ?? 60;
    _suppressStartPrompt = p.getBool(_kSuppressPrompt) ?? false;
    final s = p.getString(_kStart);
    final l = p.getString(_kLastRecord);
    _startAt = s == null ? null : DateTime.tryParse(s);
    _lastRecordAt = l == null ? null : DateTime.tryParse(l);
    _loaded = true;
    await resolveIfExpired();
    _armExpiry();
    notifyListeners();
  }

  // ── 設定 ─────────────────────────────────────────────────────

  Future<void> setEnabled(bool v) async {
    if (isRunning) return; // 記録中は切り替えない
    _enabled = v;
    await _putBool(_kEnabled, v);
    notifyListeners();
  }

  Future<void> setSuppressStartPrompt(bool v) async {
    _suppressStartPrompt = v;
    await _putBool(_kSuppressPrompt, v);
    notifyListeners();
  }

  Future<void> setAutoEndMinutes(int minutes) async {
    _autoEndMinutes = minutes;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kMinutes, minutes);
    if (isRunning) {
      await resolveIfExpired();
      _scheduleExpiry();
    }
    notifyListeners();
  }

  Future<void> _putBool(String key, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, v);
  }

  // ── 開始・終了 ───────────────────────────────────────────────

  /// トレーニング開始。[hasRecordNow] が true なら、開始時点で記録済み
  /// （開始し忘れの促しから開始した場合）として扱う。
  Future<void> start({bool hasRecordNow = false}) async {
    if (isRunning) return;
    final now = DateTime.now();
    _startAt = now;
    _lastRecordAt = hasRecordNow ? now : null;
    await _persist();
    if (hasRecordNow) _scheduleExpiry();
    notifyListeners();
  }

  /// 中断（RESET）: 記録を保存せずに破棄する。
  Future<void> cancel() async {
    if (!isRunning) return;
    _startAt = null;
    _lastRecordAt = null;
    _expiryTimer?.cancel();
    await _persist();
    await NotificationService.instance.cancelTrainingAutoEnd();
    notifyListeners();
  }

  /// 手動終了（終了時刻は今の時刻）。記録が1件も無ければ時間は記録しない。
  Future<void> endManually() => _end(auto: false);

  Future<void> _end({required bool auto}) async {
    final start = _startAt;
    if (start == null) return;
    final last = _lastRecordAt;
    _startAt = null;
    _lastRecordAt = null;
    _expiryTimer?.cancel();
    await _persist();
    if (!auto) await NotificationService.instance.cancelTrainingAutoEnd();
    StopwatchService.instance.stop();

    if (last != null) {
      final end = auto ? last : DateTime.now();
      await _saveToSession(start, end);
    }
    notifyListeners();
  }

  /// 開始した日のセッション（複数あれば最初のもの）に開始・終了時刻を書き込む。
  Future<void> _saveToSession(DateTime start, DateTime end) async {
    if (end.isBefore(start)) return;
    final sessions = await SessionManager.instance.getSessionsForDate(start);
    if (sessions.isEmpty) return;
    await SessionManager.instance.updateTrainingTime(
      sessions.first.id,
      start,
      end,
    );
  }

  // ── 記録の検知・自動終了 ─────────────────────────────────────

  /// セットが保存されたときに呼ぶ。今日の記録なら最終記録時刻を更新して通知を予約し直す。
  void onRecordSaved(DateTime sessionDate) {
    if (!_loaded || !isRunning) return;
    final n = DateTime.now();
    final isToday =
        sessionDate.year == n.year &&
        sessionDate.month == n.month &&
        sessionDate.day == n.day;
    if (!isToday) return;
    _lastRecordAt = n;
    _persist();
    _scheduleExpiry();
    notifyListeners();
  }

  /// 最終記録から設定時間が過ぎている（または日付をまたいだ）場合に自動終了する。
  Future<void> resolveIfExpired() async {
    final start = _startAt;
    if (start == null) return;
    final last = _lastRecordAt;
    final now = DateTime.now();

    final crossedDay =
        start.year != now.year ||
        start.month != now.month ||
        start.day != now.day;
    if (last == null) {
      // 記録が無いまま日付をまたいだ場合は、時間を記録せず破棄
      if (crossedDay) await _end(auto: true);
      return;
    }
    final expired = now.difference(last) >= Duration(minutes: _autoEndMinutes);
    if (expired || crossedDay) await _end(auto: true);
  }

  void _armExpiry() {
    if (isRunning && _lastRecordAt != null) _scheduleExpiry();
  }

  /// アプリ内タイマー（前面にいる間の自動終了）と、通知の予約をまとめて更新する。
  void _scheduleExpiry() {
    final last = _lastRecordAt;
    if (last == null) return;
    final at = last.add(Duration(minutes: _autoEndMinutes));
    _expiryTimer?.cancel();
    final wait = at.difference(DateTime.now());
    _expiryTimer = Timer(
      wait.isNegative ? Duration.zero : wait,
      resolveIfExpired,
    );
    NotificationService.instance.scheduleTrainingAutoEnd(
      at,
      'トレーニングの記録から${_label(_autoEndMinutes)}が経過しました',
      'トレーニング時間の記録を終了しました（最後の記録の時刻で終了）',
    );
  }

  static String _label(int minutes) {
    if (minutes < 60) return '$minutes分';
    final h = minutes ~/ 60, m = minutes % 60;
    return m == 0 ? '$h時間' : '$h時間$m分';
  }

  static String labelFor(int minutes) => _label(minutes);

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    if (_startAt == null) {
      await p.remove(_kStart);
    } else {
      await p.setString(_kStart, _startAt!.toIso8601String());
    }
    if (_lastRecordAt == null) {
      await p.remove(_kLastRecord);
    } else {
      await p.setString(_kLastRecord, _lastRecordAt!.toIso8601String());
    }
  }
}
