import '../models/workout.dart';
import '../repositories/workout_repository.dart';

/// アクティブなワークアウトセッションをメモリ上で管理し、
/// リポジトリへの読み書きも仲介するシングルトン。
///
/// 画面は SessionManager 経由でデータにアクセスするため、
/// リポジトリ実装（SQLite / Firestore）を意識しない。
class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  late WorkoutRepository _repo;
  WorkoutSession? _active;

  /// アプリ起動時に呼ぶ（main.dart）
  void init(WorkoutRepository repository) {
    _repo = repository;
  }

  // ── アクティブセッション ──────────────────────────────────────

  WorkoutSession? get active => _active;

  /// セッションが存在しなければ新規作成、あれば既存を返す
  WorkoutSession getOrCreate({String? sessionName, String? routineName}) {
    _active ??= WorkoutSession(
      sessionName: sessionName,
      routineName: routineName,
      date: DateTime.now(),
      startedAt: DateTime.now(),
    );
    return _active!;
  }

  /// 種目を保存し、DB に即座に書き込む
  Future<void> saveExercise(Exercise exercise) async {
    final session = getOrCreate();
    final idx = session.exercises.indexWhere((e) => e.name == exercise.name);
    if (idx >= 0) {
      session.exercises[idx] = exercise;
    } else {
      session.exercises.add(exercise);
    }
    await _repo.upsertSession(session);
  }

  /// セッション終了（finishedAt を記録して DB 保存）
  Future<WorkoutSession?> finish() async {
    if (_active == null) return null;
    _active!.finishedAt = DateTime.now();
    await _repo.upsertSession(_active!);
    final finished = _active;
    _active = null;
    return finished;
  }

  /// セッション破棄（テスト・リセット用）
  void reset() => _active = null;

  // ── データ読み取りファサード（画面からリポジトリを隠蔽）────────

  Future<List<WorkoutSession>> getAllSessions() => _repo.getAllSessions();

  Future<List<WorkoutSession>> getSessionsForDate(DateTime date) =>
      _repo.getSessionsForDate(date);

  Future<void> deleteSession(String id) => _repo.deleteSession(id);

  /// 指定種目の過去最高ベストセット（1RM が最大のセット）
  Future<WorkoutSet?> getPreviousBest(String exerciseName) async {
    final sessions = await _repo.getAllSessions();
    // アクティブセッションは除外（まだ確定していない）
    final allSets = sessions
        .where((s) => s.id != _active?.id)
        .expand((s) => s.exercises)
        .where((e) => e.name == exerciseName)
        .expand((e) => e.sets)
        .toList();
    if (allSets.isEmpty) return null;
    return allSets.reduce((a, b) => a.oneRM > b.oneRM ? a : b);
  }
}
