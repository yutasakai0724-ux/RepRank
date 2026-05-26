import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme.dart';
import '../models/workout.dart';
import '../data/strength_standards.dart';
import '../services/session_manager.dart';
import '../services/user_preferences.dart';

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
  late StrengthResult _result;
  // 1RM 推移データ: {date → maxOneRM}
  List<_RMPoint> _history = [];

  @override
  void initState() {
    super.initState();
    _loadBodyWeight();
  }

  Future<void> _loadBodyWeight() async {
    final weight = await UserPreferences.instance.getBodyWeight();
    if (mounted) {
      setState(() {
        _bodyWeight = weight;
        _recalculate();
      });
    }
    await _loadHistory();
  }

  Future<void> _loadHistory() async {
    final sessions = await SessionManager.instance.getAllSessions();
    final Map<String, double> byDate = {};
    for (final s in sessions) {
      final dateKey =
          '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}';
      for (final ex in s.exercises) {
        if (ex.name != widget.exercise.name) continue;
        if (ex.sets.isEmpty) continue;
        final maxRM =
            ex.sets.map((s) => s.oneRM).reduce((a, b) => a > b ? a : b);
        byDate[dateKey] = maxRM > (byDate[dateKey] ?? 0) ? maxRM : byDate[dateKey]!;
      }
    }
    final points = byDate.entries
        .map((e) => _RMPoint(date: e.key, oneRM: e.value))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (mounted) setState(() => _history = points);
  }

  void _recalculate() {
    _result = evaluate(
      exerciseName: widget.exercise.name,
      muscleGroupLabel: widget.exercise.muscleGroup.label,
      oneRM: widget.currentOneRM,
      bodyWeight: _bodyWeight,
    );
  }

  void _editBodyWeight() {
    final ctrl =
        TextEditingController(text: _bodyWeight.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceContainerLow,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('体重を設定',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: kOnSurface)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.inter(color: kOnSurface),
          decoration: InputDecoration(
            suffixText: 'kg',
            suffixStyle: GoogleFonts.jetBrainsMono(color: kOnSurfaceVariant),
            enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: kOutlineVariant)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: kPrimary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style: GoogleFonts.inter(color: kOnSurfaceVariant)),
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
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface.withValues(alpha: 0.85),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kOnSurface),
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
                  fontSize: 10, color: kOnSurfaceVariant),
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
                        color: kOnSurface),
                  ),
                  Text(
                    '体重 ✎',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 9, color: kOnSurfaceVariant),
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
          _buildLevelBar(),
          const SizedBox(height: 16),
          _buildNextGoalCard(),
          const SizedBox(height: 16),
          _buildThresholdTable(),
          const SizedBox(height: 16),
          _buildHistoryChart(),
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
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: tier.color.withValues(alpha: 0.25)),
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
                      color: kOnSurfaceVariant,
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
                        color: kOnSurface,
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
                            fontSize: 16, color: kOnSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '体重比 ${(_result.oneRM / _bodyWeight).toStringAsFixed(2)}x',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 11, color: kOnSurfaceVariant),
                ),
              ],
            ),
          ),
          // レベルバッジ
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: tier.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tier.color.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(_tierIcon(tier), color: tier.color, size: 28),
                const SizedBox(height: 6),
                Text(
                  tier.label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: tier.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── レベルバー ───────────────────────────────────────────────
  Widget _buildLevelBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'レベル進捗',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 10, color: kOnSurfaceVariant, letterSpacing: 1),
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
                        ? t.color.withValues(alpha: isCurrent ? 1.0 : 0.5)
                        : kSurfaceContainerHigh,
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
                    color: isCurrent ? t.color : kOnSurfaceVariant,
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
                      fontSize: 10, color: kOnSurfaceVariant),
                ),
                Text(
                  '${(_result.progressInTier * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _result.tier.color,
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
                backgroundColor: kSurfaceContainerHigh,
                valueColor:
                    AlwaysStoppedAnimation(_result.tier.color),
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
                        fontSize: 11, color: kOnSurfaceVariant),
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
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: nextTier.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: nextTier.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.flag_outlined,
                color: nextTier.color, size: 22),
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
                      color: kOnSurfaceVariant,
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
                        color: nextTier.color,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3, left: 4),
                      child: Text('kg',
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              color: kOnSurfaceVariant)),
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
              color: nextTier.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  '+${diff.toStringAsFixed(1)}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: nextTier.color,
                  ),
                ),
                Text('kg 必要',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 9, color: kOnSurfaceVariant)),
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
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'レベル別基準（体重 ${_bodyWeight.toStringAsFixed(0)}kg）',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 10, color: kOnSurfaceVariant, letterSpacing: 1),
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
                    ? t.color.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCurrent
                      ? t.color.withValues(alpha: 0.25)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(_tierIcon(t),
                      size: 16,
                      color: isCurrent ? t.color : kOnSurfaceVariant),
                  const SizedBox(width: 10),
                  Text(
                    t.label,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w400,
                      color: isCurrent ? t.color : kOnSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${threshold.toStringAsFixed(1)} kg',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w400,
                      color: isCurrent ? t.color : kOnSurfaceVariant,
                    ),
                  ),
                  if (isCurrent) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: t.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'NOW',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: t.color),
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

  // ── 1RM 推移グラフ ──────────────────────────────────────────
  Widget _buildHistoryChart() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1RM 推移',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 10, color: kOnSurfaceVariant, letterSpacing: 1),
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
                      color: kOnSurfaceVariant.withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  Text(
                    _history.isEmpty
                        ? 'データが蓄積されるとグラフが表示されます'
                        : 'あと ${2 - _history.length} 回記録するとグラフが表示されます',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 11, color: kOnSurfaceVariant),
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
                      fontSize: 9, color: kOnSurfaceVariant),
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
                          fontSize: 9, color: kOnSurfaceVariant),
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
              isCurved: true,
              curveSmoothness: 0.35,
              color: kPrimary,
              barWidth: 2.5,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                  radius: 4,
                  color: kPrimary,
                  strokeWidth: 2,
                  strokeColor: kSurfaceContainerLow,
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
              getTooltipColor: (_) => kSurfaceContainerHigh,
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

// 1RM 推移データ点
class _RMPoint {
  final String date; // 'YYYY-MM-DD'
  final double oneRM;
  const _RMPoint({required this.date, required this.oneRM});
}
