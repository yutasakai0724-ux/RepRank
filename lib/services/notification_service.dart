import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'user_preferences.dart';

/// 通知アクション「タイマーをリセット」の ID。
const _actionResetRest = 'reset_rest';
const _actionResetStopwatch = 'reset_stopwatch';
/// メイン isolate へ送るメッセージ（ストップウォッチ用）。休憩は種目キーをそのまま送る。
const _stopwatchResetMessage = '__stopwatch_reset__';
const _resetPortName = 'rep_rank_rest_reset_port';

/// アプリが動作中でも通知アクション（バックグラウンド）は別 isolate で実行されるため、
/// メイン isolate に ReceivePort 経由でキーを送ってタイマーを止めてもらう。
@pragma('vm:entry-point')
void notificationActionBackground(NotificationResponse response) {
  final port = IsolateNameServer.lookupPortByName(_resetPortName);
  if (response.actionId == _actionResetStopwatch) {
    port?.send(_stopwatchResetMessage);
    return;
  }
  if (response.actionId != _actionResetRest) return;
  final key = response.payload;
  if (key == null) return;
  port?.send(key);
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _stopwatchOngoingId = 44;
  static const _trainingAutoEndId = 45;

  // ── 通知タップ時の画面遷移 ────────────────────────────────────
  // payload には種目タイマーのキー（種目名）を格納する。
  // ナビゲーションハンドラ登録前にタップされた場合に備えて保留しておく。
  void Function(String exerciseKey)? _navigationHandler;
  String? _pendingNavigationKey;

  void setNavigationHandler(void Function(String exerciseKey) handler) {
    _navigationHandler = handler;
    final pending = _pendingNavigationKey;
    if (pending != null) {
      _pendingNavigationKey = null;
      handler(pending);
    }
  }

  void _dispatchNavigation(String? key) {
    if (key == null || key.isEmpty) return;
    final handler = _navigationHandler;
    if (handler != null) {
      handler(key);
    } else {
      _pendingNavigationKey = key;
    }
  }

  // ── 通知アクション: タイマーをリセット ─────────────────────────
  void Function(String exerciseKey)? _resetHandler;
  void Function()? _stopwatchResetHandler;
  final ReceivePort _resetPort = ReceivePort();

  void setStopwatchResetHandler(void Function() handler) {
    _stopwatchResetHandler = handler;
  }

  void setResetHandler(void Function(String exerciseKey) handler) {
    _resetHandler = handler;
  }

  void _registerResetPort() {
    IsolateNameServer.removePortNameMapping(_resetPortName);
    IsolateNameServer.registerPortWithName(_resetPort.sendPort, _resetPortName);
    _resetPort.listen((message) {
      if (message == _stopwatchResetMessage) {
        _stopwatchResetHandler?.call();
      } else if (message is String) {
        _resetHandler?.call(message);
      }
    });
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.actionId == _actionResetStopwatch) {
      _stopwatchResetHandler?.call();
      return;
    }
    if (response.actionId == _actionResetRest) {
      final key = response.payload;
      if (key != null) _resetHandler?.call(key);
      return;
    }
    _dispatchNavigation(response.payload);
  }

  /// アプリが通知タップで（終了状態から）起動された場合の payload を拾う。
  /// main() で initialize() の直後に呼ぶこと。
  Future<void> checkLaunchDetails() async {
    if (!_initialized) return;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp == true) {
      _dispatchNavigation(details!.notificationResponse?.payload);
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    // ローカルタイムゾーンを設定
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final locations = tz.timeZoneDatabase.locations;
      // オフセットに合うタイムゾーンを検索（近似）
      for (final loc in locations.values) {
        final tzNow = tz.TZDateTime.now(loc);
        if ((tzNow.timeZoneOffset - offset).inMinutes.abs() <= 30) {
          tz.setLocalLocation(loc);
          break;
        }
      }
    } catch (_) {}

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: _onNotificationTap,
      onDidReceiveBackgroundNotificationResponse: notificationActionBackground,
    );
    _registerResetPort();
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    if (Platform.isIOS) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(alert: true, sound: true, badge: false) ??
          false;
    } else if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.requestNotificationsPermission() ??
          false;
    }
    return false;
  }

  // ── 種目ごとの通知ID ──────────────────────────────────────────
  // 同じ key（種目名）でも「終了通知」と「進行中通知」は別IDにする必要があるため
  // 用途プレフィックスと key を合成してハッシュ化する。
  int _idFor(String usage, String key) =>
      (usage.hashCode ^ key.hashCode) & 0x7FFFFFFF;

  int _restEndId(String key) => _idFor('rest_end', key);
  int _restOngoingId(String key) => _idFor('rest_ongoing', key);

  // ── 休憩終了アラート通知（種目ごと） ────────────────────────────

  Future<void> scheduleRestEnd(
      String key, String exerciseName, int remainingSec) async {
    final enabled = await UserPreferences.instance.getRestNotification();
    if (!enabled || !_initialized) return;

    final id = _restEndId(key);
    await _plugin.cancel(id);
    final scheduledTime =
        tz.TZDateTime.now(tz.local).add(Duration(seconds: remainingSec));

    try {
      await _plugin.zonedSchedule(
        id,
        '休憩終了 - $exerciseName',
        '次のセットを始めましょう！',
        scheduledTime,
        NotificationDetails(
          android: const AndroidNotificationDetails(
            'rest_timer_channel',
            '休憩タイマー',
            channelDescription: '休憩タイマー終了時に通知します',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            sound: 'default',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: key,
      );
    } catch (e) {
      debugPrint('[NotificationService] schedule failed: $e');
    }
  }

  // ── トレーニング時間の自動終了通知 ─────────────────────────────
  // 「最後の記録から一定時間」の時刻に通知する。iOS は通知時刻にアプリの処理を
  // 実行できないため、実際の終了処理は TrainingTimeService が次回起動時／復帰時に行う。

  Future<void> scheduleTrainingAutoEnd(
      DateTime when, String title, String body) async {
    final enabled = await UserPreferences.instance.getRestNotification();
    if (!enabled || !_initialized) return;
    await _plugin.cancel(_trainingAutoEndId);
    final now = DateTime.now();
    if (!when.isAfter(now)) return;
    try {
      await _plugin.zonedSchedule(
        _trainingAutoEndId,
        title,
        body,
        tz.TZDateTime.now(tz.local).add(when.difference(now)),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'training_time_channel',
            'トレーニング時間',
            channelDescription: 'トレーニング時間の記録を自動終了したときに通知します',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentSound: true,
            sound: 'default',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint('[NotificationService] training auto-end schedule failed: $e');
    }
  }

  Future<void> cancelTrainingAutoEnd() async {
    if (!_initialized) return;
    await _plugin.cancel(_trainingAutoEndId);
  }

  Future<void> cancelRestEnd(String key) async {
    if (!_initialized) return;
    await _plugin.cancel(_restEndId(key));
  }

  // ── 常駐通知（Android chronometer によるリアルタイム残り時間・経過時間表示）──
  // iOS はローカル通知をバックグラウンドで逐次更新できないため対象外（Live Activities で別途対応）。

  /// 休憩タイマーの残り時間を通知バーにリアルタイム表示（Android のみ・種目ごと）。
  Future<void> showRestOngoing(
      String key, String exerciseName, DateTime endTime) async {
    if (!Platform.isAndroid || !_initialized) return;
    final enabled = await UserPreferences.instance.getRestNotification();
    if (!enabled) return;
    try {
      await _plugin.show(
        _restOngoingId(key),
        '休憩タイマー - $exerciseName',
        '残り時間をカウントダウン中',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'rest_timer_ongoing_channel',
            '休憩タイマー（進行中）',
            channelDescription: '休憩タイマーの残り時間をリアルタイム表示します',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            playSound: false,
            enableVibration: false,
            showWhen: true,
            usesChronometer: true,
            chronometerCountDown: true,
            when: endTime.millisecondsSinceEpoch,
            actions: const [
              AndroidNotificationAction(
                _actionResetRest,
                'タイマーをリセット',
                showsUserInterface: false,
                cancelNotification: true,
              ),
            ],
          ),
        ),
        payload: key,
      );
    } catch (e) {
      debugPrint('[NotificationService] rest ongoing failed: $e');
    }
  }

  Future<void> cancelRestOngoing(String key) async {
    if (!_initialized) return;
    await _plugin.cancel(_restOngoingId(key));
  }

  /// ストップウォッチの経過時間を通知バーにリアルタイム表示（Android のみ）。
  /// ストップウォッチはワークアウト全体で1つのため種目に依存しない。
  Future<void> showStopwatchOngoing(DateTime startedAt) async {
    if (!Platform.isAndroid || !_initialized) return;
    final enabled = await UserPreferences.instance.getRestNotification();
    if (!enabled) return;
    try {
      await _plugin.show(
        _stopwatchOngoingId,
        'ワークアウト計測中',
        '経過時間をカウント中',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'stopwatch_ongoing_channel',
            'ストップウォッチ（進行中）',
            channelDescription: 'ワークアウトの経過時間をリアルタイム表示します',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            playSound: false,
            enableVibration: false,
            showWhen: true,
            usesChronometer: true,
            chronometerCountDown: false,
            when: startedAt.millisecondsSinceEpoch,
            actions: const [
              AndroidNotificationAction(
                _actionResetStopwatch,
                'タイマーをリセット',
                showsUserInterface: false,
                cancelNotification: true,
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('[NotificationService] stopwatch ongoing failed: $e');
    }
  }

  Future<void> cancelStopwatchOngoing() async {
    if (!_initialized) return;
    await _plugin.cancel(_stopwatchOngoingId);
  }
}
