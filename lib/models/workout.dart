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
  String? memo;

  WorkoutSet({
    String? id,
    required this.setNumber,
    this.weight = 0.0,
    this.reps = 0,
    this.recordedAt,
    this.memo,
  }) : id = id ?? _uuid.v4();

  double get oneRM {
    if (reps <= 1) return weight;
    return weight * reps / 40 + weight;
  }

  double get weightInLbs => weight * 2.20462;

  Map<String, dynamic> toJson() => {
    'id': id,
    'setNumber': setNumber,
    'weight': weight,
    'reps': reps,
    'recordedAt': recordedAt?.toIso8601String(),
    'memo': memo,
  };

  factory WorkoutSet.fromJson(Map<String, dynamic> j) => WorkoutSet(
    id: j['id'] as String?,
    setNumber: j['setNumber'] as int,
    weight: (j['weight'] as num).toDouble(),
    reps: j['reps'] as int,
    recordedAt: j['recordedAt'] != null
        ? DateTime.parse(j['recordedAt'] as String)
        : null,
    memo: j['memo'] as String?,
  );
}

// ── 種目 ──────────────────────────────────────────────────────────
class Exercise {
  final String id;
  String name;
  MuscleGroup muscleGroup;
  List<WorkoutSet> sets;
  String? memo;

  Exercise({
    String? id,
    required this.name,
    required this.muscleGroup,
    List<WorkoutSet>? sets,
    this.memo,
  }) : id = id ?? _uuid.v4(),
       sets = sets ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscleGroup': muscleGroup.name,
    'sets': sets.map((s) => s.toJson()).toList(),
    'memo': memo,
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
    memo: j['memo'] as String?,
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
  double? bodyWeightKg;

  /// トレーニング時間（ストップウォッチの「トレーニング開始／終了」で記録、または手動編集）。
  /// startedAt / finishedAt（セッション作成・終了の内部的な時刻）とは別の値。
  DateTime? trainingStartedAt;
  DateTime? trainingEndedAt;

  /// 最終更新日時。ログイン時のクラウドとの同期で、新しい方を採用するために使う。
  DateTime? updatedAt;

  WorkoutSession({
    String? id,
    this.sessionName,
    this.routineName,
    required this.date,
    required this.startedAt,
    this.finishedAt,
    List<Exercise>? exercises,
    this.bodyWeightKg,
    this.trainingStartedAt,
    this.trainingEndedAt,
    this.updatedAt,
  }) : id = id ?? _uuid.v4(),
       exercises = exercises ?? [];

  /// 所要時間（終了していれば確定値、途中なら現在時刻から算出）
  Duration get duration {
    final end = finishedAt ?? DateTime.now();
    return end.difference(startedAt);
  }

  /// 記録されたトレーニング時間。開始・終了の両方があるときだけ値を返す。
  Duration? get trainingDuration {
    final s = trainingStartedAt, e = trainingEndedAt;
    if (s == null || e == null || e.isBefore(s)) return null;
    return e.difference(s);
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
    'bodyWeightKg': bodyWeightKg,
    'trainingStartedAt': trainingStartedAt?.toIso8601String(),
    'trainingEndedAt': trainingEndedAt?.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
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
    bodyWeightKg: (j['bodyWeightKg'] as num?)?.toDouble(),
    trainingStartedAt: j['trainingStartedAt'] != null
        ? DateTime.parse(j['trainingStartedAt'] as String)
        : null,
    trainingEndedAt: j['trainingEndedAt'] != null
        ? DateTime.parse(j['trainingEndedAt'] as String)
        : null,
    updatedAt: j['updatedAt'] != null
        ? DateTime.parse(j['updatedAt'] as String)
        : null,
  );
}

// ── デフォルト種目リスト ───────────────────────────────────────────
final List<Map<String, dynamic>> defaultExercises = [
  // 胸
  {'name': 'ベンチプレス',              'group': MuscleGroup.chest},
  {'name': 'インクラインベンチプレス',  'group': MuscleGroup.chest},
  {'name': 'デクラインベンチプレス',    'group': MuscleGroup.chest},
  {'name': 'ダンベルベンチプレス',      'group': MuscleGroup.chest},
  {'name': 'ダンベルフライ',            'group': MuscleGroup.chest},
  {'name': 'インクラインダンベルフライ','group': MuscleGroup.chest},
  {'name': 'ケーブルクロスオーバー',    'group': MuscleGroup.chest},
  {'name': 'チェストプレス（マシン）',  'group': MuscleGroup.chest},
  {'name': 'ペックデック',              'group': MuscleGroup.chest},
  {'name': 'ディップス',                'group': MuscleGroup.chest},
  {'name': 'プッシュアップ',            'group': MuscleGroup.chest},

  // 背中
  {'name': 'デッドリフト',              'group': MuscleGroup.back},
  {'name': 'ルーマニアンデッドリフト',  'group': MuscleGroup.back},
  {'name': '懸垂',                      'group': MuscleGroup.back},
  {'name': 'チンニング',                'group': MuscleGroup.back},
  {'name': 'ラットプルダウン',          'group': MuscleGroup.back},
  {'name': 'シーテッドケーブルロウ',    'group': MuscleGroup.back},
  {'name': 'ベントオーバーロウ',        'group': MuscleGroup.back},
  {'name': 'ダンベルロウ',              'group': MuscleGroup.back},
  {'name': 'Tバーロウ',                 'group': MuscleGroup.back},
  {'name': 'チェストサポートロウ',      'group': MuscleGroup.back},
  {'name': 'シュラッグ',                'group': MuscleGroup.back},
  {'name': 'フェイスプル',              'group': MuscleGroup.back},

  // 脚
  {'name': 'スクワット',                'group': MuscleGroup.legs},
  {'name': 'フロントスクワット',        'group': MuscleGroup.legs},
  {'name': 'ゴブレットスクワット',      'group': MuscleGroup.legs},
  {'name': 'レッグプレス',              'group': MuscleGroup.legs},
  {'name': 'レッグカール',              'group': MuscleGroup.legs},
  {'name': 'レッグエクステンション',    'group': MuscleGroup.legs},
  {'name': 'ブルガリアンスプリットスクワット', 'group': MuscleGroup.legs},
  {'name': 'ランジ',                    'group': MuscleGroup.legs},
  {'name': 'ヒップスラスト',            'group': MuscleGroup.legs},
  {'name': 'カーフレイズ',              'group': MuscleGroup.legs},
  {'name': 'シーテッドカーフレイズ',    'group': MuscleGroup.legs},
  {'name': 'ハックスクワット',          'group': MuscleGroup.legs},

  // 肩
  {'name': 'ショルダープレス',          'group': MuscleGroup.shoulders},
  {'name': 'ダンベルショルダープレス',  'group': MuscleGroup.shoulders},
  {'name': 'アーノルドプレス',          'group': MuscleGroup.shoulders},
  {'name': 'サイドレイズ',              'group': MuscleGroup.shoulders},
  {'name': 'フロントレイズ',            'group': MuscleGroup.shoulders},
  {'name': 'リアデルト（ダンベル）',    'group': MuscleGroup.shoulders},
  {'name': 'リアデルト（マシン）',      'group': MuscleGroup.shoulders},
  {'name': 'アップライトロウ',          'group': MuscleGroup.shoulders},

  // 腕
  {'name': 'バーベルカール',            'group': MuscleGroup.arms},
  {'name': 'ダンベルカール',            'group': MuscleGroup.arms},
  {'name': 'インクラインダンベルカール','group': MuscleGroup.arms},
  {'name': 'ハンマーカール',            'group': MuscleGroup.arms},
  {'name': 'プリーチャーカール',        'group': MuscleGroup.arms},
  {'name': 'ケーブルカール',            'group': MuscleGroup.arms},
  {'name': 'トライセプスプッシュダウン','group': MuscleGroup.arms},
  {'name': 'オーバーヘッドトライセプス','group': MuscleGroup.arms},
  {'name': 'スカルクラッシャー',        'group': MuscleGroup.arms},
  {'name': 'クローズグリップベンチ',    'group': MuscleGroup.arms},
  {'name': 'リバースディップス',        'group': MuscleGroup.arms},

  // 腹筋
  {'name': 'クランチ',                  'group': MuscleGroup.abs},
  {'name': 'シットアップ',              'group': MuscleGroup.abs},
  {'name': 'レッグレイズ',              'group': MuscleGroup.abs},
  {'name': 'ハンギングレッグレイズ',    'group': MuscleGroup.abs},
  {'name': 'プランク',                  'group': MuscleGroup.abs},
  {'name': 'サイドプランク',            'group': MuscleGroup.abs},
  {'name': 'ロシアンツイスト',          'group': MuscleGroup.abs},
  {'name': 'アブローラー',              'group': MuscleGroup.abs},
  {'name': 'ケーブルクランチ',          'group': MuscleGroup.abs},
  {'name': 'バイシクルクランチ',        'group': MuscleGroup.abs},
];
