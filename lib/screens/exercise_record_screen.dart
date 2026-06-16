import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../models/workout.dart';
import '../services/analytics_service.dart';
import '../services/cloud_data_service.dart';
import '../services/session_manager.dart';
import '../services/user_preferences.dart';
import '../utils/time_format.dart';
import '../widgets/duration_picker_sheet.dart';
import '../widgets/exercise_picker_sheet.dart';
import 'exercise_analysis_screen.dart';

enum _RestState { idle, running, paused, finished }

class ExerciseRecordScreen extends StatefulWidget {
  final Exercise exercise;
  /// 保存先セッションID。null の場合はアクティブセッション（今日）に保存。
  final String? sessionId;

  const ExerciseRecordScreen({
    super.key,
    required this.exercise,
    this.sessionId,
  });

  @override
  State<ExerciseRecordScreen> createState() => _ExerciseRecordScreenState();
}

class _ExerciseRecordScreenState extends State<ExerciseRecordScreen> {
  bool _isKg = true;
  Timer? _saveDebounce;
  late List<WorkoutSet> _sets;
  late List<TextEditingController> _weightCtrl;
  late List<TextEditingController> _repsCtrl;

  // 保存状態: 'saved' | 'saving' | 'unsaved'
  String _saveStatus = 'saved';

  WorkoutSet? _prevBestSet;

  // ── 休憩タイマー ─────────────────────────────────────
  Timer? _tickTimer;

  _RestState _restState = _RestState.idle;
  int _restDurationSec = 60;
  int _restRemainingSec = 60;
  Timer? _restFinishedAutoReset;

  @override
  void initState() {
    super.initState();
    _sets = List.generate(
      widget.exercise.sets.length,
      (i) => WorkoutSet(
        setNumber: i + 1,
        weight: widget.exercise.sets[i].weight,
        reps: widget.exercise.sets[i].reps,
        recordedAt: widget.exercise.sets[i].recordedAt,
      ),
    );
    _weightCtrl = _sets
        .map((s) => TextEditingController(text: s.weight.toStringAsFixed(1)))
        .toList();
    _repsCtrl = _sets
        .map((s) => TextEditingController(text: '${s.reps}'))
        .toList();

    _loadPrevBest();
    _loadRestDuration();

    // 新規追加時（sessionId 未指定）はアクティブセッションを作成 & 即保存
    if (widget.sessionId == null) {
      SessionManager.instance.getOrCreate();
      _triggerSave();
    }
  }

  Future<void> _loadPrevBest() async {
    final best =
        await SessionManager.instance.getPreviousBest(widget.exercise.name);
    if (mounted) setState(() => _prevBestSet = best);
  }

  Future<void> _loadRestDuration() async {
    final saved = await UserPreferences.instance.getRestDuration();
    if (mounted) {
      setState(() {
        _restDurationSec = saved;
        _restRemainingSec = saved;
      });
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _tickTimer?.cancel();
    _restFinishedAutoReset?.cancel();
    for (final c in _weightCtrl) {
      c.dispose();
    }
    for (final c in _repsCtrl) {
      c.dispose();
    }
    _commitSave();
    super.dispose();
  }

  // ── タイマー処理（休憩タイマー専用） ────────────────────

  void _onTick() {
    if (!mounted) return;
    if (_restState != _RestState.running) return;
    setState(() {
      _restRemainingSec--;
      if (_restRemainingSec <= 0) {
        _restRemainingSec = 0;
        _restState = _RestState.finished;
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
        _restFinishedAutoReset?.cancel();
        _restFinishedAutoReset = Timer(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _restState = _RestState.idle;
              _restRemainingSec = _restDurationSec;
            });
          }
        });
      }
    });
  }

  void _startRest() {
    setState(() {
      _restRemainingSec = _restDurationSec;
      _restState = _RestState.running;
    });
    _tickTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _pauseRest() {
    setState(() => _restState = _RestState.paused);
  }

  void _resumeRest() {
    setState(() => _restState = _RestState.running);
    _tickTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _stopRest() {
    _restFinishedAutoReset?.cancel();
    setState(() {
      _restState = _RestState.idle;
      _restRemainingSec = _restDurationSec;
    });
  }

  Future<void> _showDurationPicker() async {
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.cCardLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DurationPickerSheet(currentSec: _restDurationSec),
    );
    if (result != null && result > 0 && mounted) {
      setState(() {
        _restDurationSec = result;
        if (_restState == _RestState.idle) {
          _restRemainingSec = result;
        }
      });
      await UserPreferences.instance.setRestDuration(result);
    }
  }

  // ── 自動保存 ────────────────────────────────────────

  void _triggerSave() {
    setState(() => _saveStatus = 'saving');
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () async {
      await _commitSaveAsync();
      if (mounted) setState(() => _saveStatus = 'saved');
    });
  }

  Future<void> _commitSaveAsync() async {
    final exercise = Exercise(
      name: widget.exercise.name,
      muscleGroup: widget.exercise.muscleGroup,
      sets: List.from(_sets),
    );
    if (widget.sessionId != null) {
      // 特定のセッション（過去 or アクティブ）に保存
      await SessionManager.instance
          .saveExerciseToExistingSession(widget.sessionId!, exercise);
    } else {
      // sessionId 未指定 → アクティブセッションに保存
      await SessionManager.instance.saveExercise(exercise);
    }
    // Analytics: 種目記録イベント
    unawaited(AnalyticsService.instance.logExerciseRecorded(
      exerciseName: widget.exercise.name,
      setCount: _sets.length,
    ));

    // 匿名統計データ送信（オプトイン時のみ）
    if (_currentMaxRM > 0) {
      final weight = await UserPreferences.instance.getBodyWeight();
      if (weight > 0) {
        unawaited(CloudDataService.instance.recordRatio(
          exerciseName: widget.exercise.name,
          ratio: _currentMaxRM / weight,
        ));
      }
    }
  }

  void _commitSave() {
    _commitSaveAsync();
  }

  Future<void> _saveAndPop() async {
    _saveDebounce?.cancel();
    await _commitSaveAsync();
    if (mounted) Navigator.of(context).pop();
  }

  // ── 表示ヘルパー ─────────────────────────────────────

  double get _currentMaxRM {
    if (_sets.isEmpty) return 0;
    return _sets.map((s) => s.oneRM).reduce((a, b) => a > b ? a : b);
  }

  // ── ビルド ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndPop();
      },
      child: Scaffold(
        backgroundColor: context.cBg,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildStatsCard(),
            _buildRestTimer(),
            _buildColumnHeader(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _sets.length,
                itemBuilder: (_, i) => _buildSetRow(i),
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: context.cBg.withValues(alpha: 0.85),
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: context.cText),
        onPressed: _saveAndPop,
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
            widget.exercise.muscleGroup.label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: context.cTextSub,
            ),
          ),
        ],
      ),
      actions: [
        _buildSaveIndicator(),
        _unitToggle(),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildSaveIndicator() {
    final (icon, color, label) = switch (_saveStatus) {
      'saving' => (Icons.sync, context.cTextSub, '保存中'),
      'saved' => (Icons.cloud_done_outlined, kTertiary, '保存済'),
      _ => (Icons.edit_outlined, kPrimary, '未保存'),
    };
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(fontSize: 8, color: color),
          ),
        ],
      ),
    );
  }

  Widget _unitToggle() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(children: [
        _unitBtn('kg', _isKg),
        _unitBtn('lbs', !_isKg),
      ]),
    );
  }

  Widget _unitBtn(String label, bool active) {
    return GestureDetector(
      onTap: () {
        final newIsKg = label == 'kg';
        setState(() => _isKg = newIsKg);
        for (int i = 0; i < _sets.length; i++) {
          _weightCtrl[i].text = newIsKg
              ? _sets[i].weight.toStringAsFixed(1)
              : _sets[i].weightInLbs.toStringAsFixed(1);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? kPrimary : Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  '前回のベスト',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: context.cTextSub,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _prevBestSet != null
                      ? '${_prevBestSet!.weight.toStringAsFixed(1)}kg × ${_prevBestSet!.reps}'
                      : '--',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color:
                        _prevBestSet != null ? kPrimaryLight : context.cTextSub,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: Colors.white12),
          Expanded(
            child: Column(
              children: [
                Text(
                  '現在の最大1RM',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: context.cTextSub,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_currentMaxRM.toStringAsFixed(1)}kg',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kTertiary,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: Colors.white12),
          GestureDetector(
            onTap: _currentMaxRM > 0
                ? () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExerciseAnalysisScreen(
                          exercise: widget.exercise,
                          currentOneRM: _currentMaxRM,
                        ),
                      ),
                    )
                : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  Icon(
                    Icons.analytics_outlined,
                    size: 20,
                    color: _currentMaxRM > 0
                        ? kPrimary
                        : context.cTextSub.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '分析',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: _currentMaxRM > 0
                          ? kPrimary
                          : context.cTextSub.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 休憩タイマー ──────────────────────────────────────

  Widget _buildRestTimer() {
    final isRunning = _restState == _RestState.running;
    final isPaused = _restState == _RestState.paused;
    final isFinished = _restState == _RestState.finished;
    final isIdle = _restState == _RestState.idle;

    final borderColor = isFinished
        ? kTertiary
        : (isRunning || isPaused)
            ? kSecondary.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.06);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isFinished
            ? kTertiary.withValues(alpha: 0.12)
            : context.cCardLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: isFinished ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Icon(
            isFinished
                ? Icons.check_circle
                : (isRunning || isPaused)
                    ? Icons.timer
                    : Icons.timer_outlined,
            color: isFinished
                ? kTertiary
                : (isRunning || isPaused)
                    ? kSecondary
                    : context.cTextSub,
            size: 18,
          ),
          const SizedBox(width: 8),
          if (isIdle) ..._restIdleContent(),
          if (isRunning || isPaused) ..._restRunningContent(isPaused),
          if (isFinished) ..._restFinishedContent(),
        ],
      ),
    );
  }

  List<Widget> _restIdleContent() {
    return [
      Text(
        '休憩タイマー',
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.cText,
        ),
      ),
      const SizedBox(width: 10),
      GestureDetector(
        onTap: _showDurationPicker,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: context.cCardHigh,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatMMSS(_restDurationSec),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.cText,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.expand_more,
                  size: 14, color: context.cTextSub),
            ],
          ),
        ),
      ),
      const Spacer(),
      GestureDetector(
        onTap: _startRest,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: kSecondary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow,
                  color: Colors.white, size: 14),
              const SizedBox(width: 2),
              Text(
                'START',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _restRunningContent(bool isPaused) {
    return [
      Text(
        formatMMSS(_restRemainingSec),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: isPaused ? context.cTextSub : kSecondary,
          letterSpacing: 1,
        ),
      ),
      const SizedBox(width: 6),
      Text(
        isPaused ? '一時停止' : '休憩中',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          color: context.cTextSub,
          letterSpacing: 1,
        ),
      ),
      const Spacer(),
      GestureDetector(
        onTap: isPaused ? _resumeRest : _pauseRest,
        child: Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: context.cCardHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isPaused ? Icons.play_arrow : Icons.pause,
            color: context.cText,
            size: 18,
          ),
        ),
      ),
      GestureDetector(
        onTap: _stopRest,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: context.cCardHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.stop, color: context.cText, size: 18),
        ),
      ),
    ];
  }

  List<Widget> _restFinishedContent() {
    return [
      Text(
        '休憩終了！',
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: kTertiary,
        ),
      ),
      const Spacer(),
      GestureDetector(
        onTap: _stopRest,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: kTertiary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'OK',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildColumnHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('SET',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, color: context.cTextSub, letterSpacing: 1)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text('重量',
                textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, color: context.cTextSub, letterSpacing: 1)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text('回数',
                textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, color: context.cTextSub, letterSpacing: 1)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text('1RM推定',
                textAlign: TextAlign.right,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, color: context.cTextSub, letterSpacing: 1)),
          ),
          const SizedBox(width: 28),
        ],
      ),
    );
  }

  Widget _buildSetRow(int i) {
    final s = _sets[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${s.setNumber}',
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: _numInput(
              controller: _weightCtrl[i],
              onChanged: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null) {
                  s.weight = _isKg ? parsed : parsed / 2.20462;
                  s.recordedAt = DateTime.now();
                }
              },
              onDone: () {
                setState(() {});
                _triggerSave();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: _numInput(
              controller: _repsCtrl[i],
              onChanged: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null) {
                  s.reps = parsed;
                  s.recordedAt = DateTime.now();
                }
              },
              onDone: () {
                setState(() {});
                _triggerSave();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kTertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${s.oneRM.toStringAsFixed(1)}kg',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: kTertiary,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 16,
              onPressed: () {
                _weightCtrl[i].dispose();
                _weightCtrl.removeAt(i);
                _repsCtrl[i].dispose();
                _repsCtrl.removeAt(i);
                setState(() {
                  _sets.removeAt(i);
                  for (int j = 0; j < _sets.length; j++) {
                    _sets[j].setNumber = j + 1;
                  }
                });
                _triggerSave();
              },
              icon: Icon(Icons.close, color: context.cBorder),
            ),
          ),
        ],
      ),
    );
  }

  Widget _numInput({
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
    required VoidCallback onDone,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: kPrimary,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: context.cCardTop.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kPrimary, width: 1),
        ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      ),
      onChanged: onChanged,
      onSubmitted: (_) => onDone(),
      onEditingComplete: onDone,
    );
  }

  // ── ボトムバー（セット追加 ＋ 次の種目） ──────────────────

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _addSet,
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.cBorderSub, width: 1),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: context.cTextSub, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'セットを追加',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.cTextSub,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showAddNextExercise,
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      '次の種目',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addSet() {
    final num = _sets.length + 1;
    final prevSet = _sets.isNotEmpty ? _sets.last : null;
    final initWeight = prevSet?.weight ?? 0.0;
    final initReps = prevSet?.reps ?? 0;
    final newSet =
        WorkoutSet(setNumber: num, weight: initWeight, reps: initReps);
    final weightText = initWeight > 0
        ? (_isKg
            ? initWeight.toStringAsFixed(1)
            : (initWeight * 2.20462).toStringAsFixed(1))
        : '';
    _weightCtrl.add(TextEditingController(text: weightText));
    _repsCtrl.add(TextEditingController(text: initReps > 0 ? '$initReps' : ''));
    setState(() => _sets.add(newSet));
    _triggerSave();
  }

  Future<void> _showAddNextExercise() async {
    _commitSave();
    // 現在のセッションを特定（sessionId 指定がなければアクティブセッション）
    final targetSession = widget.sessionId != null
        ? (await SessionManager.instance.getAllSessions())
            .where((s) => s.id == widget.sessionId)
            .firstOrNull
        : SessionManager.instance.active;

    final doneNames = Set<String>.from(
      targetSession?.exercises.map((e) => e.name) ?? [],
    );
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ExercisePickerSheet(
        title: '次の種目を選択',
        markedNames: doneNames,
        headerSlot: _buildSessionPreview(targetSession),
        onSelected: (exercise) {
          final existingEx = targetSession?.exercises
              .where((e) => e.name == exercise.name)
              .firstOrNull;

          if (existingEx != null && targetSession != null) {
            // 同じセッション内の既存種目 → そのまま編集
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExerciseRecordScreen(
                  exercise: existingEx,
                  sessionId: targetSession.id,
                ),
              ),
            );
          } else {
            // 新規種目 → 同じセッションIDを引き継ぐ
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExerciseRecordScreen(
                  exercise: exercise,
                  sessionId: widget.sessionId,
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSessionPreview([WorkoutSession? session]) {
    session ??= SessionManager.instance.active;
    if (session == null || session.exercises.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.cCardHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.fitness_center, size: 14, color: kPrimary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '記録済み: ${session.exercises.map((e) => e.name).join(' · ')}',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: context.cTextSub,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
