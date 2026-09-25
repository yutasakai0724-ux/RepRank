import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';
import '../models/workout.dart';
import '../data/strength_standards.dart';
import '../services/session_manager.dart';
import '../services/user_preferences.dart';
import '../utils/time_format.dart';
import 'exercise_record_screen.dart';

class ExerciseAnalysisScreen extends StatefulWidget {
  final Exercise exercise;
  final double currentOneRM;

  const ExerciseAnalysisScreen({
    super.key,
    required this.exercise,
    required this.currentOneRM,
  });

  @override
  State<ExerciseAnalysisScreen> createState() =>
      _ExerciseAnalysisScreenState();
}

class _ExerciseAnalysisScreenState extends State<ExerciseAnalysisScreen> {
  double _bodyWeight = 70.0;
  String _gender = '男性';
  late StrengthResult _result;
  List<_RMPoint> _history = [];
  List<_VolumePoint> _volumeHistory = [];
  bool _historyExpanded = false;

  static const int _historyCollapsedCount = 5;

  @override
  void initState() {
    super.initState();
    _loadBodyWeight();
  }

  Future<void> _loadBodyWeight() async {
    final weight = await UserPreferences.instance.getBodyWeight();
    final gender = await UserPreferences.instance.getGender();
    if (mounted) {
      setState(() {
        _bodyWeight = weight;
        _gender = gender;
        _recalculate();
      });
    }
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    final sessions = await SessionManager.instance.getAllSessions();
    final Map<String, double> byDate = {};
    final Map<String, double?> bwByDate = {};
    final Map<String, double> volByDate = {};
    final Map<String, DateTime> dateTimeByDate = {};
    final Map<String, int> setCountByDate = {};
    final Map<String, String> sessionIdByDate = {};
    final Map<String, Exercise> exerciseByDate = {};
    for (final s in sessions) {
      final dateKey = formatYMD(s.date);
      dateTimeByDate[dateKey] = s.date;
      for (final ex in s.exercises) {
        if (ex.name != widget.exercise.name) continue;
        if (ex.sets.isEmpty) continue;
        final maxRM = ex.sets.map((s) => s.oneRM).reduce((a, b) => a > b ? a : b);
        if (maxRM > (byDate[dateKey] ?? 0)) {
          byDate[dateKey] = maxRM;
          bwByDate[dateKey] = s.bodyWeightKg;
          setCountByDate[dateKey] = ex.sets.length;
          sessionIdByDate[dateKey] = s.id;
          exerciseByDate[dateKey] = ex;
        }
        final vol = ex.sets.fold(0.0, (sum, s) => sum + s.weight * s.reps);
        volByDate[dateKey] = (volByDate[dateKey] ?? 0) + vol;
      }
    }
    final points = byDate.entries
        .map((e) => _RMPoint(
              date: e.key,
              dateTime: dateTimeByDate[e.key]!,
              oneRM: e.value,
              setCount: setCountByDate[e.key] ?? 0,
              sessionBodyWeightKg: bwByDate[e.key],
              sessionId: sessionIdByDate[e.key]!,
              exercise: exerciseByDate[e.key]!,
            ))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    final volPoints = volByDate.entries
        .map((e) => _VolumePoint(date: e.key, volume: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (mounted) {
      setState(() {
        _history = points;
        _volumeHistory = volPoints;
      });
    }
  }

  void _recalculate() {
    _result = evaluate(
      exerciseName: widget.exercise.name,
      muscleGroupLabel: widget.exercise.muscleGroup.label,
      oneRM: widget.currentOneRM,
      bodyWeight: _bodyWeight,
      isFemale: _gender == '女性',
    );
  }

  void _editBodyWeight() {
    final ctrl =
        TextEditingController(text: _bodyWeight.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cCardLow,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('体重を設定',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: context.cText)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.inter(color: context.cText),
          decoration: InputDecoration(
            suffixText: 'kg',
            suffixStyle: GoogleFonts.jetBrainsMono(color: context.cTextSub),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: context.cBorderSub)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: kPrimary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style: GoogleFonts.inter(color: context.cTextSub)),
          ),
          TextButton(
            onPressed: () async {
              final v = double.tryParse(ctrl.text);
              if (v != null && v > 0) {
                await UserPreferences.instance.setBodyWeight(v);
                if (mounted) {
                  setState(() {
                    _bodyWeight = v;
                    _recalculate();
                  });
                }
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text('保存',
                style: GoogleFonts.inter(
                    color: kPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        backgroundColor: context.cBg.withValues(alpha: 0.85),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: context.cText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.exercise.name,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: kPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              '強度分析',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 10, color: context.cTextSub),
            ),
          ],
        ),
        actions: [
          // 体重設定
          GestureDetector(
            onTap: _editBodyWeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_bodyWeight.toStringAsFixed(1)}kg',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.cText),
                  ),
                  Text(
                    '体重 ✎',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 9, color: context.cTextSub),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCurrentRM(),
          const SizedBox(height: 16),
          _buildHistoryList(),
          const SizedBox(height: 16),
          _buildLevelBar(),
          const SizedBox(height: 16),
          _buildNextGoalCard(),
          const SizedBox(height: 16),
          _buildThresholdTable(),
          const SizedBox(height: 16),
          _buildHistoryChart(),
          const SizedBox(height: 16),
          _buildRatioChart(),
          const SizedBox(height: 16),
          _buildVolumeChart(),
          const SizedBox(height: 16),
          _buildHistogram(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ── 現在の1RM ────────────────────────────────────────────────
  Widget _buildCurrentRM() {
    final tier = _result.tier;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: tier.colorForContext(context).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '現在の推定1RM',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: context.cTextSub,
                      letterSpacing: 1),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      widget.currentOneRM.toStringAsFixed(1),
                      style: GoogleFonts.inter(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: context.cText,
                        letterSpacing: -2,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'kg',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 16, color: context.cTextSub),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '体重比 ${(_result.oneRM / _bodyWeight).toStringAsFixed(2)}x',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 11, color: context.cTextSub),
                ),
              ],
            ),
          ),
          // レベルバッジ
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: tier.colorForContext(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tier.colorForContext(context).withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(_tierIcon(tier), color: tier.colorForContext(context), size: 28),
                const SizedBox(height: 6),
                Text(
                  tier.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: tier.colorForContext(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 過去の記録一覧 ───────────────────────────────────────────
  Widget _buildHistoryList() {
    if (_history.isEmpty) return const SizedBox.shrink();

    // 新しい順に並べ替え
    final sorted = List<_RMPoint>.from(_history)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final bestOneRM =
        sorted.map((p) => p.oneRM).reduce((a, b) => a > b ? a : b);
    final visible = _historyExpanded
        ? sorted
        : sorted.take(_historyCollapsedCount).toList();
    final hasMore = sorted.length > _historyCollapsedCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '過去の記録',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.cTextSub,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          for (final p in visible) _buildHistoryRow(p, isBest: p.oneRM == bestOneRM),
          if (hasMore)
            GestureDetector(
              onTap: () => setState(() => _historyExpanded = !_historyExpanded),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Center(
                  child: Text(
                    _historyExpanded
                        ? '閉じる'
                        : 'もっと見る（他 ${sorted.length - _historyCollapsedCount} 件）',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kPrimary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(_RMPoint p, {required bool isBest}) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExerciseRecordScreen(
            exercise: p.exercise,
            sessionId: p.sessionId,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isBest
              ? kTertiary.withValues(alpha: 0.1)
              : context.cCardHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: isBest
              ? Border.all(color: kTertiary.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          children: [
            if (isBest) ...[
              const Icon(Icons.star, size: 14, color: kTertiary),
              const SizedBox(width: 6),
            ],
            Expanded(
              flex: 3,
              child: Text(
                formatJpDate(p.dateTime),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.cText,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${p.setCount}セット',
                textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: context.cTextSub,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${p.oneRM.toStringAsFixed(1)}kg',
                textAlign: TextAlign.right,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isBest ? kTertiary : kPrimaryLight,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: context.cBorder),
          ],
        ),
      ),
    );
  }

  // ── レベルバー ───────────────────────────────────────────────
  Widget _buildLevelBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'レベル進捗',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 10, color: context.cTextSub, letterSpacing: 1),
          ),
          const SizedBox(height: 14),
          // セグメントバー
          Row(
            children: StrengthTier.values.map((t) {
              final isActive = t.index <= _result.tier.index;
              final isCurrent = t == _result.tier;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? t.colorForContext(context).withValues(alpha: isCurrent ? 1.0 : 0.5)
                        : context.cCardHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // ラベル
          Row(
            children: StrengthTier.values.map((t) {
              final isCurrent = t == _result.tier;
              return Expanded(
                child: Text(
                  t.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: isCurrent
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: isCurrent ? t.colorForContext(context) : context.cTextSub,
                  ),
                ),
              );
            }).toList(),
          ),
          // 現在レベル内プログレス
          if (_result.tier != StrengthTier.elite) ...[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_result.tier.label} 内の進捗',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 10, color: context.cTextSub),
                ),
                Text(
                  '${(_result.progressInTier * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _result.tier.colorForContext(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _result.progressInTier,
                minHeight: 6,
                backgroundColor: context.cCardHigh,
                valueColor:
                    AlwaysStoppedAnimation(_result.tier.colorForContext(context)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── 次の目標 ─────────────────────────────────────────────────
  Widget _buildNextGoalCard() {
    final next = _result.nextThreshold;
    if (next == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events,
                color: Color(0xFFFFD700), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'エリート達成！',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFFD700),
                    ),
                  ),
                  Text(
                    '最高ランクに到達しています',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 11, color: context.cTextSub),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final diff = next - _result.oneRM;
    final nextTier =
        StrengthTier.values[_result.tier.index + 1];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: nextTier.colorForContext(context).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: nextTier.colorForContext(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.flag_outlined,
                color: nextTier.colorForContext(context), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '次の目標：${nextTier.label}',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: context.cTextSub,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      next.toStringAsFixed(1),
                      style: GoogleFonts.inter(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: nextTier.colorForContext(context),
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3, left: 4),
                      child: Text('kg',
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              color: context.cTextSub)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: nextTier.colorForContext(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '+${diff.toStringAsFixed(1)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: nextTier.colorForContext(context),
                  ),
                ),
                Text('kg 必要',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 9, color: context.cTextSub)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 全レベル閾値テーブル ─────────────────────────────────────
  Widget _buildThresholdTable() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'レベル別基準（体重 ${_bodyWeight.toStringAsFixed(0)}kg）',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 10, color: context.cTextSub, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          ...StrengthTier.values.asMap().entries.map((entry) {
            final t = entry.value;
            final threshold = _result.thresholds[entry.key];
            final isCurrent = t == _result.tier;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrent
                    ? t.colorForContext(context).withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCurrent
                      ? t.colorForContext(context).withValues(alpha: 0.25)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(_tierIcon(t),
                      size: 16,
                      color: isCurrent ? t.colorForContext(context) : context.cTextSub),
                  const SizedBox(width: 10),
                  Text(
                    t.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w400,
                      color: isCurrent ? t.colorForContext(context) : context.cTextSub,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${threshold.toStringAsFixed(1)} kg',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w400,
                      color: isCurrent ? t.colorForContext(context) : context.cTextSub,
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: t.colorForContext(context).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'NOW',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: t.colorForContext(context)),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── 強度基準ヒストグラム ────────────────────────────────────────
  Widget _buildHistogram() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '強度分布ヒストグラム',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 10, color: context.cTextSub, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            'ユーザーデータによる体重比分布',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                color: context.cTextSub.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          _buildComingSoon(),
        ],
      ),
    );
  }

  Widget _buildComingSoon() {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 28,
                color: context.cTextSub.withValues(alpha: 0.2)),
            const SizedBox(height: 10),
            Text(
              'Coming Soon',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.cTextSub.withValues(alpha: 0.4),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ユーザーデータ収集後に公開予定',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  color: context.cTextSub.withValues(alpha: 0.28)),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1RM 推移グラフ ──────────────────────────────────────────
  Widget _buildHistoryChart() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1RM 推移',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 10, color: context.cTextSub, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          if (_history.length < 2)
            Container(
              height: 100,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.show_chart,
                      size: 32,
                      color: context.cTextSub.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  Text(
                    _history.isEmpty
                        ? 'データが蓄積されるとグラフが表示されます'
                        : 'あと ${2 - _history.length} 回記録するとグラフが表示されます',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 11, color: context.cTextSub),
                  ),
                ],
              ),
            )
          else
            _buildLineChart(),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    final spots = _history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.oneRM))
        .toList();

    final minY = (_history.map((p) => p.oneRM).reduce((a, b) => a < b ? a : b) * 0.9)
        .floorToDouble();
    final maxY = (_history.map((p) => p.oneRM).reduce((a, b) => a > b ? a : b) * 1.1)
        .ceilToDouble();

    return SizedBox(
      height: 160,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: (_history.length - 1).toDouble(),
          minY: minY,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.06),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 9, color: context.cTextSub),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: _history.length <= 6
                    ? 1
                    : (_history.length / 4).ceilToDouble(),
                getTitlesWidget: (v, _) {
                  final idx = v.toInt();
                  if (idx < 0 || idx >= _history.length) {
                    return const SizedBox.shrink();
                  }
                  final parts = _history[idx].date.split('-');
                  final label = '${parts[1]}/${parts[2]}';
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      label,
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 9, color: context.cTextSub),
                    ),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              curveSmoothness: 0.35,
              color: kPrimary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                  radius: 4,
                  color: kPrimary,
                  strokeWidth: 2,
                  strokeColor: context.cCardLow,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    kPrimary.withValues(alpha: 0.18),
                    kPrimary.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => context.cCardHigh,
              getTooltipItems: (spots) => spots
                  .map((s) => LineTooltipItem(
                        '${s.y.toStringAsFixed(1)}kg',
                        GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: kPrimary,
                        ),
                      ))
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  // ── 体重比推移グラフ ────────────────────────────────────────
  Widget _buildRatioChart() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '体重比推移（参考指標）',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 10, color: context.cTextSub, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            '1RM ÷ 体重 ${_bodyWeight.toStringAsFixed(0)}kg',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 9, color: context.cTextSub.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          if (_history.length < 2)
            _buildChartEmpty()
          else
            _buildRatioLineChart(),
        ],
      ),
    );
  }

  Widget _buildRatioLineChart() {
    final spots = _history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.oneRM / (e.value.sessionBodyWeightKg ?? _bodyWeight)))
        .toList();
    final minY = (spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.9);
    final maxY = (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.1);

    return SizedBox(
      height: 140,
      child: LineChart(LineChartData(
        minX: 0,
        maxX: (_history.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.white.withValues(alpha: 0.06), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(2),
                style: GoogleFonts.jetBrainsMono(fontSize: 9, color: context.cTextSub),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: _history.length <= 6 ? 1 : (_history.length / 4).ceilToDouble(),
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= _history.length) return const SizedBox.shrink();
                final parts = _history[idx].date.split('-');
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${parts[1]}/${parts[2]}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 9, color: context.cTextSub)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            curveSmoothness: 0.35,
            color: kSecondary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 4,
                color: kSecondary,
                strokeWidth: 2,
                strokeColor: context.cCardLow,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [kSecondary.withValues(alpha: 0.18), kSecondary.withValues(alpha: 0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => context.cCardHigh,
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${s.y.toStringAsFixed(2)}x',
                      GoogleFonts.jetBrainsMono(
                          fontSize: 11, fontWeight: FontWeight.w700, color: kSecondary),
                    ))
                .toList(),
          ),
        ),
      )),
    );
  }

  // ── 総ボリューム推移グラフ ──────────────────────────────────
  Widget _buildVolumeChart() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '総ボリューム推移',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 10, color: context.cTextSub, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          Text(
            '重量 × 回数 × セット数 (kg)',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 9, color: context.cTextSub.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          if (_volumeHistory.length < 2)
            _buildChartEmpty()
          else
            _buildVolumeLineChart(),
        ],
      ),
    );
  }

  Widget _buildVolumeLineChart() {
    final spots = _volumeHistory
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.volume))
        .toList();
    final minY = (spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) * 0.9);
    final maxY = (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.1);

    return SizedBox(
      height: 140,
      child: LineChart(LineChartData(
        minX: 0,
        maxX: (_volumeHistory.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.white.withValues(alpha: 0.06), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (v, _) => Text(
                v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}t' : '${v.toInt()}',
                style: GoogleFonts.jetBrainsMono(fontSize: 9, color: context.cTextSub),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: _volumeHistory.length <= 6 ? 1 : (_volumeHistory.length / 4).ceilToDouble(),
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= _volumeHistory.length) return const SizedBox.shrink();
                final parts = _volumeHistory[idx].date.split('-');
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${parts[1]}/${parts[2]}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 9, color: context.cTextSub)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            curveSmoothness: 0.35,
            color: kTertiary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 4,
                color: kTertiary,
                strokeWidth: 2,
                strokeColor: context.cCardLow,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [kTertiary.withValues(alpha: 0.18), kTertiary.withValues(alpha: 0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => context.cCardHigh,
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '${s.y >= 1000 ? (s.y / 1000).toStringAsFixed(1) + "t" : s.y.toStringAsFixed(0) + "kg"}',
                      GoogleFonts.jetBrainsMono(
                          fontSize: 11, fontWeight: FontWeight.w700, color: kTertiary),
                    ))
                .toList(),
          ),
        ),
      )),
    );
  }

  Widget _buildChartEmpty() {
    return SizedBox(
      height: 80,
      child: Center(
        child: Text(
          'データが蓄積されるとグラフが表示されます',
          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: context.cTextSub),
        ),
      ),
    );
  }

  IconData _tierIcon(StrengthTier t) {
    switch (t) {
      case StrengthTier.beginner:     return Icons.fitness_center;
      case StrengthTier.novice:       return Icons.trending_up;
      case StrengthTier.intermediate: return Icons.bolt;
      case StrengthTier.advanced:     return Icons.local_fire_department;
      case StrengthTier.elite:        return Icons.emoji_events;
    }
  }
}

class _RMPoint {
  final String date;
  final DateTime dateTime;
  final double oneRM;
  final int setCount;
  final double? sessionBodyWeightKg;
  final String sessionId;
  final Exercise exercise;
  const _RMPoint({
    required this.date,
    required this.dateTime,
    required this.oneRM,
    required this.setCount,
    required this.sessionId,
    required this.exercise,
    this.sessionBodyWeightKg,
  });
}

class _VolumePoint {
  final String date;
  final double volume;
  const _VolumePoint({required this.date, required this.volume});
}
