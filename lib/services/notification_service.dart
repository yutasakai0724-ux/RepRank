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

  static const _restEndId = 42;
  static const _restOngoingId = 43;
  static const _stopwatchOngoingId = 44;

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

  Future<void> scheduleRestEnd(int remainingSec) async {
    final enabled = await UserPreferences.instance.getRestNotification();
    if (!enabled || !_initialized) return;

    await _plugin.cancel(_restEndId);
    final scheduledTime =
        tz.TZDateTime.now(tz.local).add(Duration(seconds: remainingSec));

    try {
      await _plugin.zonedSchedule(
        _restEndId,
        '休憩終了',
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
      );
    } catch (e) {
      debugPrint('[NotificationService] schedule failed: $e');
    }
  }

  Future<void> cancelRestEnd() async {
    if (!_initialized) return;
    await _plugin.cancel(_restEndId);
  }

  // ── 常駐通知（Android chronometer によるリアルタイム残り時間・経過時間表示）──
  // iOS はローカル通知をバックグラウンドで逐次更新できないため対象外（Live Activities で別途対応）。

  /// 休憩タイマーの残り時間を通知バーにリアルタイム表示（Android のみ）。
  Future<void> showRestOngoing(DateTime endTime) async {
    if (!Platform.isAndroid || !_initialized) return;
    final enabled = await UserPreferences.instance.getRestNotification();
    if (!enabled) return;
    try {
      await _plugin.show(
        _restOngoingId,
        '休憩タイマー',
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
      );
    } catch (e) {
      debugPrint('[NotificationService] rest ongoing failed: $e');
    }
  }

  Future<void> cancelRestOngoing() async {
    if (!_initialized) return;
    await _plugin.cancel(_restOngoingId);
  }

  /// ストップウォッチの経過時間を通知バーにリアルタイム表示（Android のみ）。
  Future<void> showStopwatchOngoing(DateTime startedAt) async {
    if (!Platform.isAndroid || !_initialized) return;
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
