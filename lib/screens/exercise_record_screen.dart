import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../models/workout.dart';
import '../services/analytics_service.dart';
import '../services/cloud_data_service.dart';
import '../services/rest_timer_service.dart';
import '../services/session_manager.dart';
import '../services/user_preferences.dart';
import '../utils/time_format.dart';
import '../widgets/duration_picker_sheet.dart';
import '../widgets/exercise_picker_sheet.dart';
import 'exercise_analysis_screen.dart';

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
  late List<TextEditingController> _setMemoCtrl;
  late TextEditingController _exerciseMemoCtrl;

  String _saveStatus = 'saved';
  Exercise? _prevRecord;

  // ── セッション体重 ────────────────────────────────────
  double? _bodyWeightKg;
  String? _resolvedSessionId;

  // RestTimerService はグローバル singleton。タイマーUIの再描画用タイマー。
  Timer? _uiRefreshTimer;

  /// この画面（種目）に対応する休憩タイマーのキー。
  late final String _timerKey;

  @override
  void initState() {
    super.initState();
    _timerKey = RestTimerService.keyFor(widget.exercise.name);
    _sets = List.generate(
      widget.exercise.sets.length,
      (i) => WorkoutSet(
        setNumber: i + 1,
        weight: widget.exercise.sets[i].weight,
        reps: widget.exercise.sets[i].reps,
        recordedAt: widget.exercise.sets[i].recordedAt,
        memo: widget.exercise.sets[i].memo,
      ),
    );
    _weightCtrl = _sets
        .map((s) => TextEditingController(text: _formatWeight(s.weight)))
        .toList();
    _repsCtrl = _sets
        .map((s) => TextEditingController(text: '${s.reps}'))
        .toList();
    _setMemoCtrl = _sets
        .map((s) => TextEditingController(text: s.memo ?? ''))
        .toList();
    _exerciseMemoCtrl = TextEditingController(text: widget.exercise.memo ?? '');

    _loadPrevRecord();
    _loadRestDuration();
    _loadUnit();

    // RestTimerService の変更を受け取るリスナー登録
    RestTimerService.instance.addListener(_onTimerChanged);
    // この画面にタイマーUIがあるため、この種目分だけ全画面共通オーバーレイを抑制する。
    // suppressOverlay() は notifyListeners() を呼ぶため、initState（ビルド中）から
    // 直接呼ぶと「setState() called during build」になる。次フレームに遅延させる。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      RestTimerService.instance.suppressOverlay(_timerKey);
    });

    // 新規追加時（sessionId 未指定）はアクティブセッションを作成
    // 種目は実際にデータが入力された時のみ保存する（選択だけで記録にならないよう）
    if (widget.sessionId == null) {
      _initSession();
    } else {
      _resolvedSessionId = widget.sessionId;
      _loadBodyWeight();
    }
  }

  void _onTimerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initSession() async {
    final session = await SessionManager.instance.getOrCreate();
    _resolvedSessionId = session.id;
    // _triggerSave() はここでは呼ばない（空の種目が記録されるのを防ぐ）
    _loadBodyWeight();
  }

  Future<void> _loadBodyWeight() async {
    double? weight;
    final active = SessionManager.instance.active;
    if (active != null && active.id == _resolvedSessionId) {
      weight = active.bodyWeightKg;
    } else if (_resolvedSessionId != null) {
      final sessions = await SessionManager.instance.getAllSessions();
      final session =
          sessions.where((s) => s.id == _resolvedSessionId).firstOrNull;
      weight = session?.bodyWeightKg;
    }
    weight ??= await UserPreferences.instance.getBodyWeight();
    if (mounted) setState(() => _bodyWeightKg = weight);
  }

  Future<void> _loadUnit() async {
    final isKg = await UserPreferences.instance.getIsKg();
    if (mounted) setState(() => _isKg = isKg);
  }

  Future<void> _loadPrevRecord() async {
    final record = await SessionManager.instance.getPreviousExerciseRecord(
      widget.exercise.name,
      excludeSessionId: widget.sessionId,
    );
    if (mounted) setState(() => _prevRecord = record);
  }

  /// 前回の記録の全セット（重量・回数・メモ）を現在の入力にペーストする。
  void _pasteFromPrevious() {
    final prev = _prevRecord;
    if (prev == null || prev.sets.isEmpty) return;
    for (final c in _weightCtrl) {
      c.dispose();
    }
    for (final c in _repsCtrl) {
      c.dispose();
    }
    for (final c in _setMemoCtrl) {
      c.dispose();
    }
    final newSets = <WorkoutSet>[];
    final newWeightCtrl = <TextEditingController>[];
    final newRepsCtrl = <TextEditingController>[];
    final newMemoCtrl = <TextEditingController>[];
    for (int i = 0; i < prev.sets.length; i++) {
      final ps = prev.sets[i];
      newSets.add(WorkoutSet(
        setNumber: i + 1,
        weight: ps.weight,
        reps: ps.reps,
        memo: ps.memo,
        recordedAt: DateTime.now(),
      ));
      newWeightCtrl.add(TextEditingController(text: _formatWeight(ps.weight)));
      newRepsCtrl
          .add(TextEditingController(text: ps.reps > 0 ? '${ps.reps}' : ''));
      newMemoCtrl.add(TextEditingController(text: ps.memo ?? ''));
    }
    setState(() {
      _sets = newSets;
      _weightCtrl = newWeightCtrl;
      _repsCtrl = newRepsCtrl;
      _setMemoCtrl = newMemoCtrl;
    });
    _triggerSave();
  }

  Future<void> _confirmPasteFromPrevious() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cCardLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('前回の記録をペースト',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: context.cText)),
        content: Text(
          '現在入力中の全セットが前回の記録（重量・回数・メモ）で上書きされます。よろしいですか？',
          style: GoogleFonts.inter(fontSize: 13, color: context.cTextSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('キャンセル',
                style: GoogleFonts.inter(color: context.cTextSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('ペースト',
                style: GoogleFonts.inter(
                    color: kPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) _pasteFromPrevious();
  }

  Future<void> _loadRestDuration() async {
    final saved = await UserPreferences.instance.getRestDuration();
    RestTimerService.instance.setDuration(widget.exercise, widget.sessionId, saved);
  }

  @override
  void dispose() {
    RestTimerService.instance.removeListener(_onTimerChanged);
    RestTimerService.instance.unsuppressOverlay(_timerKey);
    _saveDebounce?.cancel();
    _uiRefreshTimer?.cancel();
    for (final c in _weightCtrl) {
      c.dispose();
    }
    for (final c in _repsCtrl) {
      c.dispose();
    }
    for (final c in _setMemoCtrl) {
      c.dispose();
    }
    _exerciseMemoCtrl.dispose();
    _commitSave();
    super.dispose();
  }

  /// 重量の表示用フォーマット。整数値は小数点なしで表示し、
  /// 端数がある場合のみ小数第1位まで表示する（入力自体は小数点対応のまま）。
  String _formatWeight(double kg) {
    final displayValue = _isKg ? kg : kg * 2.20462;
    if (displayValue <= 0) return '';
    if (displayValue == displayValue.roundToDouble()) {
      return displayValue.toInt().toString();
    }
    return displayValue.toStringAsFixed(1);
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
    // 意味のあるデータがある場合のみ保存（選択しただけでは記録にならない）
    final hasData = _sets.any((s) =>
            s.reps > 0 || s.weight > 0 || (s.memo?.isNotEmpty ?? false)) ||
        _exerciseMemoCtrl.text.trim().isNotEmpty;
    if (!hasData) return;

    final exercise = Exercise(
      name: widget.exercise.name,
      muscleGroup: widget.exercise.muscleGroup,
      sets: List.from(_sets),
      memo: _exerciseMemoCtrl.text.trim().isEmpty
          ? null
          : _exerciseMemoCtrl.text.trim(),
    );
    if (widget.sessionId != null) {
      await SessionManager.instance
          .saveExerciseToExistingSession(widget.sessionId!, exercise);
    } else {
      await SessionManager.instance.saveExercise(exercise);
    }
    unawaited(AnalyticsService.instance.logExerciseRecorded(
      exerciseName: widget.exercise.name,
      setCount: _sets.length,
    ));

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

  // ── タイマー設定 ─────────────────────────────────────

  Future<void> _showDurationPicker() async {
    final timer = RestTimerService.instance;
    final currentDuration = timer.entryFor(_timerKey)?.durationSec ?? 60;
    final result = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: context.cCardLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => DurationPickerSheet(currentSec: currentDuration),
    );
    if (result != null && result > 0 && mounted) {
      timer.setDuration(widget.exercise, widget.sessionId, result);
      await UserPreferences.instance.setRestDuration(result);
    }
  }

  Future<void> _editBodyWeight() async {
    if (_resolvedSessionId == null) return;
    final ctrl = TextEditingController(
      text: (_bodyWeightKg ?? 0).toStringAsFixed(1),
    );
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cCardLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('この記録の体重',
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
                style: GoogleFonts.inter(color: context.cTextSub)),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              Navigator.pop(ctx, v);
            },
            child: Text('保存',
                style: GoogleFonts.inter(
                    color: kPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (result != null && result > 0 && mounted) {
      await SessionManager.instance
          .updateSessionBodyWeight(_resolvedSessionId!, result);
      if (mounted) setState(() => _bodyWeightKg = result);
    }
  }

  // ── ビルド ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndPop();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: context.cBg,
          appBar: _buildAppBar(),
          body: Column(
            children: [
              _buildStatsCard(),
              _buildOverallMemo(),
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
        _buildBodyWeightButton(),
        _buildSaveIndicator(),
        _unitToggle(),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBodyWeightButton() {
    return GestureDetector(
      onTap: _editBodyWeight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _bodyWeightKg != null
                  ? '${_bodyWeightKg!.toStringAsFixed(0)}kg'
                  : '--',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.cText,
              ),
            ),
            Text(
              '体重 ✎',
              style: GoogleFonts.jetBrainsMono(fontSize: 8, color: context.cTextSub),
            ),
          ],
        ),
      ),
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
        border: Border.all(color: context.cBorder),
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
          _weightCtrl[i].text = _formatWeight(_sets[i].weight);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? context.cCardTop : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? kPrimary : context.cTextSub,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '前回の記録',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: context.cTextSub,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_prevRecord != null && _prevRecord!.sets.isNotEmpty)
                      GestureDetector(
                        onTap: _confirmPasteFromPrevious,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(Icons.content_paste,
                              size: 12, color: kPrimary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (_prevRecord != null && _prevRecord!.sets.isNotEmpty)
                  ..._prevRecord!.sets.take(3).map(
                        (s) => Text(
                          '${s.weight.toStringAsFixed(1)}kg × ${s.reps}',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: kPrimaryLight,
                          ),
                        ),
                      )
                else
                  Text(
                    '--',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.cTextSub,
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

  // ── 全体メモ ──────────────────────────────────────────

  Widget _buildOverallMemo() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: TextField(
        controller: _exerciseMemoCtrl,
        maxLines: null,
        minLines: 1,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.newline,
        style: GoogleFonts.inter(fontSize: 13, color: context.cText),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          icon: Icon(Icons.sticky_note_2_outlined,
              size: 16, color: context.cTextSub),
          hintText: 'この種目のメモ（フォーム・意識点など）',
          hintStyle: GoogleFonts.inter(fontSize: 12, color: context.cTextSub),
        ),
        onChanged: (_) => _triggerSave(),
      ),
    );
  }

  // ── 休憩タイマー ──────────────────────────────────────

  Widget _buildRestTimer() {
    final entry = RestTimerService.instance.entryFor(_timerKey);
    final state = entry?.state ?? RestState.idle;
    final isRunning = state == RestState.running;
    final isPaused  = state == RestState.paused;
    final isFinished = state == RestState.finished;
    final isIdle    = state == RestState.idle;

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
    final durationSec =
        RestTimerService.instance.entryFor(_timerKey)?.durationSec ?? 60;
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: context.cCardHigh,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatMMSS(durationSec),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.cText,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.expand_more, size: 14, color: context.cTextSub),
            ],
          ),
        ),
      ),
      const Spacer(),
      GestureDetector(
        onTap: () => RestTimerService.instance.start(widget.exercise, widget.sessionId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: kSecondary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.play_arrow, color: Colors.white, size: 14),
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
    final remaining =
        RestTimerService.instance.entryFor(_timerKey)?.remainingSec ?? 0;
    return [
      Text(
        formatMMSS(remaining),
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
        onTap: isPaused
            ? () => RestTimerService.instance.resume(_timerKey)
            : () => RestTimerService.instance.pause(_timerKey),
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
        onTap: () => RestTimerService.instance.stop(_timerKey),
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
        onTap: () => RestTimerService.instance.stop(_timerKey),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
            flex: 4,
            child: Text('回数',
                textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, color: context.cTextSub, letterSpacing: 1)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
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
      child: Column(
        children: [
          Row(
            children: [
              // SET番号
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
              // 重量入力（小さめ）
              Expanded(
                flex: 3,
                child: SizedBox(height: _inputRowHeight, child: _weightInput(i)),
              ),
              const SizedBox(width: 8),
              // 回数 ± カウンター（キーボード入力も可、1RM推定近くまで幅を使う）
              Expanded(
                flex: 4,
                child: _repsCounter(i),
              ),
              const SizedBox(width: 8),
              // 1RM推定
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      color: kTertiary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${s.oneRM.toStringAsFixed(1)}kg',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: kTertiary,
                      ),
                    ),
                  ),
                ),
              ),
              // 削除ボタン
              SizedBox(
                width: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 16,
                  onPressed: () => _removeSet(i),
                  icon: Icon(Icons.close, color: context.cBorder),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // セットメモ（重量・回数入力欄の下に配置）
          Padding(
            padding: const EdgeInsets.only(left: 28),
            child: TextField(
              controller: _setMemoCtrl[i],
              maxLines: null,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              style: GoogleFonts.inter(fontSize: 11, color: context.cTextSub),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                hintText: 'セットメモ',
                hintStyle:
                    GoogleFonts.inter(fontSize: 11, color: context.cTextSub.withValues(alpha: 0.5)),
              ),
              onChanged: (v) {
                _sets[i].memo = v.trim().isEmpty ? null : v.trim();
                _triggerSave();
              },
            ),
          ),
        ],
      ),
    );
  }

  void _removeSet(int i) {
    _weightCtrl[i].dispose();
    _weightCtrl.removeAt(i);
    _repsCtrl[i].dispose();
    _repsCtrl.removeAt(i);
    _setMemoCtrl[i].dispose();
    _setMemoCtrl.removeAt(i);
    setState(() {
      _sets.removeAt(i);
      for (int j = 0; j < _sets.length; j++) {
        _sets[j].setNumber = j + 1;
      }
    });
    _triggerSave();
  }

  // 重量入力・回数エリアで高さを揃えるための共通値
  static const double _inputRowHeight = 38;

  Widget _weightInput(int i) {
    return TextField(
      controller: _weightCtrl[i],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: kPrimary,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: context.cCardTop,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.cBorderSub),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: context.cBorderSub),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kPrimary, width: 1),
        ),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      ),
      onChanged: (v) {
        final parsed = double.tryParse(v);
        if (parsed != null) {
          setState(() {
            _sets[i].weight = _isKg ? parsed : parsed / 2.20462;
            _sets[i].recordedAt = DateTime.now();
          });
        }
      },
      onSubmitted: (_) => _triggerSave(),
      onEditingComplete: _triggerSave,
    );
  }

  Widget _repsCounter(int i) {
    final reps = _sets[i].reps;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _counterBtn(
          icon: Icons.remove,
          onTap: reps > 0 ? () => _setReps(i, reps - 1) : null,
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            height: _inputRowHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.cCardTop,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.cBorderSub),
            ),
            child: TextField(
              controller: _repsCtrl[i],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: reps > 0 ? kPrimary : context.cTextSub,
              ),
              decoration: const InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null) {
                  setState(() {
                    _sets[i].reps = parsed;
                    _sets[i].recordedAt = DateTime.now();
                  });
                }
              },
              onSubmitted: (_) => _triggerSave(),
              onEditingComplete: _triggerSave,
            ),
          ),
        ),
        _counterBtn(
          icon: Icons.add,
          onTap: () => _setReps(i, reps + 1),
        ),
      ],
    );
  }

  void _setReps(int i, int value) {
    setState(() {
      _sets[i].reps = value;
      _sets[i].recordedAt = DateTime.now();
      _repsCtrl[i].text = '$value';
    });
    _triggerSave();
  }

  Widget _counterBtn({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: _inputRowHeight,
        decoration: BoxDecoration(
          color: onTap != null ? context.cCardTop : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: onTap != null ? context.cBorderSub : Colors.transparent,
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: onTap != null ? context.cText : context.cTextSub.withValues(alpha: 0.3),
        ),
      ),
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
    _weightCtrl.add(TextEditingController(text: _formatWeight(initWeight)));
    _repsCtrl.add(TextEditingController(text: initReps > 0 ? '$initReps' : ''));
    _setMemoCtrl.add(TextEditingController());
    setState(() => _sets.add(newSet));
    _triggerSave();
  }

  Future<void> _showAddNextExercise() async {
    _commitSave();
    final targetSession = widget.sessionId != null
        ? (await SessionManager.instance.getAllSessions())
            .where((s) => s.id == widget.sessionId)
            .firstOrNull
        : SessionManager.instance.active;

    final doneNames = Set<String>.from(
      targetSession?.exercises.map((e) => e.name) ?? [],
    );
    if (!mounted) return;
    final routineNames = SessionManager.instance.routineExerciseNames;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ExercisePickerSheet(
        title: '次の種目を選択',
        markedNames: doneNames,
        headerSlot: _buildSessionPreview(targetSession),
        priorityNames: routineNames,
        allowMarkedTap: true,
        onSelected: (exercise) {
          final existingEx = targetSession?.exercises
              .where((e) => e.name == exercise.name)
              .firstOrNull;

          if (existingEx != null && targetSession != null) {
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
