import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../models/workout.dart';
import '../services/session_manager.dart';
import 'exercise_analysis_screen.dart';
import '../widgets/exercise_picker_sheet.dart';

class ExerciseRecordScreen extends StatefulWidget {
  final Exercise exercise;
  final bool isEditMode;
  const ExerciseRecordScreen({
    super.key,
    required this.exercise,
    this.isEditMode = false,
  });

  @override
  State<ExerciseRecordScreen> createState() => _ExerciseRecordScreenState();
}

class _ExerciseRecordScreenState extends State<ExerciseRecordScreen> {
  bool _isKg = true;
  int _elapsedSec = 0;
  Timer? _elapsedTimer;
  Timer? _saveDebounce;
  late List<WorkoutSet> _sets;
  late List<TextEditingController> _weightCtrl;
  late List<TextEditingController> _repsCtrl;

  // 保存状態: 'saved' | 'saving' | 'unsaved'
  String _saveStatus = 'saved';

  WorkoutSet? _prevBestSet;

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

    // セッションタイマー（SessionManagerの開始時刻から計算）
    final session = SessionManager.instance.getOrCreate();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSec =
            DateTime.now().difference(session.startedAt).inSeconds;
      });
    });

    // 編集モードでない場合は即座にセッションに登録 & 前回ベストを取得
    if (!widget.isEditMode) {
      _triggerSave();
      _loadPrevBest();
    }
  }

  Future<void> _loadPrevBest() async {
    final best = await SessionManager.instance
        .getPreviousBest(widget.exercise.name);
    if (mounted) setState(() => _prevBestSet = best);
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _saveDebounce?.cancel();
    for (final c in _weightCtrl) { c.dispose(); }
    for (final c in _repsCtrl) { c.dispose(); }
    // 画面を離れる直前に確実に保存
    _commitSave();
    super.dispose();
  }

  // ── 自動保存 ────────────────────────────────────────

  /// 入力変更時に呼ぶ。300ms デバウンス後に DB 保存
  void _triggerSave() {
    setState(() => _saveStatus = 'saving');
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 300), () async {
      await _commitSaveAsync();
      if (mounted) setState(() => _saveStatus = 'saved');
    });
  }

  /// SessionManager + DB に即座に書き込む（await 可能版）
  Future<void> _commitSaveAsync() async {
    if (widget.isEditMode) return;
    final exercise = Exercise(
      name: widget.exercise.name,
      muscleGroup: widget.exercise.muscleGroup,
      sets: List.from(_sets),
    );
    await SessionManager.instance.saveExercise(exercise);
  }

  /// dispose から呼ぶ fire-and-forget 版
  void _commitSave() {
    _commitSaveAsync();
  }

  // ── 表示ヘルパー ─────────────────────────────────────

  String get _elapsedDisplay {
    final m = _elapsedSec ~/ 60;
    final s = _elapsedSec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  double get _currentMaxRM {
    if (_sets.isEmpty) return 0;
    return _sets.map((s) => s.oneRM).reduce((a, b) => a > b ? a : b);
  }


  // ── ビルド ───────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStatsCard(),
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
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
            widget.exercise.muscleGroup.label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: kOnSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        // 経過時間
        if (!widget.isEditMode)
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _elapsedDisplay,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kPrimary,
                ),
              ),
              Text(
                '経過時間',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  color: kOnSurfaceVariant,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        const SizedBox(width: 8),
        // 自動保存インジケーター
        _buildSaveIndicator(),
        // kg/lbs トグル
        _unitToggle(),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildSaveIndicator() {
    final (icon, color, label) = switch (_saveStatus) {
      'saving' => (Icons.sync, kOnSurfaceVariant, '保存中'),
      'saved'  => (Icons.cloud_done_outlined, kTertiary, '保存済'),
      _        => (Icons.edit_outlined, kPrimary, '未保存'),
    };
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8,
              color: color,
            ),
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
        color: kSurfaceContainerLow,
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
                    color: kOnSurfaceVariant,
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
                    color: _prevBestSet != null
                        ? kPrimaryLight
                        : kOnSurfaceVariant,
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
                    color: kOnSurfaceVariant,
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
          // 分析ボタン
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
                    color: _currentMaxRM > 0 ? kPrimary : kOnSurfaceVariant.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '分析',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      color: _currentMaxRM > 0 ? kPrimary : kOnSurfaceVariant.withValues(alpha: 0.3),
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

  Widget _buildColumnHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('SET',
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, color: kOnSurfaceVariant, letterSpacing: 1)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text('重量',
                textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, color: kOnSurfaceVariant, letterSpacing: 1)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text('回数',
                textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, color: kOnSurfaceVariant, letterSpacing: 1)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text('1RM推定',
                textAlign: TextAlign.right,
                style: GoogleFonts.jetBrainsMono(
                    fontSize: 9, color: kOnSurfaceVariant, letterSpacing: 1)),
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
        color: kSurfaceContainerLow,
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
                // setState なし：入力を邪魔しない
                final parsed = double.tryParse(v);
                if (parsed != null) {
                  s.weight = _isKg ? parsed : parsed / 2.20462;
                  s.recordedAt = DateTime.now();
                }
              },
              onDone: () {
                setState(() {}); // 1RM バッジを更新
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
              icon: const Icon(Icons.close, color: kOutline),
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
        fillColor: kSurfaceHighest.withValues(alpha: 0.5),
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
      // Enter キーまたはフォーカスアウトで1RM更新・保存
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
            // セットを追加
            GestureDetector(
              onTap: _addSet,
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: kOutlineVariant,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, color: kOnSurfaceVariant, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'セットを追加',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: kOnSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!widget.isEditMode) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  // 次の種目を追加
                  Expanded(
                    flex: 3,
                    child: GestureDetector(
                      onTap: _showAddNextExercise,
                      child: Container(
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
                  ),
                  const SizedBox(width: 10),
                  // ワークアウト終了
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _finishWorkout,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: kSurfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: kTertiary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline,
                                color: kTertiary, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              '終了',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: kTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _finishWorkout() async {
    // 最終セットを保存してからセッション終了
    await _commitSaveAsync();
    final session = await SessionManager.instance.finish();
    if (!mounted) return;

    // サマリーダイアログ
    final duration = session?.duration ?? Duration.zero;
    final totalVolume = session?.totalVolume ?? 0.0;
    final exerciseCount = session?.exercises.length ?? 0;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.emoji_events, color: kTertiary, size: 24),
            const SizedBox(width: 8),
            Text(
              'ワークアウト完了！',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                color: kOnSurface,
                fontSize: 17,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 4),
            _summaryRow(
              Icons.fitness_center,
              '種目数',
              '$exerciseCount 種目',
              kPrimary,
            ),
            const SizedBox(height: 12),
            _summaryRow(
              Icons.timer_outlined,
              '時間',
              '${duration.inMinutes} 分',
              kSecondary,
            ),
            const SizedBox(height: 12),
            _summaryRow(
              Icons.trending_up,
              'ボリューム',
              '${totalVolume.toStringAsFixed(0)} kg',
              kTertiary,
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                // ルートまで戻る
                Navigator.of(context)
                    .popUntil((route) => route.isFirst);
              },
              child: Text(
                '完了',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
      IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
                fontSize: 11, color: kOnSurfaceVariant),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kOnSurface,
          ),
        ),
      ],
    );
  }

  void _addSet() {
    final num = _sets.length + 1;
    // 前のセットの値を初期値として引き継ぐ（UX改善）
    final prevSet = _sets.isNotEmpty ? _sets.last : null;
    final initWeight = prevSet?.weight ?? 0.0;
    final initReps = prevSet?.reps ?? 0;
    final newSet = WorkoutSet(setNumber: num, weight: initWeight, reps: initReps);
    final weightText = initWeight > 0
        ? (_isKg ? initWeight.toStringAsFixed(1) : (initWeight * 2.20462).toStringAsFixed(1))
        : '';
    _weightCtrl.add(TextEditingController(text: weightText));
    _repsCtrl.add(TextEditingController(text: initReps > 0 ? '$initReps' : ''));
    setState(() => _sets.add(newSet));
    _triggerSave();
  }

  void _showAddNextExercise() {
    _commitSave();
    final doneNames = Set<String>.from(
      SessionManager.instance.active?.exercises.map((e) => e.name) ?? [],
    );
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ExercisePickerSheet(
        title: '次の種目を選択',
        markedNames: doneNames,
        headerSlot: _buildSessionPreview(),
        onSelected: (exercise) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExerciseRecordScreen(exercise: exercise),
            ),
          );
        },
      ),
    );
  }

  /// シート内に現在のセッション進捗を小さく表示
  Widget _buildSessionPreview() {
    final session = SessionManager.instance.active;
    if (session == null || session.exercises.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: kSurfaceContainerHigh,
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
                color: kOnSurfaceVariant,
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
