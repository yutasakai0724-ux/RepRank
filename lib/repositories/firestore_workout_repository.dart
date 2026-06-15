import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/workout.dart';
import 'workout_repository.dart';

/// Firestore を使った WorkoutRepository 実装。
/// ユーザーデータは `users/{uid}/sessions/{sessionId}` に保存する。
class FirestoreWorkoutRepository implements WorkoutRepository {
  final String uid;
  FirestoreWorkoutRepository(this.uid);

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('sessions');

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

  @override
  Future<void> deleteSession(String id) async {
    try {
      await _col.doc(id).delete();
    } catch (e) {
      debugPrint('[Firestore] deleteSession failed: $e');
    }
  }
}
