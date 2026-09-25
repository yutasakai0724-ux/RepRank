import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'user_preferences.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _stopwatchOngoingId = 44;

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

  void _onNotificationTap(NotificationResponse response) {
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
    );
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
