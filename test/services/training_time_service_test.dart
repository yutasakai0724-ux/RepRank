import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:RepRank/models/workout.dart';
import 'package:RepRank/repositories/workout_repository.dart';
import 'package:RepRank/services/session_manager.dart';
import 'package:RepRank/services/training_time_service.dart';

class _MockRepo implements WorkoutRepository {
  final List<WorkoutSession> store = [];
  @override
  Future<List<WorkoutSession>> getAllSessions() async => List.of(store);
  @override
  Future<List<WorkoutSession>> getSessionsForDate(DateTime d) async => store
      .where((s) =>
          s.date.year == d.year && s.date.month == d.month && s.date.day == d.day)
      .toList();
  @override
  Future<void> upsertSession(WorkoutSession s) async {
    store.removeWhere((x) => x.id == s.id);
    store.add(s);
  }

  @override
  Future<void> deleteSession(String id) async => store.removeWhere((s) => s.id == id);
}

void main() {
  late _MockRepo repo;
  final now = DateTime.now();

  Future<void> boot(Map<String, Object> prefs) async {
    SharedPreferences.setMockInitialValues(prefs);
    repo = _MockRepo();
    SessionManager.instance.reset();
    SessionManager.instance.init(repo);
    await repo.upsertSession(WorkoutSession(
      date: DateTime(now.year, now.month, now.day),
      startedAt: DateTime(now.year, now.month, now.day),
    ));
    await TrainingTimeService.instance.init();
  }

  test('最終記録から設定時間が過ぎていれば、最終記録の時刻で自動終了して保存する', () async {
    // 開始は日付内の早い時刻にそろえるため、今日の 0:10 開始・0:50 最終記録（60分設定で経過済み）
    final start = DateTime(now.year, now.month, now.day, 0, 10);
    final last = DateTime(now.year, now.month, now.day, 0, 50);
    if (now.difference(last) < const Duration(minutes: 60)) {
      return; // 0:50 から60分未満（深夜0時台）の実行時は判定不能なのでスキップ
    }
    await boot({
      'training_time_running_start': start.toIso8601String(),
      'training_time_last_record': last.toIso8601String(),
    });
    expect(TrainingTimeService.instance.isRunning, isFalse);
    final s = repo.store.single;
    expect(s.trainingStartedAt, start);
    expect(s.trainingEndedAt, last);
    expect(s.trainingDuration, const Duration(minutes: 40));
  });

  test('記録が1件も無いまま手動終了した場合は時間を記録しない', () async {
    await boot({});
    await TrainingTimeService.instance.start();
    expect(TrainingTimeService.instance.isRunning, isTrue);
    await TrainingTimeService.instance.endManually();
    expect(TrainingTimeService.instance.isRunning, isFalse);
    expect(repo.store.single.trainingStartedAt, isNull);
  });

  test('記録後に手動終了すると開始・終了が保存される', () async {
    await boot({});
    await TrainingTimeService.instance.start();
    TrainingTimeService.instance.onRecordSaved(now);
    await TrainingTimeService.instance.endManually();
    final s = repo.store.single;
    expect(s.trainingStartedAt, isNotNull);
    expect(s.trainingEndedAt, isNotNull);
    expect(s.trainingDuration!.inSeconds, greaterThanOrEqualTo(0));
  });
}
