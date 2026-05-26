import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'mock_data.dart';

/// SQLite データベースの初期化・マイグレーション管理。
/// Firebase 移行時はこのクラスを削除し、
/// SqliteWorkoutRepository を FirestoreWorkoutRepository に差し替えるだけ。
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'reprank_v1.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE sessions (
            id          TEXT PRIMARY KEY,
            session_name TEXT,
            routine_name TEXT,
            date        TEXT NOT NULL,
            started_at  TEXT NOT NULL,
            finished_at TEXT,
            exercises_json TEXT NOT NULL DEFAULT '[]'
          )
        ''');
        // 初回起動時にデモデータを挿入
        await _seedDemoData(db);
      },
    );
  }

  Future<void> _seedDemoData(Database db) async {
    for (final d in seedDates) {
      for (final session in loadSessionsForDate(d)) {
        await db.insert('sessions', {
          'id': session.id,
          'session_name': session.sessionName,
          'routine_name': session.routineName,
          'date': session.date.toIso8601String().substring(0, 10),
          'started_at': session.startedAt.toIso8601String(),
          'finished_at': session.finishedAt?.toIso8601String(),
          'exercises_json':
              jsonEncode(session.exercises.map((e) => e.toJson()).toList()),
        });
      }
    }
  }
}
