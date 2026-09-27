import 'dart:async';
import 'package:flutter/material.dart';
import '../utils/app_fonts.dart';
import '../theme.dart';
import '../models/workout.dart';
import '../services/analytics_service.dart';
import '../services/cloud_data_service.dart';
import '../services/rest_timer_service.dart';
import '../services/session_manager.dart';
import '../services/stopwatch_service.dart';
import '../services/training_time_service.dart';
import '../services/user_preferences.dart';
import '../utils/time_format.dart';
import '../widgets/duration_picker_sheet.dart';
import 'exercise_analysis_screen.dart';

class ExerciseRecordScreen extends StatefulWidget {
  final Exercise exercise;

  /// 保存先セッションID。null の場合はアクティブセッション（今日）に保存。
  final String? sessionId;

  /// sessionId が無く、今日以外の日付へ新規に記録する場合の対象日。
  /// セッションは最初に保存されるとき（データが入力されたとき）に作成する。
  final DateTime? targetDate;

  const ExerciseRecordScreen({
    super.key,
    required this.exercise,
    this.sessionId,
    this.targetDate,
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
  String? _prevSessionId;

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
    if (widget.sessionId == null && _target != null) {
      _sessionDate = _target!;
      _loadBodyWeight();
    } else if (widget.sessionId == null) {
      _initSession();
    } else {
      _resolvedSessionId = widget.sessionId;
      _loadBodyWeight();
      _loadSessionDate();
    }
  }

  /// 編集中の記録の日付（sessionId 未指定＝今日の新規記録）。
  DateTime _sessionDate = DateTime.now();

  bool get _isPast {
    final n = DateTime.now();
    return _sessionDate.year != n.year ||
        _sessionDate.month != n.month ||
        _sessionDate.day != n.day;
  }

  Future<void> _loadSessionDate() async {
    // キャッシュに無い（直前に作成された等）場合は DB から取り直す
    var sessions = await SessionManager.instance.getAllSessionsCached();
    var s = sessions.where((s) => s.id == widget.sessionId).firstOrNull;
    if (s == null) {
      sessions = await SessionManager.instance.getAllSessions();
      s = sessions.where((s) => s.id == widget.sessionId).firstOrNull;
    }
    if (s != null && mounted) setState(() => _sessionDate = s!.date);
  }

  String _dateLabel(DateTime d) {
    const w = ['月', '火', '水', '木', '金', '土', '日'];
    return '${d.year}/${d.month}/${d.day}(${w[d.weekday - 1]})';
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
      final session = sessions
          .where((s) => s.id == _resolvedSessionId)
          .firstOrNull;
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
      beforeDate: _target, // 今日以外への新規記録は、その日より前を「前回」にする
    );
    if (mounted) {
      setState(() {
        _prevRecord = record?.exercise;
        _prevSessionId = record?.sessionId;
      });
    }
  }

  /// 前回の記録の全セット（重量・回数）を現在の入力にペーストする。
  /// [withMemo] が true ならセットごとのメモも含める。false の場合、メモは
  /// 現在入力済みの同じ番号のセットのものを残す。
  void _pasteFromPrevious({required bool withMemo}) {
    final prev = _prevRecord;
    if (prev == null || prev.sets.isEmpty) return;
    final oldMemos = [for (final c in _setMemoCtrl) c.text];
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
      final oldMemo = i < oldMemos.length ? oldMemos[i] : '';
      final memo = withMemo ? ps.memo : (oldMemo.isEmpty ? null : oldMemo);
      newSets.add(
        WorkoutSet(
          setNumber: i + 1,
          weight: ps.weight,
          reps: ps.reps,
          memo: memo,
          recordedAt: DateTime.now(),
        ),
      );
      newWeightCtrl.add(TextEditingController(text: _formatWeight(ps.weight)));
      newRepsCtrl.add(
        TextEditingController(text: ps.reps > 0 ? '${ps.reps}' : ''),
      );
      newMemoCtrl.add(TextEditingController(text: memo ?? ''));
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
    // null=キャンセル, true=メモを含める, false=記録のみ
    final choice = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cCardLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '前回の記録をペースト',
          style: AppFonts.inter(
            fontWeight: FontWeight.w700,
            color: context.cText,
          ),
        ),
        content: Text(
          '現在入力中の全セットの重量・回数が前回の記録で上書きされます。',
          style: AppFonts.inter(fontSize: 13, color: context.cTextSub),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'キャンセル',
              style: AppFonts.inter(color: context.cTextSub),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'メモを含めペースト',
              style: AppFonts.inter(
                color: kPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              '記録のみペースト',
              style: AppFonts.inter(
                color: kPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (choice != null) _pasteFromPrevious(withMemo: choice);
  }

  Future<void> _loadRestDuration() async {
    final saved = await UserPreferences.instance.getRestDuration();
    RestTimerService.instance.setDuration(
      widget.exercise,
      widget.sessionId,
      saved,
    );
  }

  @override
  void dispose() {
    RestTimerService.instance.removeListener(_onTimerChanged);
    RestTimerService.instance.unsuppressOverlay(_timerKey);
    _saveDebounce?.cancel();
    _uiRefreshTimer?.cancel();
    _commitSave(); // コントローラ破棄前に保存内容を確定する
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
    // 連続入力のたびに画面全体を再構築しないよう、状態が変わるときだけ setState する
    if (_saveStatus != 'saving') setState(() => _saveStatus = 'saving');
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () async {
      await _commitSaveAsync();
      if (mounted) setState(() => _saveStatus = 'saved');
      _maybePromptTrainingStart();
    });
  }

  /// 今日を指定された場合は通常の新規記録（アクティブセッション）として扱う。
  DateTime? get _target {
    final d = widget.targetDate;
    if (d == null) return null;
    final n = DateTime.now();
    return (d.year == n.year && d.month == n.month && d.day == n.day)
        ? null
        : d;
  }

  /// 開始し忘れの確認を出した日（アプリ起動中は1日1回まで）
  static int? _promptedDayKey;

  /// 今日の記録を保存した時点で、トレーニング時間の記録がオンなのに開始されていなければ、
  /// 「トレーニングを開始しますか？」と確認する（「今後は表示しない」を選べる）。
  Future<void> _maybePromptTrainingStart() async {
    final svc = TrainingTimeService.instance;
    if (!mounted ||
        !svc.enabled ||
        svc.isRunning ||
        svc.suppressStartPrompt ||
        _isPast) {
      return;
    }
    // 実際にセットが記録されているときだけ確認する
    if (!_sets.any((s) => s.reps > 0 || s.weight > 0)) return;
    final n = DateTime.now();
    final key = n.year * 10000 + n.month * 100 + n.day;
    if (_promptedDayKey == key) return;
    _promptedDayKey = key;

    var dontShowAgain = false;
    final start = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: context.cCardLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'トレーニングを開始しますか？',
            style: AppFonts.inter(
              fontWeight: FontWeight.w700,
              color: context.cText,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'トレーニング時間の記録がまだ開始されていません。今から開始して、時間を記録しますか？',
                style: AppFonts.inter(fontSize: 13, color: context.cTextSub),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setLocal(() => dontShowAgain = !dontShowAgain),
                child: Row(
                  children: [
                    Checkbox(
                      value: dontShowAgain,
                      activeColor: kPrimary,
                      onChanged: (v) =>
                          setLocal(() => dontShowAgain = v ?? false),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '今後はこのお知らせを表示しない',
                            style: AppFonts.inter(
                              fontSize: 13,
                              color: context.cText,
                            ),
                          ),
                          Text(
                            '（設定から変更できます）',
                            style: AppFonts.inter(
                              fontSize: 11,
                              color: context.cTextSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'あとで',
                style: AppFonts.inter(color: context.cTextSub),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                '開始する',
                style: AppFonts.inter(
                  color: kPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (dontShowAgain) await svc.setSuppressStartPrompt(true);
    if (start == true) {
      // 今すぐ記録した直後なので「記録あり」として開始する
      StopwatchService.instance.start();
      await svc.start(hasRecordNow: true);
    }
  }

  Future<String>? _targetSessionFuture;

  /// 対象日のセッションIDを返す。その日に既にセッションがあればそれを使い、
  /// 無ければ作成する（保存が重なっても1つだけ作る）。
  Future<String> _ensureTargetSession() {
    return _targetSessionFuture ??= () async {
      final date = _target!;
      final existing = await SessionManager.instance.getSessionsForDate(date);
      final id = existing.isNotEmpty
          ? existing.first.id
          : (await SessionManager.instance.createSessionForDate(date)).id;
      _resolvedSessionId = id;
      return id;
    }();
  }

  Future<void> _commitSaveAsync() async {
    // 意味のあるデータがある場合のみ保存（選択しただけでは記録にならない）
    final hasData =
        _sets.any(
          (s) => s.reps > 0 || s.weight > 0 || (s.memo?.isNotEmpty ?? false),
        ) ||
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
      await SessionManager.instance.saveExerciseToExistingSession(
        widget.sessionId!,
        exercise,
      );
    } else if (_target != null) {
      final id = await _ensureTargetSession();
      await SessionManager.instance.saveExerciseToExistingSession(id, exercise);
    } else {
      await SessionManager.instance.saveExercise(exercise);
    }
    unawaited(
      AnalyticsService.instance.logExerciseRecorded(
        exerciseName: widget.exercise.name,
        setCount: _sets.length,
      ),
    );

    if (_currentMaxRM > 0) {
      final weight = await UserPreferences.instance.getBodyWeight();
      if (weight > 0) {
        unawaited(
          CloudDataService.instance.recordRatio(
            exerciseName: widget.exercise.name,
            ratio: _currentMaxRM / weight,
          ),
        );
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
        title: Text(
          'この記録の体重',
          style: AppFonts.inter(
            fontWeight: FontWeight.w700,
            color: context.cText,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppFonts.inter(color: context.cText),
          decoration: InputDecoration(
            suffixText: 'kg',
            suffixStyle: AppFonts.jetBrainsMono(color: context.cTextSub),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: context.cBorderSub),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: kPrimary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'キャンセル',
              style: AppFonts.inter(color: context.cTextSub),
            ),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(ctrl.text);
              Navigator.pop(ctx, v);
            },
            child: Text(
              '保存',
              style: AppFonts.inter(
                color: kPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (result != null && result > 0 && mounted) {
      await SessionManager.instance.updateSessionBodyWeight(
        _resolvedSessionId!,
        result,
      );
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
              if (_isPast) _buildPastBanner(),
              // 休憩タイマーだけを上部に固定。過去の記録・メモはセットと一緒にスクロールする。
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildRestTimer(),
              ),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildStatsCard(),
                    _buildOverallMemo(),
                    _buildColumnHeader(),
                    for (int i = 0; i < _sets.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildSetRow(i),
                      ),
                  ],
                ),
              ),
              _buildAddSetOnlyBar(),
            ],
          ),
        ),
      ),
    );
  }

  /// 今日以外の記録を編集中であることを目立たせる帯。
  Widget _buildPastBanner() {
    return Container(
      width: double.infinity,
      color: kPrimary.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.history, size: 14, color: kPrimary),
          const SizedBox(width: 6),
          Text(
            '${_dateLabel(_sessionDate)}の記録を編集中',
            style: AppFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kPrimary,
            ),
          ),
        ],
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
            style: AppFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: kPrimary,
              letterSpacing: -0.5,
            ),
          ),
          Row(
            children: [
              Text(
                widget.exercise.muscleGroup.label,
                style: AppFonts.jetBrainsMono(
                  fontSize: 10,
                  color: context.cTextSub,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.event,
                size: 11,
                color: _isPast ? kPrimary : context.cTextSub,
              ),
              const SizedBox(width: 2),
              Text(
                _isPast ? _dateLabel(_sessionDate) : '今日',
                style: AppFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: _isPast ? FontWeight.w700 : FontWeight.w400,
                  color: _isPast ? kPrimary : context.cTextSub,
                ),
              ),
            ],
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
              style: AppFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.cText,
              ),
            ),
            Text(
              '体重 ✎',
              style: AppFonts.jetBrainsMono(
                fontSize: 8,
                color: context.cTextSub,
              ),
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
          Text(label, style: AppFonts.jetBrainsMono(fontSize: 8, color: color)),
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
      child: Row(children: [_unitBtn('kg', _isKg), _unitBtn('lbs', !_isKg)]),
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
          style: AppFonts.jetBrainsMono(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: active ? kPrimary : context.cTextSub,
          ),
        ),
      ),
    );
  }

  /// 前回の記録欄。欄全体のタップで、その記録の編集画面へ遷移する。
  /// ペーストボタンは誤タップを避けるため、欄の右下に大きめに配置する。
  Widget _buildPrevRecordCell() {
    final prev = _prevRecord;
    final hasPrev = prev != null && prev.sets.isNotEmpty;
    return Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: hasPrev && _prevSessionId != null
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ExerciseRecordScreen(
                      exercise: prev,
                      sessionId: _prevSessionId,
                    ),
                  ),
                ).then((_) => _loadPrevRecord())
              : null,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '前回の記録',
                    style: AppFonts.jetBrainsMono(
                      fontSize: 9,
                      color: context.cTextSub,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (hasPrev)
                    Icon(
                      Icons.chevron_right,
                      size: 12,
                      color: context.cTextSub,
                    ),
                ],
              ),
              const SizedBox(height: 4),
              if (hasPrev)
                ...prev.sets
                    .take(3)
                    .map(
                      (s) => Text(
                        '${s.weight.toStringAsFixed(1)}kg × ${s.reps}',
                        style: AppFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kPrimaryLight,
                        ),
                      ),
                    )
              else
                Text(
                  '--',
                  style: AppFonts.jetBrainsMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.cTextSub,
                  ),
                ),
            ],
          ),
        ),
        if (hasPrev) ...[
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _confirmPasteFromPrevious,
              child: Container(
                constraints: const BoxConstraints(minHeight: 40, minWidth: 64),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kPrimary.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.content_paste, size: 16, color: kPrimary),
                    const SizedBox(width: 4),
                    Text(
                      'ペースト',
                      style: AppFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
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
          Expanded(child: _buildPrevRecordCell()),
          Container(width: 1, height: 36, color: Colors.white12),
          Expanded(
            child: Column(
              children: [
                Text(
                  '現在の最大1RM',
                  style: AppFonts.jetBrainsMono(
                    fontSize: 9,
                    color: context.cTextSub,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_currentMaxRM.toStringAsFixed(1)}kg',
                  style: AppFonts.jetBrainsMono(
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
                    style: AppFonts.jetBrainsMono(
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
        style: AppFonts.inter(fontSize: 13, color: context.cText),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          icon: Icon(
            Icons.sticky_note_2_outlined,
            size: 16,
            color: context.cTextSub,
          ),
          hintText: 'この種目のメモ（フォーム・意識点など）',
          hintStyle: AppFonts.inter(fontSize: 12, color: context.cTextSub),
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
    final isPaused = state == RestState.paused;
    final isFinished = state == RestState.finished;
    final isIdle = state == RestState.idle;

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
        style: AppFonts.inter(
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
                style: AppFonts.jetBrainsMono(
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
        onTap: () =>
            RestTimerService.instance.start(widget.exercise, widget.sessionId),
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
                style: AppFonts.jetBrainsMono(
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
      ValueListenableBuilder<int>(
        valueListenable: RestTimerService.instance.tick,
        builder: (_, __, ___) => Text(
          formatMMSS(
            RestTimerService.instance.entryFor(_timerKey)?.remainingSec ?? 0,
          ),
          style: AppFonts.jetBrainsMono(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: isPaused ? context.cTextSub : kSecondary,
            letterSpacing: 1,
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        isPaused ? '一時停止' : '休憩中',
        style: AppFonts.jetBrainsMono(
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
        style: AppFonts.inter(
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
            style: AppFonts.jetBrainsMono(
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
            child: Text(
              'SET',
              style: AppFonts.jetBrainsMono(
                fontSize: 9,
                color: context.cTextSub,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              '重量',
              textAlign: TextAlign.center,
              style: AppFonts.jetBrainsMono(
                fontSize: 9,
                color: context.cTextSub,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              '回数',
              textAlign: TextAlign.center,
              style: AppFonts.jetBrainsMono(
                fontSize: 9,
                color: context.cTextSub,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              '1RM推定',
              textAlign: TextAlign.right,
              style: AppFonts.jetBrainsMono(
                fontSize: 9,
                color: context.cTextSub,
                letterSpacing: 1,
              ),
            ),
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
                  style: AppFonts.jetBrainsMono(
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
                child: SizedBox(
                  height: _inputRowHeight,
                  child: _weightInput(i),
                ),
              ),
              const SizedBox(width: 8),
              // 回数 ± カウンター（キーボード入力も可、1RM推定近くまで幅を使う）
              Expanded(flex: 4, child: _repsCounter(i)),
              const SizedBox(width: 8),
              // 1RM推定
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: kTertiary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${s.oneRM.toStringAsFixed(1)}kg',
                      style: AppFonts.jetBrainsMono(
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
              style: AppFonts.inter(fontSize: 11, color: context.cTextSub),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                hintText: 'セットメモ',
                hintStyle: AppFonts.inter(
                  fontSize: 11,
                  color: context.cTextSub.withValues(alpha: 0.5),
                ),
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
      style: AppFonts.jetBrainsMono(
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
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
              style: AppFonts.jetBrainsMono(
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
        _counterBtn(icon: Icons.add, onTap: () => _setReps(i, reps + 1)),
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

  Widget _counterBtn({required IconData icon, required VoidCallback? onTap}) {
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
          color: onTap != null
              ? context.cText
              : context.cTextSub.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  // ── ボトムバー（セット追加 ＋ 次の種目） ──────────────────

  /// セット追加のみ（次の種目は＋ボタンで今日の記録に追加する）
  Widget _buildAddSetOnlyBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GestureDetector(
        onTap: _addSet,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
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
                style: AppFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.cTextSub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addSet() {
    final num = _sets.length + 1;
    final prevSet = _sets.isNotEmpty ? _sets.last : null;
    final initWeight = prevSet?.weight ?? 0.0;
    final initReps = prevSet?.reps ?? 0;
    final newSet = WorkoutSet(
      setNumber: num,
      weight: initWeight,
      reps: initReps,
    );
    _weightCtrl.add(TextEditingController(text: _formatWeight(initWeight)));
    _repsCtrl.add(TextEditingController(text: initReps > 0 ? '$initReps' : ''));
    _setMemoCtrl.add(TextEditingController());
    setState(() => _sets.add(newSet));
    _triggerSave();
  }
}
