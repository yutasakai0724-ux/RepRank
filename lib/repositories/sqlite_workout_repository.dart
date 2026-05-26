import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../models/workout.dart';
import '../data/database_helper.dart';
import 'workout_repository.dart';

/// SQLite を使った WorkoutRepository 実装。
///
/// Firebase 移行時の対応:
///   1. このファイルを FirestoreWorkoutRepository に差し替える
///   2. main.dart の初期化を差し替えるだけ — 画面・SessionManager は変更不要
class SqliteWorkoutRepository implements WorkoutRepository {
  final DatabaseHelper _helper;
  SqliteWorkoutRepository(this._helper);

  @override
  Future<List<WorkoutSession>> getAllSessions() async {
    final db = await _helper.database;
    final rows = await db.query('sessions', orderBy: 'started_at DESC');
    return rows.map(_fromRow).toList();
  }

  @override
  Future<List<WorkoutSession>> getSessionsForDate(DateTime date) async {
    final db = await _helper.database;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.query(
      'sessions',
      where: 'date = ?',
      whereArgs: [dateStr],
      orderBy: 'started_at ASC',
    );
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> upsertSession(WorkoutSession session) async {
    final db = await _helper.database;
    await db.insert(
      'sessions',
      _toRow(session),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteSession(String id) async {
    final db = await _helper.database;
    await db.delete('sessions', where: 'id = ?', whereArgs: [id]);
  }

  // ── 変換ヘルパー ───────────────────────────────────────────────

  WorkoutSession _fromRow(Map<String, dynamic> row) {
    final exList = jsonDecode(row['exercises_json'] as String) as List;
    return WorkoutSession(
      id: row['id'] as String,
      sessionName: row['session_name'] as String?,
      routineName: row['routine_name'] as String?,
      date: DateTime.parse(row['date'] as String),
      startedAt: DateTime.parse(row['started_at'] as String),
      finishedAt: row['finished_at'] != null
          ? DateTime.parse(row['finished_at'] as String)
          : null,
      exercises: exList
          .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> _toRow(WorkoutSession s) => {
    'id': s.id,
    'session_name': s.sessionName,
    'routine_name': s.routineName,
    'date': s.date.toIso8601String().substring(0, 10),
    'started_at': s.startedAt.toIso8601String(),
    'finished_at': s.finishedAt?.toIso8601String(),
    'exercises_json':
        jsonEncode(s.exercises.map((e) => e.toJson()).toList()),
  };
}
