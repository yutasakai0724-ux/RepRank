import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// ── 筋肉部位 ──────────────────────────────────────────────────────
enum MuscleGroup { all, chest, back, legs, shoulders, arms, abs }

extension MuscleGroupLabel on MuscleGroup {
  String get label {
    switch (this) {
      case MuscleGroup.all:       return 'ALL';
      case MuscleGroup.chest:     return '胸';
      case MuscleGroup.back:      return '背中';
      case MuscleGroup.legs:      return '脚';
      case MuscleGroup.shoulders: return '肩';
      case MuscleGroup.arms:      return '腕';
      case MuscleGroup.abs:       return '腹筋';
    }
  }
}

// ── セット ────────────────────────────────────────────────────────
class WorkoutSet {
  final String id;
  int setNumber;
  double weight;
  int reps;
  DateTime? recordedAt;

  WorkoutSet({
    String? id,
    required this.setNumber,
    this.weight = 0.0,
    this.reps = 0,
    this.recordedAt,
  }) : id = id ?? _uuid.v4();

  double get oneRM {
    if (reps <= 0) return weight;
    return weight * reps / 40 + weight;
  }

  double get weightInLbs => weight * 2.20462;

  Map<String, dynamic> toJson() => {
    'id': id,
    'setNumber': setNumber,
    'weight': weight,
    'reps': reps,
    'recordedAt': recordedAt?.toIso8601String(),
  };

  factory WorkoutSet.fromJson(Map<String, dynamic> j) => WorkoutSet(
    id: j['id'] as String?,
    setNumber: j['setNumber'] as int,
    weight: (j['weight'] as num).toDouble(),
    reps: j['reps'] as int,
    recordedAt: j['recordedAt'] != null
        ? DateTime.parse(j['recordedAt'] as String)
        : null,
  );
}

// ── 種目 ──────────────────────────────────────────────────────────
class Exercise {
  final String id;
  String name;
  MuscleGroup muscleGroup;
  List<WorkoutSet> sets;

  Exercise({
    String? id,
    required this.name,
    required this.muscleGroup,
    List<WorkoutSet>? sets,
  }) : id = id ?? _uuid.v4(),
       sets = sets ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscleGroup': muscleGroup.name,
    'sets': sets.map((s) => s.toJson()).toList(),
  };

  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
    id: j['id'] as String?,
    name: j['name'] as String,
    muscleGroup: MuscleGroup.values.firstWhere(
      (g) => g.name == j['muscleGroup'],
      orElse: () => MuscleGroup.chest,
    ),
    sets: (j['sets'] as List)
        .map((s) => WorkoutSet.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
}

// ── セッション ────────────────────────────────────────────────────
class WorkoutSession {
  final String id;
  String? sessionName;
  String? routineName;
  DateTime date;
  DateTime startedAt;
  DateTime? finishedAt;
  List<Exercise> exercises;

  WorkoutSession({
    String? id,
    this.sessionName,
    this.routineName,
    required this.date,
    required this.startedAt,
    this.finishedAt,
    List<Exercise>? exercises,
  }) : id = id ?? _uuid.v4(),
       exercises = exercises ?? [];

  /// 所要時間（終了していれば確定値、途中なら現在時刻から算出）
  Duration get duration {
    final end = finishedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  /// トータルボリューム (kg)
  double get totalVolume => exercises.fold(
    0.0,
    (sum, ex) => sum + ex.sets.fold(0.0, (s, set) => s + set.weight * set.reps),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sessionName': sessionName,
    'routineName': routineName,
    'date': date.toIso8601String(),
    'startedAt': startedAt.toIso8601String(),
    'finishedAt': finishedAt?.toIso8601String(),
    'exercises': exercises.map((e) => e.toJson()).toList(),
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> j) => WorkoutSession(
    id: j['id'] as String?,
    sessionName: j['sessionName'] as String?,
    routineName: j['routineName'] as String?,
    date: DateTime.parse(j['date'] as String),
    startedAt: DateTime.parse(j['startedAt'] as String),
    finishedAt: j['finishedAt'] != null
        ? DateTime.parse(j['finishedAt'] as String)
        : null,
    exercises: (j['exercises'] as List)
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

// ── デフォルト種目リスト ───────────────────────────────────────────
final List<Map<String, dynamic>> defaultExercises = [
  {'name': 'ベンチプレス',      'group': MuscleGroup.chest},
  {'name': 'ダンベルフライ',    'group': MuscleGroup.chest},
  {'name': 'インクラインプレス', 'group': MuscleGroup.chest},
  {'name': 'デッドリフト',      'group': MuscleGroup.back},
  {'name': '懸垂',              'group': MuscleGroup.back},
  {'name': 'ラットプルダウン',  'group': MuscleGroup.back},
  {'name': 'スクワット',        'group': MuscleGroup.legs},
  {'name': 'レッグプレス',      'group': MuscleGroup.legs},
  {'name': 'レッグカール',      'group': MuscleGroup.legs},
  {'name': 'ショルダープレス',  'group': MuscleGroup.shoulders},
  {'name': 'サイドレイズ',      'group': MuscleGroup.shoulders},
  {'name': 'バーベルカール',    'group': MuscleGroup.arms},
  {'name': 'トライセプス',      'group': MuscleGroup.arms},
  {'name': 'クランチ',          'group': MuscleGroup.abs},
  {'name': 'プランク',          'group': MuscleGroup.abs},
];
