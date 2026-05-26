import '../models/workout.dart';

/// ワークアウトデータの永続化インターフェース。
/// SQLite / Firestore どちらの実装にも差し替え可能。
abstract class WorkoutRepository {
  /// 全セッションを開始日時の降順で取得
  Future<List<WorkoutSession>> getAllSessions();

  /// 指定日のセッションを取得（昇順）
  Future<List<WorkoutSession>> getSessionsForDate(DateTime date);

  /// セッションを保存（id が同じなら上書き）
  Future<void> upsertSession(WorkoutSession session);

  /// セッションを削除
  Future<void> deleteSession(String id);
}
