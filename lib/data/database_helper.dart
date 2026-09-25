import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

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
      version: 3,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE sessions (
            id          TEXT PRIMARY KEY,
            session_name TEXT,
            routine_name TEXT,
            date        TEXT NOT NULL,
            started_at  TEXT NOT NULL,
            finished_at TEXT,
            exercises_json TEXT NOT NULL DEFAULT '[]',
            body_weight_kg REAL,
            updated_at  TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE sessions ADD COLUMN body_weight_kg REAL');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE sessions ADD COLUMN updated_at TEXT');
        }
      },
    );
  }
}
