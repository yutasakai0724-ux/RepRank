import 'package:flutter/foundation.dart';
import '../repositories/firestore_workout_repository.dart';
import '../repositories/sqlite_workout_repository.dart';
import '../data/database_helper.dart';

/// ログイン・ログアウト時のデータ同期を管理するサービス。
///
/// - 初回ログイン: ローカルデータ → Firestore にアップロード
/// - 新端末ログイン: Firestore → ローカル SQLite にダウンロード
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  /// ログイン後に呼ぶ。
  /// ローカルにデータがあれば Firestore へアップロード。
  /// ローカルが空で Firestore にデータがあればダウンロード。
  Future<void> syncOnLogin(String uid) async {
    try {
      debugPrint('[Sync] starting sync for uid=$uid');
      final local = SqliteWorkoutRepository(DatabaseHelper.instance);
      final cloud = FirestoreWorkoutRepository(uid);

      final localSessions = await local.getAllSessions();
      final cloudSessions = await cloud.getAllSessions();

      if (localSessions.isEmpty && cloudSessions.isNotEmpty) {
        // 新端末: クラウドからローカルへダウンロード
        debugPrint('[Sync] downloading ${cloudSessions.length} sessions from cloud');
        for (final s in cloudSessions) {
          await local.upsertSession(s);
        }
        debugPrint('[Sync] download complete');
      } else if (localSessions.isNotEmpty) {
        // 初回ログインまたは既存端末: ローカルをクラウドへアップロード
        debugPrint('[Sync] uploading ${localSessions.length} sessions to cloud');
        for (final s in localSessions) {
          await cloud.upsertSession(s);
        }
        debugPrint('[Sync] upload complete');
      }
    } catch (e) {
      debugPrint('[Sync] sync failed: $e');
    }
  }
}
