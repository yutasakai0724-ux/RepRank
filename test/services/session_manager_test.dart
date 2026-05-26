import 'package:flutter_test/flutter_test.dart';
import 'package:kintorekioku/models/workout.dart';
import 'package:kintorekioku/repositories/workout_repository.dart';
import 'package:kintorekioku/services/session_manager.dart';

// ── インメモリ モックリポジトリ ───────────────────────────────────
class _MockRepo implements WorkoutRepository {
  final List<WorkoutSession> _store = [];

  @override
  Future<List<WorkoutSession>> getAllSessions() async =>
      List.unmodifiable(_store);

  @override
  Future<List<WorkoutSession>> getSessionsForDate(DateTime date) async =>
      _store.where((s) =>
          s.date.year == date.year &&
          s.date.month == date.month &&
          s.date.day == date.day).toList();

  @override
  Future<void> upsertSession(WorkoutSession session) async {
    final idx = _store.indexWhere((s) => s.id == session.id);
    if (idx >= 0) {
      _store[idx] = session;
    } else {
      _store.add(session);
    }
  }

  @override
  Future<void> deleteSession(String id) async {
    _store.removeWhere((s) => s.id == id);
  }
}

// ── テスト用 SessionManager リセット ────────────────────────────
// SessionManager はシングルトンなので各テストで reset() を呼ぶ
void _resetManager(_MockRepo repo) {
  SessionManager.instance.reset();
  SessionManager.instance.init(repo);
}

void main() {
  late _MockRepo repo;

  setUp(() {
    repo = _MockRepo();
    _resetManager(repo);
  });

  // ── getOrCreate ─────────────────────────────────────────────────
  group('getOrCreate', () {
    test('creates new session when none exists', () {
      final session = SessionManager.instance.getOrCreate();
      expect(session, isNotNull);
      expect(session.id, isNotEmpty);
    });

    test('returns same session on repeated calls', () {
      final a = SessionManager.instance.getOrCreate();
      final b = SessionManager.instance.getOrCreate();
      expect(a.id, equals(b.id));
    });

    test('stores sessionName and routineName', () {
      final session = SessionManager.instance.getOrCreate(
        sessionName: '胸の日',
        routineName: '胸の日',
      );
      expect(session.sessionName, '胸の日');
      expect(session.routineName, '胸の日');
    });
  });

  // ── saveExercise ────────────────────────────────────────────────
  group('saveExercise', () {
    test('saves a new exercise to session and DB', () async {
      final exercise = Exercise(
        name: 'ベンチプレス',
        muscleGroup: MuscleGroup.chest,
        sets: [WorkoutSet(setNumber: 1, weight: 80.0, reps: 5)],
      );
      await SessionManager.instance.saveExercise(exercise);

      final sessions = await repo.getAllSessions();
      expect(sessions.length, 1);
      expect(sessions.first.exercises.first.name, 'ベンチプレス');
    });

    test('updates existing exercise by name', () async {
      final ex1 = Exercise(
        name: 'ベンチプレス',
        muscleGroup: MuscleGroup.chest,
        sets: [WorkoutSet(setNumber: 1, weight: 80.0, reps: 5)],
      );
      await SessionManager.instance.saveExercise(ex1);

      final ex2 = Exercise(
        name: 'ベンチプレス',
        muscleGroup: MuscleGroup.chest,
        sets: [
          WorkoutSet(setNumber: 1, weight: 80.0, reps: 5),
          WorkoutSet(setNumber: 2, weight: 85.0, reps: 3),
        ],
      );
      await SessionManager.instance.saveExercise(ex2);

      final sessions = await repo.getAllSessions();
      expect(sessions.length, 1); // セッションは1つのまま
      expect(sessions.first.exercises.length, 1); // 種目も1つのまま
      expect(sessions.first.exercises.first.sets.length, 2); // セット数が更新
    });

    test('adds different exercises as separate entries', () async {
      await SessionManager.instance.saveExercise(
        Exercise(name: 'ベンチプレス', muscleGroup: MuscleGroup.chest),
      );
      await SessionManager.instance.saveExercise(
        Exercise(name: 'スクワット', muscleGroup: MuscleGroup.legs),
      );

      final session = SessionManager.instance.active!;
      expect(session.exercises.length, 2);
    });
  });

  // ── finish ──────────────────────────────────────────────────────
  group('finish', () {
    test('returns null when no active session', () async {
      final result = await SessionManager.instance.finish();
      expect(result, isNull);
    });

    test('sets finishedAt and clears active session', () async {
      SessionManager.instance.getOrCreate();
      await SessionManager.instance.saveExercise(
        Exercise(name: 'デッドリフト', muscleGroup: MuscleGroup.back),
      );

      final before = DateTime.now();
      final finished = await SessionManager.instance.finish();
      final after = DateTime.now();

      expect(finished, isNotNull);
      expect(finished!.finishedAt, isNotNull);
      expect(
        finished.finishedAt!.isAfter(before) ||
            finished.finishedAt!.isAtSameMomentAs(before),
        isTrue,
      );
      expect(
        finished.finishedAt!.isBefore(after) ||
            finished.finishedAt!.isAtSameMomentAs(after),
        isTrue,
      );
      expect(SessionManager.instance.active, isNull);
    });

    test('persists session to DB after finish', () async {
      SessionManager.instance.getOrCreate(sessionName: 'テスト');
      await SessionManager.instance.finish();

      final sessions = await repo.getAllSessions();
      expect(sessions.length, 1);
      expect(sessions.first.finishedAt, isNotNull);
    });
  });

  // ── getPreviousBest ─────────────────────────────────────────────
  group('getPreviousBest', () {
    test('returns null when no past sessions exist', () async {
      final best = await SessionManager.instance.getPreviousBest('ベンチプレス');
      expect(best, isNull);
    });

    test('returns set with highest 1RM across sessions', () async {
      // 過去セッション2つを直接リポジトリに挿入
      final past1 = WorkoutSession(
        date: DateTime.now().subtract(const Duration(days: 7)),
        startedAt: DateTime.now().subtract(const Duration(days: 7)),
        exercises: [
          Exercise(
            name: 'ベンチプレス',
            muscleGroup: MuscleGroup.chest,
            sets: [WorkoutSet(setNumber: 1, weight: 80.0, reps: 5)], // 1RM=90
          ),
        ],
      );
      final past2 = WorkoutSession(
        date: DateTime.now().subtract(const Duration(days: 3)),
        startedAt: DateTime.now().subtract(const Duration(days: 3)),
        exercises: [
          Exercise(
            name: 'ベンチプレス',
            muscleGroup: MuscleGroup.chest,
            sets: [WorkoutSet(setNumber: 1, weight: 100.0, reps: 5)], // 1RM=112.5
          ),
        ],
      );
      await repo.upsertSession(past1);
      await repo.upsertSession(past2);

      // アクティブセッションは別の種目
      await SessionManager.instance.saveExercise(
        Exercise(name: 'スクワット', muscleGroup: MuscleGroup.legs),
      );

      final best = await SessionManager.instance.getPreviousBest('ベンチプレス');
      expect(best, isNotNull);
      expect(best!.weight, 100.0); // より高い1RMを持つセットが返る
    });

    test('excludes active session from best calculation', () async {
      // 過去セッション
      final past = WorkoutSession(
        date: DateTime.now().subtract(const Duration(days: 7)),
        startedAt: DateTime.now().subtract(const Duration(days: 7)),
        exercises: [
          Exercise(
            name: 'ベンチプレス',
            muscleGroup: MuscleGroup.chest,
            sets: [WorkoutSet(setNumber: 1, weight: 80.0, reps: 5)],
          ),
        ],
      );
      await repo.upsertSession(past);

      // 現在のアクティブセッションに高い重量を入力（除外されるべき）
      await SessionManager.instance.saveExercise(
        Exercise(
          name: 'ベンチプレス',
          muscleGroup: MuscleGroup.chest,
          sets: [WorkoutSet(setNumber: 1, weight: 200.0, reps: 1)],
        ),
      );

      final best = await SessionManager.instance.getPreviousBest('ベンチプレス');
      expect(best!.weight, 80.0); // 過去セッションの値のみ参照
    });
  });

  // ── deleteSession ───────────────────────────────────────────────
  group('deleteSession', () {
    test('removes session from DB', () async {
      await SessionManager.instance.saveExercise(
        Exercise(name: 'テスト種目', muscleGroup: MuscleGroup.chest),
      );
      final finished = await SessionManager.instance.finish();
      expect(finished, isNotNull);

      final beforeDelete = await repo.getAllSessions();
      expect(beforeDelete.length, 1);

      await SessionManager.instance.deleteSession(finished!.id);

      final afterDelete = await repo.getAllSessions();
      expect(afterDelete.length, 0);
    });
  });
}
