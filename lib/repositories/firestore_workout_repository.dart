import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/workout.dart';
import 'workout_repository.dart';

/// Firestore を使った WorkoutRepository 実装。
/// ユーザーデータは `users/{uid}/sessions/{sessionId}` に保存する。
/// 削除した記録の印は `users/{uid}/deleted_sessions/{sessionId}`（端末間の削除の同期用）。
class FirestoreWorkoutRepository implements WorkoutRepository {
  final String uid;
  FirestoreWorkoutRepository(this.uid);

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('sessions');

  CollectionReference<Map<String, dynamic>> get _deletedCol => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('deleted_sessions');

  @override
  Future<List<WorkoutSession>> getAllSessions() async {
    try {
      final snap = await _col.orderBy('startedAt', descending: true).get();
      return snap.docs.map((d) => WorkoutSession.fromJson(d.data())).toList();
    } catch (e) {
      debugPrint('[Firestore] getAllSessions failed: $e');
      return [];
    }
  }

  @override
  Future<List<WorkoutSession>> getSessionsForDate(DateTime date) async {
    try {
      final dateStr = date.toIso8601String().substring(0, 10);
      final snap = await _col
          .where('date', isEqualTo: dateStr)
          .orderBy('startedAt')
          .get();
      return snap.docs.map((d) => WorkoutSession.fromJson(d.data())).toList();
    } catch (e) {
      debugPrint('[Firestore] getSessionsForDate failed: $e');
      return [];
    }
  }

  @override
  Future<void> upsertSession(WorkoutSession session) async {
    try {
      await _col.doc(session.id).set(session.toJson());
    } catch (e) {
      debugPrint('[Firestore] upsertSession failed: $e');
    }
  }

  /// 記録を削除し、削除の印を残す（他の端末の同期で、その端末の記録も削除される）。
  @override
  Future<void> deleteSession(String id) async {
    await removeSessionDoc(id);
    await putTombstone(id, DateTime.now());
  }

  /// 記録のドキュメントだけを削除する（削除の印は触らない。同期処理用）。
  Future<void> removeSessionDoc(String id) async {
    try {
      await _col.doc(id).delete();
    } catch (e) {
      debugPrint('[Firestore] deleteSession failed: $e');
    }
  }

  /// 最終更新日時が [mark] より新しい記録（前回の同期以降に変わったもの）。
  /// 失敗したときは null。
  Future<List<WorkoutSession>?> getSessionsUpdatedAfter(String mark) async {
    try {
      final snap = await _col.where('updatedAt', isGreaterThan: mark).get();
      return snap.docs.map((d) => WorkoutSession.fromJson(d.data())).toList();
    } catch (e) {
      debugPrint('[Firestore] getSessionsUpdatedAfter failed: $e');
      return null;
    }
  }

  /// 削除の印（ID → 削除時刻）。[after] を渡すと、それより後の印だけ。失敗したときは null。
  Future<Map<String, DateTime>?> getTombstones({String? after}) async {
    try {
      Query<Map<String, dynamic>> q = _deletedCol;
      if (after != null) q = q.where('deletedAt', isGreaterThan: after);
      final snap = await q.get();
      final result = <String, DateTime>{};
      for (final d in snap.docs) {
        final at = DateTime.tryParse(d.data()['deletedAt'] as String? ?? '');
        if (at != null) result[d.id] = at;
      }
      return result;
    } catch (e) {
      debugPrint('[Firestore] getTombstones failed: $e');
      return null;
    }
  }

  Future<void> putTombstone(String id, DateTime at) async {
    try {
      await _deletedCol
          .doc(id)
          .set({'id': id, 'deletedAt': at.toIso8601String()});
    } catch (e) {
      debugPrint('[Firestore] putTombstone failed: $e');
    }
  }

  Future<void> removeTombstone(String id) async {
    try {
      await _deletedCol.doc(id).delete();
    } catch (e) {
      debugPrint('[Firestore] removeTombstone failed: $e');
    }
  }
}
