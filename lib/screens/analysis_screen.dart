import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../theme.dart';
import '../models/workout.dart';
import '../data/strength_standards.dart';
import '../services/ad_service.dart';
import '../services/session_manager.dart';
import '../services/stopwatch_service.dart';
import '../services/user_preferences.dart';
import '../utils/time_format.dart';
import 'exercise_analysis_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen>
    with SingleTickerProviderStateMixin {
  double _bodyWeight = 70.0;
  String _gender = '男性';
  List<WorkoutSession> _allSessions = [];
  bool _isLoading = true;

  // ── ワークアウトストップウォッチ ──────────────────────
  Timer? _stopwatchTimer;
  Duration _elapsed = Duration.zero;
  late final AnimationController _pulseController;

  // ── リワード広告 ───────────────────────────────────────
  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    SessionManager.instance.addListener(_onSessionChanged);
    _startStopwatchTick();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _loadRewardedAd();
  }

  void _onSessionChanged() => _loadData();

  @override
  void dispose() {
    SessionManager.instance.removeListener(_onSessionChanged);
    _stopwatchTimer?.cancel();
    _pulseController.dispose();
    _rewardedAd?.dispose();
    super.dispose();
  }

  void _loadRewardedAd() {
    if (_isAdLoading) return;
    setState(() => _isAdLoading = true);
    AdService.instance.loadRewarded(
      onLoaded: (ad) {
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            setState(() {
              _rewardedAd = null;
              _isAdLoading = false;
            });
            _loadRewardedAd(); // 次の広告を事前ロード
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            setState(() {
              _rewardedAd = null;
              _isAdLoading = false;
            });
          },
        );
        if (mounted) {
          setState(() {
            _rewardedAd = ad;
            _isAdLoading = false;
          });
        }
      },
      onFailed: (_) {
        if (mounted) setState(() => _isAdLoading = false);
      },
    );
  }

  void _showRewardedAd() {
    _rewardedAd?.show(
      onUserEarnedReward: (_, reward) {
        // リワードなし（応援のみ）
      },
    );
  }

  void _startStopwatchTick() {
    _updateElapsed();
    _stopwatchTimer?.cancel();
    _stopwatchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateElapsed();
    });
  }

  void _updateElapsed() {
    if (!mounted) return;
    setState(() {
      _elapsed = StopwatchService.instance.elapsed;
    });
  }


  Future<void> _loadData() async {
    final sessions = await SessionManager.instance.getAllSessions();
    final weight = await UserPreferences.instance.getBodyWeight();
    final gender = await UserPreferences.instance.getGender();
    if (mounted) {
      setState(() {
        _allSessions = sessions;
        _bodyWeight = weight;
        _gender = gender;
        _isLoading = false;
      });
    }
  }

  // 全セッション + アクティブセッションから種目ごとの最高1RMを返す
  List<_ExerciseSummary> get _summaries {
    final allExercises = <Exercise>[
      ..._allSessions.expand((s) => s.exercises),
    ];
    // アクティブセッションを合算（まだ DB に確定していない分）
    final active = SessionManager.instance.active;
    if (active != null) allExercises.addAll(active.exercises);
    if (allExercises.isEmpty) return [];

    // 同名種目は最高1RMを採用
    final Map<String, _ExerciseSummary> best = {};
    for (final e in allExercises.where((e) => e.sets.isNotEmpty)) {
      final maxRM =
          e.sets.map((s) => s.oneRM).reduce((a, b) => a > b ? a : b);
      final existing = best[e.name];
      if (existing == null || maxRM > existing.maxRM) {
        final result = evaluate(
          exerciseName: e.name,
          muscleGroupLabel: e.muscleGroup.label,
          oneRM: maxRM,
          bodyWeight: _bodyWeight,
          isFemale: _gender == '女性',
        );
        best[e.name] =
            _ExerciseSummary(exercise: e, maxRM: maxRM, result: result);
      }
    }
    return best.values.toList()..sort((a, b) => b.maxRM.compareTo(a.maxRM));
  }

  // 最も次のレベルに近い種目
  _ExerciseSummary? get _closestToNextLevel {
    final list =
        _summaries.where((s) => s.result.nextThreshold != null).toList();
    if (list.isEmpty) return null;
    list.sort((a, b) {
      final ra =
          (a.result.nextThreshold! - a.maxRM) / a.result.nextThreshold!;
      final rb =
          (b.result.nextThreshold! - b.maxRM) / b.result.nextThreshold!;
      return ra.compareTo(rb);
    });
    return list.first;
  }

  // 体重推移（日付ごと、記録が入力された日の体重値を使用）
  List<({String date, double weight})> get _bodyWeightHistory {
    final Map<String, double> byDate = {};
    final allSessions = [
      ..._allSessions,
      if (SessionManager.instance.active != null)
        SessionManager.instance.active!,
    ];
    for (final s in allSessions) {
      if (s.bodyWeightKg == null || s.exercises.isEmpty) continue;
      final key = formatYMD(s.date);
      byDate[key] = s.bodyWeightKg!;
    }
    final list = byDate.entries.map((e) => (date: e.key, weight: e.value)).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }

  // 部位カバレッジ
  Set<MuscleGroup> get _coveredGroups {
    final exercises = <Exercise>[
      ..._allSessions.expand((s) => s.exercises),
    ];
    final active = SessionManager.instance.active;
    if (active != null) exercises.addAll(active.exercises);
    return exercises.map((e) => e.muscleGroup).toSet();
  }

  void _editBodyWeight() {
    final ctrl = TextEditingController(text: _bodyWeight.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cCardLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('体重を設定',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: context.cText)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                  style: GoogleFonts.inter(color: context.cTextSub))),
          TextButton(
            onPressed: () async {
              final v = double.tryParse(ctrl.text);
              if (v != null && v > 0) {
                await UserPreferences.instance.setBodyWeight(v);
                if (mounted) setState(() => _bodyWeight = v);
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
    final summaries = _summaries;

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        backgroundColor: context.cBg.withValues(alpha: 0.85),
        elevation: 0,
        title: Text(
          'REP RANK',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: kPrimary,
            letterSpacing: -0.5,
            fontStyle: FontStyle.italic,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _editBodyWeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_bodyWeight.toStringAsFixed(0)}kg',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.cText),
                  ),
                  Text('体重 ✎',
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 9, color: context.cTextSub)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _buildWorkoutStopwatchCard(),
                const SizedBox(height: 16),
                if (summaries.isEmpty)
                  _buildEmptyInline()
                else ...[
                  _buildOverallCard(summaries),
                  const SizedBox(height: 16),
                  _buildMuscleCoverage(),
                  const SizedBox(height: 16),
                  if (_closestToNextLevel != null) ...[
                    _buildNextMilestoneCard(_closestToNextLevel!),
                    const SizedBox(height: 16),
                  ],
                  _buildSectionHeader('種目別ベスト'),
                  const SizedBox(height: 10),
                  _buildExerciseGrid(summaries),
                ],
                const SizedBox(height: 24),
                _buildSectionHeader('体重推移'),
                const SizedBox(height: 10),
                _buildBodyWeightChart(),
                const SizedBox(height: 24),
                _buildSupportAdButton(),
                const SizedBox(height: 8),
              ],
            ),
    );
  }

  // ── 体重推移グラフ ─────────────────────────────────────
  Widget _buildBodyWeightChart() {
    final history = _bodyWeightHistory;
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
            '記録日の体重値',
            style: GoogleFonts.jetBrainsMono(
                fontSize: 10, color: context.cTextSub.withValues(alpha: 0.5)),
          ),
          const SizedBox(height: 16),
          if (history.length < 2)
            SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  'データが不足しています',
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 11, color: context.cTextSub),
                ),
              ),
            )
          else
            _buildBodyWeightLineChart(history),
        ],
      ),
    );
  }

  Widget _buildBodyWeightLineChart(
      List<({String date, double weight})> history) {
    final spots = history
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.weight))
        .toList();
    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 1;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 1;

    return SizedBox(
      height: 140,
      child: LineChart(LineChartData(
        minX: 0,
        maxX: (history.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.white.withValues(alpha: 0.06), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, color: context.cTextSub),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval:
                  history.length <= 6 ? 1 : (history.length / 4).ceilToDouble(),
              getTitlesWidget: (v, _) {
                final idx = v.toInt();
                if (idx < 0 || idx >= history.length) {
                  return const SizedBox.shrink();
                }
                final parts = history[idx].date.split('-');
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${parts[1]}/${parts[2]}',
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 9, color: context.cTextSub)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
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
                          color: kPrimary),
                    ))
                .toList(),
          ),
        ),
      )),
    );
  }

  // ── ワークアウトストップウォッチカード（単純な START/STOP/RESET） ─
  // Stitch design: 17765783634350002168 / ebfe1322ae884b6ab25aa263c47a4622
  Widget _buildWorkoutStopwatchCard() {
    final svc = StopwatchService.instance;
    final isRunning = svc.isRunning;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glow = 0.10 + 0.10 * _pulseController.value;
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                kPrimaryLight.withValues(alpha: 0.10),
                Colors.transparent,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: kPrimaryLight.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: kPrimaryLight.withValues(alpha: glow),
                blurRadius: 24,
                spreadRadius: 0,
              ),
            ],
          ),
          child: child!,
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ヘッダー
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: Tween<double>(begin: 0.4, end: 1.0)
                    .animate(_pulseController),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: kPrimaryLight,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'ストップウォッチ',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kPrimaryLight,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // 経過時間（64px 大画面表示）
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              formatHMS(_elapsed),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 64,
                fontWeight: FontWeight.w800,
                color: kPrimaryLight,
                letterSpacing: -1,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '経過時間',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: context.cTextSub,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // 操作ボタン: START / STOP / RESET
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.play_arrow,
                  label: 'START',
                  bgColor: isRunning ? context.cCardHigh : kPrimary,
                  fgColor: isRunning ? context.cTextSub : Colors.white,
                  disabled: isRunning,
                  onTap: () {
                    StopwatchService.instance.start();
                    _updateElapsed();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.pause,
                  label: 'STOP',
                  bgColor: isRunning ? context.cCardHigh : context.cCardHigh,
                  fgColor: isRunning ? kPrimaryLight : context.cTextSub,
                  borderColor: isRunning
                      ? kPrimaryLight.withValues(alpha: 0.5)
                      : null,
                  disabled: !isRunning,
                  onTap: () {
                    StopwatchService.instance.stop();
                    _updateElapsed();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionButton(
                  icon: Icons.refresh,
                  label: 'RESET',
                  bgColor: context.cCardHigh,
                  fgColor: context.cTextSub,
                  onTap: () {
                    StopwatchService.instance.reset();
                    _updateElapsed();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color fgColor,
    required VoidCallback onTap,
    Color? borderColor,
    bool disabled = false,
  }) {
    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: borderColor != null
                ? Border.all(color: borderColor, width: 1)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fgColor, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fgColor,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyInline() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined,
              size: 56, color: context.cTextSub.withValues(alpha: 0.2)),
          const SizedBox(height: 14),
          Text(
            'まだデータがありません',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.cTextSub,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '＋ボタンからトレーニングを開始',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: context.cTextSub.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ── 総合カード ────────────────────────────────────────────────
  Widget _buildOverallCard(List<_ExerciseSummary> summaries) {
    // 最高レベルを「総合」として表示
    final topTier = summaries
        .map((s) => s.result.tier)
        .reduce((a, b) => a.index > b.index ? a : b);
    final avgRM = summaries.map((s) => s.maxRM).reduce((a, b) => a + b) /
        summaries.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: topTier.colorForContext(context).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('総合レベル',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        color: context.cTextSub,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(
                  topTier.label,
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: topTier.colorForContext(context),
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _statChip(
                      '${summaries.length} 種目',
                      Icons.fitness_center,
                      kPrimary,
                    ),
                    const SizedBox(width: 8),
                    _statChip(
                      '平均 ${avgRM.toStringAsFixed(0)}kg',
                      Icons.show_chart,
                      kTertiary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // レベルアイコン
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: topTier.colorForContext(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: topTier.colorForContext(context).withValues(alpha: 0.25)),
            ),
            child: Icon(_tierIcon(topTier), color: topTier.colorForContext(context), size: 36),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── 部位カバレッジ ──────────────────────────────────────────
  Widget _buildMuscleCoverage() {
    const allGroups = [
      MuscleGroup.chest,
      MuscleGroup.back,
      MuscleGroup.legs,
      MuscleGroup.shoulders,
      MuscleGroup.arms,
      MuscleGroup.abs,
    ];
    final covered = _coveredGroups;

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
          Text('部位カバレッジ',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: context.cTextSub,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: allGroups.map((g) {
              final hit = covered.contains(g);
              return Column(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: hit
                          ? kPrimary.withValues(alpha: 0.12)
                          : context.cCardHigh,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: hit
                            ? kPrimary.withValues(alpha: 0.4)
                            : Colors.transparent,
                      ),
                    ),
                    child: Icon(
                      _groupIcon(g),
                      size: 18,
                      color: hit ? kPrimary : context.cTextSub.withValues(alpha: 0.3),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    g.label,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: hit ? context.cText : context.cTextSub.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── 次のマイルストーン ────────────────────────────────────────
  Widget _buildNextMilestoneCard(_ExerciseSummary s) {
    final next = s.result.nextThreshold!;
    final diff = next - s.maxRM;
    final nextTier = StrengthTier.values[s.result.tier.index + 1];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: nextTier.colorForContext(context).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('最も近い目標',
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  color: context.cTextSub,
                  letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: nextTier.colorForContext(context).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.flag_outlined,
                    color: nextTier.colorForContext(context), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.exercise.name,
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.cText),
                    ),
                    Text(
                      '${s.result.tier.label} → ${nextTier.label}',
                      style: GoogleFonts.jetBrainsMono(
                          fontSize: 11, color: context.cTextSub),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${next.toStringAsFixed(1)}kg',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: nextTier.colorForContext(context),
                      height: 1,
                    ),
                  ),
                  Text(
                    'あと +${diff.toStringAsFixed(1)}kg',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 10, color: context.cTextSub),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: s.result.progressInTier,
              minHeight: 6,
              backgroundColor: context.cCardHigh,
              valueColor: AlwaysStoppedAnimation(nextTier.colorForContext(context)),
            ),
          ),
        ],
      ),
    );
  }

  // ── 種目別グリッド ────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.jetBrainsMono(
          fontSize: 10, color: context.cTextSub, letterSpacing: 1.5),
    );
  }

  Widget _buildExerciseGrid(List<_ExerciseSummary> summaries) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemCount: summaries.length,
      itemBuilder: (_, i) => _buildExerciseCard(summaries[i]),
    );
  }

  Widget _buildExerciseCard(_ExerciseSummary s) {
    final tier = s.result.tier;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExerciseAnalysisScreen(
            exercise: s.exercise,
            currentOneRM: s.maxRM,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.cCardLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tier.colorForContext(context).withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(_groupIcon(s.exercise.muscleGroup),
                    size: 16,
                    color: tier.colorForContext(context).withValues(alpha: 0.8)),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: tier.colorForContext(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tier.label,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: tier.colorForContext(context),
                    ),
                  ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.exercise.name,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.cText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      s.maxRM.toStringAsFixed(1),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: context.cText,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2, left: 2),
                      child: Text('kg',
                          style: GoogleFonts.jetBrainsMono(
                              fontSize: 11, color: context.cTextSub)),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 広告応援ボタン ──────────────────────────────────────────────

  Widget _buildSupportAdButton() {
    final isReady = _rewardedAd != null;
    return GestureDetector(
      onTap: isReady ? _showRewardedAd : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isReady
              ? kPrimary.withValues(alpha: 0.1)
              : context.cCardLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isReady
                ? kPrimary.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.volunteer_activism_outlined,
              size: 18,
              color: isReady ? kPrimary : context.cTextSub,
            ),
            const SizedBox(width: 8),
            Text(
              isReady ? '広告を見て応援する' : '広告を準備中...',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isReady ? kPrimary : context.cTextSub,
              ),
            ),
          ],
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

  IconData _groupIcon(MuscleGroup g) {
    switch (g) {
      case MuscleGroup.chest:     return Icons.fitness_center;
      case MuscleGroup.back:      return Icons.rowing;
      case MuscleGroup.legs:      return Icons.directions_run;
      case MuscleGroup.shoulders: return Icons.sports_handball;
      case MuscleGroup.arms:      return Icons.sports_gymnastics;
      case MuscleGroup.abs:       return Icons.crop_square;
      default:                    return Icons.fitness_center;
    }
  }
}

class _ExerciseSummary {
  final Exercise exercise;
  final double maxRM;
  final StrengthResult result;
  const _ExerciseSummary(
      {required this.exercise, required this.maxRM, required this.result});
}
