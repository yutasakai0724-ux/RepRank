import 'package:flutter/foundation.dart';
import '../models/workout.dart';
import 'workout_repository.dart';

/// SQLite（ローカル）と Firestore（クラウド）の両方に書き込むリポジトリ。
///
/// - 読み取りは SQLite（高速・オフライン対応）
/// - 書き込みは SQLite + Firestore 両方に同時実行
/// - Firestore への書き込みが失敗してもローカルには保存される
class HybridWorkoutRepository implements WorkoutRepository {
  final WorkoutRepository local;
  final WorkoutRepository cloud;

  HybridWorkoutRepository({required this.local, required this.cloud});

  @override
  Future<List<WorkoutSession>> getAllSessions() => local.getAllSessions();

  @override
  Future<List<WorkoutSession>> getSessionsForDate(DateTime date) =>
      local.getSessionsForDate(date);

  @override
  Future<void> upsertSession(WorkoutSession session) async {
    // ローカルを先に書き込み（オフラインでも確実に保存）
    await local.upsertSession(session);
    // クラウドはバックグラウンドで書き込み（失敗してもローカルに影響しない）
    cloud.upsertSession(session).catchError((e) {
      debugPrint('[Hybrid] cloud upsert failed: $e');
    });
  }

  @override
  Future<void> deleteSession(String id) async {
    await local.deleteSession(id);
    cloud.deleteSession(id).catchError((e) {
      debugPrint('[Hybrid] cloud delete failed: $e');
    });
  }
}
