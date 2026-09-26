import 'package:flutter/foundation.dart';
import '../models/workout.dart';
import '../repositories/workout_repository.dart';
import 'user_preferences.dart';

/// アクティブなワークアウトセッションをメモリ上で管理し、
/// リポジトリへの読み書きも仲介するシングルトン。
/// ChangeNotifier を使って分析画面にデータ変更を通知する。
class SessionManager extends ChangeNotifier {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  late WorkoutRepository _repo;
  WorkoutSession? _active;
  List<String> routineExerciseNames = [];

  /// アプリ起動時に呼ぶ（main.dart）
  void init(WorkoutRepository repository) {
    _repo = repository;
  }

  /// ユーザー操作による保存。最終更新日時を付けて書き込む（同期時の新旧判定に使う）。
  Future<void> _save(WorkoutSession session) {
    session.updatedAt = DateTime.now();
    return _repo.upsertSession(session);
  }

  /// 同期など外部要因でデータが更新されたことを画面に知らせる。
  void notifyDataChanged() => notifyListeners();

  // ── アクティブセッション ──────────────────────────────────────

  WorkoutSession? get active => _active;

  /// セッションが存在しなければ新規作成、あれば既存を返す。
  /// アクティブセッションが別日の場合は破棄して新規作成。
  Future<WorkoutSession> getOrCreate({
    String? sessionName,
    String? routineName,
  }) async {
    if (_active != null) {
      final today = DateTime.now();
      final d = _active!.date;
      if (d.year != today.year ||
          d.month != today.month ||
          d.day != today.day) {
        _active = null; // 別日のセッションを破棄
      }
    }
    if (_active == null) {
      final bw = await UserPreferences.instance.getBodyWeight();
      _active = WorkoutSession(
        sessionName: sessionName,
        routineName: routineName,
        date: DateTime.now(),
        startedAt: DateTime.now(),
        bodyWeightKg: bw,
      );
    }
    return _active!;
  }

  /// 種目を保存し、DB に即座に書き込む（アクティブセッション用）
  Future<void> saveExercise(Exercise exercise) async {
    final session = await getOrCreate();
    final idx = session.exercises.indexWhere((e) => e.name == exercise.name);
    if (idx >= 0) {
      session.exercises[idx] = exercise;
    } else {
      session.exercises.add(exercise);
    }
    await _save(session);
    notifyListeners();
  }

  /// 既存セッションの種目を更新して DB に保存（編集モード用）
  Future<void> saveExerciseToExistingSession(
    String sessionId,
    Exercise exercise,
  ) async {
    // アクティブセッションの場合はそのまま saveExercise を流用
    if (_active?.id == sessionId) {
      await saveExercise(exercise);
      return;
    }
    // 過去のセッションは DB から取得して更新
    final sessions = await _repo.getAllSessions();
    final session = sessions.where((s) => s.id == sessionId).firstOrNull;
    if (session == null) return;
    final idx = session.exercises.indexWhere((e) => e.name == exercise.name);
    if (idx >= 0) {
      session.exercises[idx] = exercise;
    } else {
      session.exercises.add(exercise);
    }
    await _save(session);
    notifyListeners();
  }

  /// 今日の記録に指定種目があれば返す（同日同種目チェック用）
  Future<({WorkoutSession session, Exercise exercise})?> findTodayExercise(
    String exerciseName,
  ) async {
    final today = DateTime.now();
    // アクティブセッション（今日）をチェック
    if (_active != null) {
      final d = _active!.date;
      if (d.year == today.year &&
          d.month == today.month &&
          d.day == today.day) {
        final ex = _active!.exercises
            .where((e) => e.name == exerciseName)
            .firstOrNull;
        if (ex != null) return (session: _active!, exercise: ex);
      }
    }
    // DB から今日のセッションをチェック
    final todaySessions = await _repo.getSessionsForDate(today);
    for (final s in todaySessions) {
      final ex = s.exercises.where((e) => e.name == exerciseName).firstOrNull;
      if (ex != null) return (session: s, exercise: ex);
    }
    return null;
  }

  /// 指定日付でセッションを新規作成して保存（カレンダーから過去日付に記録する際に使用）
  Future<WorkoutSession> createSessionForDate(DateTime date) async {
    final session = WorkoutSession(date: date, startedAt: date);
    await _save(session);
    _cache = null;
    return session;
  }

  /// セッション終了（finishedAt を記録して DB 保存）
  Future<WorkoutSession?> finish() async {
    if (_active == null) return null;
    _active!.finishedAt = DateTime.now();
    await _save(_active!);
    final finished = _active;
    _active = null;
    return finished;
  }

  /// セッションの体重を更新する。
  /// 当日（今日）のセッションであればプロフィールの体重も同時に更新する。
  /// 過去日（1日以上前）のセッションはそのセッションの体重比算出にのみ使用し、
  /// プロフィールの値は変更しない。
  Future<void> updateSessionBodyWeight(String sessionId, double weight) async {
    WorkoutSession? session;
    if (_active?.id == sessionId) {
      session = _active;
    } else {
      final sessions = await _repo.getAllSessions();
      session = sessions.where((s) => s.id == sessionId).firstOrNull;
    }
    if (session == null) return;

    session.bodyWeightKg = weight;
    await _save(session);

    final today = DateTime.now();
    final d = session.date;
    final isToday =
        d.year == today.year && d.month == today.month && d.day == today.day;
    if (isToday) {
      await UserPreferences.instance.setBodyWeight(weight);
    }

    notifyListeners();
  }

  /// セッション破棄（テスト・リセット用）
  void reset() {
    _active = null;
    _cache = null;
    routineExerciseNames = [];
  }

  // ── データ読み取りファサード（画面からリポジトリを隠蔽）────────

  Future<List<WorkoutSession>> getAllSessions() => _repo.getAllSessions();

  List<WorkoutSession>? _cache;

  /// 表示専用のキャッシュ付き全件取得（カレンダー用）。
  /// データ変更の通知（notifyListeners）・削除で破棄される。返したリストは変更しないこと。
  Future<List<WorkoutSession>> getAllSessionsCached() async {
    final c = _cache;
    if (c != null) return c;
    final fresh = await _repo.getAllSessions();
    _cache = fresh;
    return fresh;
  }

  @override
  void notifyListeners() {
    _cache = null;
    super.notifyListeners();
  }

  Future<List<WorkoutSession>> getSessionsForDate(DateTime date) =>
      _repo.getSessionsForDate(date);

  Future<void> deleteSession(String id) async {
    _cache = null;
    await _repo.deleteSession(id);
    _cache = null;
  }

  /// 指定種目の過去最高ベストセット（1RM が最大のセット）
  Future<WorkoutSet?> getPreviousBest(String exerciseName) async {
    final sessions = await _repo.getAllSessions();
    final allSets = sessions
        .where((s) => s.id != _active?.id)
        .expand((s) => s.exercises)
        .where((e) => e.name == exerciseName)
        .expand((e) => e.sets)
        .toList();
    if (allSets.isEmpty) return null;
    return allSets.reduce((a, b) => a.oneRM > b.oneRM ? a : b);
  }

  /// 指定種目を直近に記録したセッションでのその種目の記録（全セット）を返す。
  /// 「前回の記録」表示・ペースト機能用。現在編集中のセッションは除外。
  Future<({Exercise exercise, String sessionId})?> getPreviousExerciseRecord(
    String exerciseName, {
    String? excludeSessionId,
  }) async {
    final sessions = await _repo.getAllSessions();
    final candidates = sessions.where(
      (s) =>
          s.id != _active?.id &&
          s.id != excludeSessionId &&
          s.exercises.any((e) => e.name == exerciseName),
    );
    if (candidates.isEmpty) return null;
    final latestSession = candidates.reduce(
      (a, b) => a.date.isAfter(b.date) ? a : b,
    );
    return (
      exercise: latestSession.exercises.firstWhere(
        (e) => e.name == exerciseName,
      ),
      sessionId: latestSession.id,
    );
  }
}
