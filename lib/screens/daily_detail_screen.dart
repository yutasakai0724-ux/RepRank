import 'package:flutter/material.dart';
import '../utils/app_fonts.dart';
import '../theme.dart';
import '../models/workout.dart';
import '../services/session_manager.dart';
import '../services/training_time_service.dart';
import '../utils/time_format.dart';
import '../widgets/exercise_picker_sheet.dart';
import 'exercise_record_screen.dart';

class DailyDetailScreen extends StatefulWidget {
  final DateTime date;
  const DailyDetailScreen({super.key, required this.date});

  @override
  State<DailyDetailScreen> createState() => _DailyDetailScreenState();
}

class _DailyDetailScreenState extends State<DailyDetailScreen> {
  // セッション展開状態
  final Set<int> _expandedSessions = {0};

  List<WorkoutSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await SessionManager.instance.getSessionsForDate(
      widget.date,
    );
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    }
  }

  String get _dateLabel => formatJpDate(widget.date);

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
        title: Text(
          _dateLabel,
          style: AppFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.cText,
          ),
        ),
        actions: const [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _sessions.isEmpty
          ? _buildEmptyState()
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const SizedBox(height: 16),
                _buildStreakBanner(),
                const SizedBox(height: 16),
                ..._sessions.asMap().entries.map(
                  (e) => _buildDismissibleCard(e.key, e.value),
                ),
                const SizedBox(height: 80),
              ],
            ),
      // フッターの上に「この日の記録を追加」ボタン
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _addExerciseSheet,
              icon: const Icon(Icons.add, size: 20),
              label: Text(
                'この日の記録を追加',
                style: AppFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.fitness_center,
            size: 56,
            color: context.cTextSub.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          Text(
            'トレーニング記録はありません',
            style: AppFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.cTextSub,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '「この日の記録を追加」から種目を追加できます',
            style: AppFonts.inter(
              fontSize: 12,
              color: context.cTextSub.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakBanner() {
    // 今日から遡って連続ワークアウト日数を HistoryScreen と同じロジックで計算
    // ※ DailyDetailScreen は _sessions しか持たないためシンプルに表示
    final streakLabel = _sessions.isNotEmpty ? '記録あり' : '';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (streakLabel.isNotEmpty)
          Text(
            streakLabel,
            style: AppFonts.jetBrainsMono(
              fontSize: 12,
              color: kPrimary,
              letterSpacing: 1,
            ),
          )
        else
          const SizedBox.shrink(),
        Text(
          '${_sessions.length} セッション',
          style: AppFonts.jetBrainsMono(fontSize: 11, color: context.cTextSub),
        ),
      ],
    );
  }

  /// 記録カードの長押しで削除確認ダイアログを出す。
  Widget _buildDismissibleCard(int idx, WorkoutSession session) {
    return GestureDetector(
      onLongPress: () async {
        final ok = await _confirmDelete(session);
        if (ok != true) return;
        await SessionManager.instance.deleteSession(session.id);
        _loadSessions();
      },
      child: _buildSessionCard(idx, session),
    );
  }

  Future<bool?> _confirmDelete(WorkoutSession session) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cCardLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '記録を削除',
          style: AppFonts.inter(
            fontWeight: FontWeight.w700,
            color: context.cText,
          ),
        ),
        content: Text(
          '${session.sessionName ?? '記録'}を削除しますか？\nこの操作は元に戻せません。',
          style: AppFonts.inter(fontSize: 14, color: context.cTextSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'キャンセル',
              style: AppFonts.inter(color: context.cTextSub),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '削除',
              style: AppFonts.inter(
                color: Colors.red.shade400,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// トレーニング時間の行（開始〜終了と時間）。タップで開始・終了時刻を修正できる。
  /// 記録がなく、設定でトレーニング時間の記録がオフのときは表示しない。
  Widget _buildTrainingTimeRow(WorkoutSession session) {
    final has =
        session.trainingStartedAt != null && session.trainingEndedAt != null;
    if (!has && !TrainingTimeService.instance.enabled) {
      return const SizedBox.shrink();
    }
    final d = session.trainingDuration;
    final label = has
        ? '${formatHM(session.trainingStartedAt!)} 〜 ${formatHM(session.trainingEndedAt!)}'
            '${d != null ? '（${d.inMinutes}分）' : ''}'
        : '未記録（タップして追加）';
    return InkWell(
      onTap: () => _editTrainingTime(session),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.cCardHigh)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.timer_outlined, size: 14, color: kSecondary),
            const SizedBox(width: 6),
            Text('トレーニング時間',
                style: AppFonts.inter(fontSize: 11, color: context.cTextSub)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: AppFonts.jetBrainsMono(
                      fontSize: 11,
                      color: has ? context.cText : context.cTextSub)),
            ),
            Icon(Icons.edit_outlined, size: 14, color: context.cTextSub),
          ],
        ),
      ),
    );
  }

  /// 開始・終了時刻の修正ダイアログ。時刻は、この記録の日付上の時刻として保存する。
  Future<void> _editTrainingTime(WorkoutSession session) async {
    final day = session.date;
    DateTime onDay(TimeOfDay t) =>
        DateTime(day.year, day.month, day.day, t.hour, t.minute);
    TimeOfDay? start = session.trainingStartedAt == null
        ? null
        : TimeOfDay.fromDateTime(session.trainingStartedAt!);
    TimeOfDay? end = session.trainingEndedAt == null
        ? null
        : TimeOfDay.fromDateTime(session.trainingEndedAt!);

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> pick(bool isStart) async {
            final init = (isStart ? start : end) ??
                const TimeOfDay(hour: 18, minute: 0);
            final picked =
                await showTimePicker(context: ctx, initialTime: init);
            if (picked == null) return;
            setLocal(() => isStart ? start = picked : end = picked);
          }

          String fmt(TimeOfDay? t) => t == null
              ? '--:--'
              : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
          final invalid = start != null &&
              end != null &&
              !onDay(end!).isAfter(onDay(start!));
          return AlertDialog(
            backgroundColor: context.cCardLow,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('トレーニング時間を修正',
                style: AppFonts.inter(
                    fontWeight: FontWeight.w700, color: context.cText)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _timeRow('開始', fmt(start), () => pick(true)),
                const SizedBox(height: 8),
                _timeRow('終了', fmt(end), () => pick(false)),
                if (invalid) ...[
                  const SizedBox(height: 8),
                  Text('終了は開始より後の時刻にしてください',
                      style: AppFonts.inter(
                          fontSize: 12, color: Colors.red.shade400)),
                ],
              ],
            ),
            actions: [
              if (session.trainingStartedAt != null ||
                  session.trainingEndedAt != null)
                TextButton(
                  onPressed: () => Navigator.pop(ctx, 'clear'),
                  child: Text('消去',
                      style: AppFonts.inter(color: Colors.red.shade400)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('キャンセル',
                    style: AppFonts.inter(color: context.cTextSub)),
              ),
              TextButton(
                onPressed: (start == null || end == null || invalid)
                    ? null
                    : () => Navigator.pop(ctx, 'save'),
                child: Text('保存',
                    style: AppFonts.inter(
                        color: kPrimary, fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
    if (result == 'save' && start != null && end != null) {
      await SessionManager.instance
          .updateTrainingTime(session.id, onDay(start!), onDay(end!));
    } else if (result == 'clear') {
      await SessionManager.instance.updateTrainingTime(session.id, null, null);
    } else {
      return;
    }
    _loadSessions();
  }

  Widget _timeRow(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(label,
                  style: AppFonts.inter(fontSize: 13, color: context.cTextSub)),
            ),
            Text(value,
                style: AppFonts.jetBrainsMono(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: context.cText)),
            const Spacer(),
            Icon(Icons.access_time, size: 18, color: context.cTextSub),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(int idx, WorkoutSession session) {
    final isExpanded = _expandedSessions.contains(idx);
    final totalVolume = session.exercises.fold(
      0.0,
      (sum, ex) =>
          sum + ex.sets.fold(0.0, (s, set) => s + set.weight * set.reps),
    );
    final duration = session.trainingDuration;
    final startLabel = formatHM(session.startedAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          // セッションヘッダー（タップで展開）
          GestureDetector(
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedSessions.remove(idx);
              } else {
                _expandedSessions.add(idx);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // アイコン
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: kPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              session.sessionName ?? '記録',
                              style: AppFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.cText,
                              ),
                            ),
                            Text(
                              startLabel,
                              style: AppFonts.jetBrainsMono(
                                fontSize: 10,
                                color: context.cTextSub,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        // マイセット名 or 種目リスト
                        Text(
                          session.routineName != null
                              ? '${session.routineName} • ${session.exercises.map((e) => e.name).join(', ')}'
                              : session.exercises.map((e) => e.name).join(', '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppFonts.inter(
                            fontSize: 11,
                            color: context.cTextSub,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.trending_up, size: 13, color: kTertiary),
                            const SizedBox(width: 4),
                            Text(
                              '${totalVolume.toStringAsFixed(0)} kg',
                              style: AppFonts.jetBrainsMono(
                                fontSize: 11,
                                color: context.cText,
                              ),
                            ),
                            if (duration != null) ...[
                              const SizedBox(width: 14),
                              Icon(
                                Icons.timer_outlined,
                                size: 13,
                                color: kSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${duration.inMinutes} 分',
                                style: AppFonts.jetBrainsMono(
                                  fontSize: 11,
                                  color: context.cText,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: context.cBorder,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildTrainingTimeRow(session),
          // 展開時: 種目リスト
          if (isExpanded) ...[
            Divider(height: 1, color: context.cCardHigh),
            ...session.exercises.asMap().entries.map(
              (entry) => _buildExerciseRow(session, entry.key, entry.value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseRow(
    WorkoutSession session,
    int exIdx,
    Exercise exercise,
  ) {
    final totalVol = exercise.sets.fold(
      0.0,
      (s, set) => s + set.weight * set.reps,
    );
    final maxRM = exercise.sets.isEmpty
        ? 0.0
        : exercise.sets.map((s) => s.oneRM).reduce((a, b) => a > b ? a : b);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExerciseRecordScreen(
            exercise: exercise,
            sessionId: session.id, // その日のセッションに保存
          ),
        ),
      ).then((_) => _loadSessions()), // 戻ったらDBリフレッシュ
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: exIdx < session.exercises.length - 1
                  ? context.cCardHigh
                  : Colors.transparent,
            ),
          ),
        ),
        child: Row(
          children: [
            // マイセット構造インジケーター
            if (session.routineName != null) ...[
              Column(
                children: [
                  Container(
                    width: 2,
                    height: 36,
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // マイセット名 > 種目名
                  if (session.routineName != null)
                    Text(
                      session.routineName!,
                      style: AppFonts.jetBrainsMono(
                        fontSize: 9,
                        color: kPrimary.withValues(alpha: 0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                  Row(
                    children: [
                      if (session.routineName != null)
                        Text(
                          '› ',
                          style: AppFonts.jetBrainsMono(
                            fontSize: 12,
                            color: kPrimary,
                          ),
                        ),
                      Text(
                        exercise.name,
                        style: AppFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.cText,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: context.cCardHigh,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          exercise.muscleGroup.label,
                          style: AppFonts.jetBrainsMono(
                            fontSize: 9,
                            color: context.cTextSub,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // セットサマリー
                  Text(
                    '${exercise.sets.length} セット  •  ${totalVol.toStringAsFixed(0)} kg',
                    style: AppFonts.jetBrainsMono(
                      fontSize: 10,
                      color: context.cTextSub,
                    ),
                  ),
                ],
              ),
            ),
            // 最大1RM
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '1RM',
                  style: AppFonts.jetBrainsMono(
                    fontSize: 9,
                    color: context.cTextSub,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${maxRM.toStringAsFixed(1)}kg',
                  style: AppFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: context.cBorder, size: 18),
          ],
        ),
      ),
    );
  }

  void _addExerciseSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ExercisePickerSheet(
        onSelected: (exercise) async {
          // 当日の記録に同じ種目があれば編集モードで開く
          final existing = _sessions
              .expand(
                (s) => s.exercises
                    .where((e) => e.name == exercise.name)
                    .map((ex) => (session: s, exercise: ex)),
              )
              .firstOrNull;

          if (!context.mounted) return;

          if (existing != null) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExerciseRecordScreen(
                  exercise: existing.exercise,
                  sessionId: existing.session.id,
                ),
              ),
            );
          } else {
            // 新規種目 → 指定日付に記録（セッションは入力・保存時に作成される）
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExerciseRecordScreen(
                  exercise: exercise,
                  targetDate: widget.date,
                ),
              ),
            );
          }
          _loadSessions();
        },
      ),
    );
  }
}
