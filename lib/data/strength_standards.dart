import 'package:flutter/material.dart';
import '../theme.dart';

// ── レベル定義 ──────────────────────────────────────────────────
enum StrengthTier { beginner, novice, intermediate, advanced, elite }

extension StrengthTierExt on StrengthTier {
  String get label {
    switch (this) {
      case StrengthTier.beginner:     return '初心者';
      case StrengthTier.novice:       return '初級';
      case StrengthTier.intermediate: return '中級';
      case StrengthTier.advanced:     return '上級';
      case StrengthTier.elite:        return 'エリート';
    }
  }

  Color get color {
    switch (this) {
      case StrengthTier.beginner:     return const Color(0xFF6B7280);
      case StrengthTier.novice:       return kSecondary;
      case StrengthTier.intermediate: return kTertiary;
      case StrengthTier.advanced:     return kPrimary;
      case StrengthTier.elite:        return const Color(0xFFFFD700);
    }
  }
}

// ── ExRx 基準 (体重倍率, 男性) ──────────────────────────────────
// 各リスト: [初心者, 初級, 中級, 上級, エリート]
const Map<String, List<double>> _exrxStandards = {
  'ベンチプレス':      [0.50, 0.75, 1.25, 1.75, 2.00],
  'インクラインプレス': [0.40, 0.65, 1.00, 1.40, 1.65],
  'スクワット':        [0.75, 1.25, 1.50, 2.00, 2.50],
  'デッドリフト':      [1.00, 1.50, 2.00, 2.50, 3.00],
  'ショルダープレス':  [0.35, 0.55, 0.80, 1.10, 1.35],
  '懸垂':             [0.40, 0.65, 1.00, 1.35, 1.60],
  'ラットプルダウン':  [0.50, 0.65, 0.85, 1.10, 1.30],
  'バーベルカール':    [0.25, 0.40, 0.60, 0.85, 1.05],
  'レッグプレス':      [1.00, 1.50, 2.25, 3.00, 3.50],
  'レッグカール':      [0.25, 0.40, 0.65, 0.90, 1.10],
};

// 部位別フォールバック倍率
const Map<String, List<double>> _fallbackByGroup = {
  '胸':   [0.45, 0.70, 1.10, 1.60, 1.90],
  '背中':  [0.50, 0.70, 1.00, 1.40, 1.70],
  '脚':   [0.80, 1.30, 1.80, 2.30, 2.80],
  '肩':   [0.30, 0.50, 0.75, 1.00, 1.25],
  '腕':   [0.20, 0.35, 0.55, 0.75, 0.95],
  '腹筋':  [0.20, 0.30, 0.45, 0.60, 0.75],
};

// ── 結果型 ───────────────────────────────────────────────────────
class StrengthResult {
  final StrengthTier tier;
  final double oneRM;
  final double bodyWeight;
  final List<double> thresholds; // kg
  final String exerciseName;

  const StrengthResult({
    required this.tier,
    required this.oneRM,
    required this.bodyWeight,
    required this.thresholds,
    required this.exerciseName,
  });

  /// 次のレベルの閾値。エリートなら null
  double? get nextThreshold {
    final idx = tier.index;
    if (idx >= thresholds.length - 1) return null;
    return thresholds[idx + 1];
  }

  /// 現在レベル下限
  double get currentFloor => tier.index == 0 ? 0 : thresholds[tier.index - 1];

  /// 現在レベル内での進捗 0.0〜1.0
  double get progressInTier {
    final next = nextThreshold;
    if (next == null) return 1.0;
    final floor = currentFloor;
    if (next <= floor) return 1.0;
    return ((oneRM - floor) / (next - floor)).clamp(0.0, 1.0);
  }
}

// ── 評価関数 ─────────────────────────────────────────────────────
StrengthResult evaluate({
  required String exerciseName,
  required String muscleGroupLabel,
  required double oneRM,
  required double bodyWeight,
}) {
  final multipliers = _exrxStandards[exerciseName] ??
      _fallbackByGroup[muscleGroupLabel] ??
      [0.40, 0.65, 1.00, 1.40, 1.70];

  final thresholds = multipliers.map((m) => m * bodyWeight).toList();

  StrengthTier tier = StrengthTier.beginner;
  for (int i = thresholds.length - 1; i >= 0; i--) {
    if (oneRM >= thresholds[i]) {
      tier = StrengthTier.values[i];
      break;
    }
  }

  return StrengthResult(
    tier: tier,
    oneRM: oneRM,
    bodyWeight: bodyWeight,
    thresholds: thresholds,
    exerciseName: exerciseName,
  );
}
