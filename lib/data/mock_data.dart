import '../models/workout.dart';

// ── シードデータ（初回インストール時に DB へ投入） ─────────────────────────
// 日付は「今日から N 日前」の相対指定にすることで
// インストール日に関わらず自然なデモ履歴が表示される。

/// 今日から [daysAgo] 日前の DateTime を返す
DateTime _daysAgo(int daysAgo, {int hour = 8, int minute = 0}) {
  final d = DateTime.now().subtract(Duration(days: daysAgo));
  return DateTime(d.year, d.month, d.day, hour, minute);
}

/// 初回起動時に DB へ投入するデモセッション
List<WorkoutSession> loadSessionsForDate(DateTime d) {
  final d7  = DateTime.now().subtract(const Duration(days: 7));
  final d14 = DateTime.now().subtract(const Duration(days: 14));

  final match7  = d.year == d7.year  && d.month == d7.month  && d.day == d7.day;
  final match14 = d.year == d14.year && d.month == d14.month && d.day == d14.day;

  if (match7) {
    return [
      WorkoutSession(
        sessionName: 'プッシュデイ B',
        routineName: '胸の日',
        date: DateTime(d.year, d.month, d.day),
        startedAt: _daysAgo(7, hour: 8, minute: 15),
        finishedAt: _daysAgo(7, hour: 9, minute: 19),
        exercises: [
          Exercise(name: 'ベンチプレス', muscleGroup: MuscleGroup.chest, sets: [
            WorkoutSet(setNumber: 1, weight: 80, reps: 10),
            WorkoutSet(setNumber: 2, weight: 82.5, reps: 8),
            WorkoutSet(setNumber: 3, weight: 82.5, reps: 7),
          ]),
          Exercise(name: 'ショルダープレス', muscleGroup: MuscleGroup.shoulders, sets: [
            WorkoutSet(setNumber: 1, weight: 50, reps: 10),
            WorkoutSet(setNumber: 2, weight: 50, reps: 10),
          ]),
          Exercise(name: 'サイドレイズ', muscleGroup: MuscleGroup.shoulders, sets: [
            WorkoutSet(setNumber: 1, weight: 12, reps: 15),
            WorkoutSet(setNumber: 2, weight: 12, reps: 15),
            WorkoutSet(setNumber: 3, weight: 10, reps: 15),
          ]),
        ],
      ),
    ];
  }
  if (match14) {
    return [
      WorkoutSession(
        sessionName: 'プル&レッグデイ',
        routineName: null,
        date: DateTime(d.year, d.month, d.day),
        startedAt: _daysAgo(14, hour: 9, minute: 0),
        finishedAt: _daysAgo(14, hour: 10, minute: 15),
        exercises: [
          Exercise(name: 'デッドリフト', muscleGroup: MuscleGroup.back, sets: [
            WorkoutSet(setNumber: 1, weight: 100, reps: 5),
            WorkoutSet(setNumber: 2, weight: 110, reps: 5),
            WorkoutSet(setNumber: 3, weight: 110, reps: 4),
          ]),
          Exercise(name: 'スクワット', muscleGroup: MuscleGroup.legs, sets: [
            WorkoutSet(setNumber: 1, weight: 80, reps: 8),
            WorkoutSet(setNumber: 2, weight: 85, reps: 6),
          ]),
          Exercise(name: 'ラットプルダウン', muscleGroup: MuscleGroup.back, sets: [
            WorkoutSet(setNumber: 1, weight: 60, reps: 10),
            WorkoutSet(setNumber: 2, weight: 60, reps: 10),
            WorkoutSet(setNumber: 3, weight: 55, reps: 10),
          ]),
        ],
      ),
    ];
  }
  return [];
}

/// シード対象日リスト（DatabaseHelper から参照）
List<DateTime> get seedDates => [
  DateTime.now().subtract(const Duration(days: 7)),
  DateTime.now().subtract(const Duration(days: 14)),
];
