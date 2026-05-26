import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../models/workout.dart';
import '../services/session_manager.dart';
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
    final sessions =
        await SessionManager.instance.getSessionsForDate(widget.date);
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    }
  }

  String get _dateLabel {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final w = weekdays[widget.date.weekday - 1];
    return '${widget.date.month}月${widget.date.day}日($w)';
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
        title: Text(
          _dateLabel,
          style: GoogleFonts.inter(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: kOnSurface,
          ),
        ),
        actions: [
          // 種目追加
          IconButton(
            icon: const Icon(Icons.add, color: kPrimary),
            onPressed: _addExerciseSheet,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: kOnSurfaceVariant),
            onPressed: () {},
          ),
        ],
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
                ..._sessions.asMap().entries.map((e) => _buildDismissibleCard(e.key, e.value)),
                const SizedBox(height: 80),
              ],
            ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          color: kPrimary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(Icons.add, color: Colors.white, size: 26),
          onPressed: _addExerciseSheet,
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
            color: kOnSurfaceVariant.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 16),
          Text(
            'トレーニング記録はありません',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: kOnSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '＋ボタンで種目を追加できます',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: kOnSurfaceVariant.withValues(alpha: 0.6),
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
            style: GoogleFonts.jetBrainsMono(
              fontSize: 12,
              color: kPrimary,
              letterSpacing: 1,
            ),
          )
        else
          const SizedBox.shrink(),
        Text(
          '${_sessions.length} セッション',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 11,
            color: kOnSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildDismissibleCard(int idx, WorkoutSession session) {
    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(session),
      onDismissed: (_) async {
        await SessionManager.instance.deleteSession(session.id);
        _loadSessions();
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade900,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text('削除', style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      child: _buildSessionCard(idx, session),
    );
  }

  Future<bool?> _confirmDelete(WorkoutSession session) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('記録を削除',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: kOnSurface)),
        content: Text(
          '${session.sessionName ?? '記録'}を削除しますか？\nこの操作は元に戻せません。',
          style: GoogleFonts.inter(fontSize: 14, color: kOnSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('キャンセル',
                style: GoogleFonts.inter(color: kOnSurfaceVariant)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('削除',
                style: GoogleFonts.inter(
                    color: Colors.red.shade400, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(int idx, WorkoutSession session) {
    final isExpanded = _expandedSessions.contains(idx);
    final totalVolume = session.exercises.fold(
      0.0,
      (sum, ex) => sum + ex.sets.fold(0.0, (s, set) => s + set.weight * set.reps),
    );
    final duration = session.finishedAt?.difference(session.startedAt);
    final startLabel =
        '${session.startedAt.hour.toString().padLeft(2, '0')}:${session.startedAt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
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
                    child: const Icon(Icons.fitness_center,
                        color: kPrimary, size: 22),
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
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: kOnSurface,
                              ),
                            ),
                            Text(
                              startLabel,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                color: kOnSurfaceVariant,
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
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: kOnSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.trending_up,
                                size: 13, color: kTertiary),
                            const SizedBox(width: 4),
                            Text(
                              '${totalVolume.toStringAsFixed(0)} kg',
                              style: GoogleFonts.jetBrainsMono(
                                  fontSize: 11, color: kOnSurface),
                            ),
                            if (duration != null) ...[
                              const SizedBox(width: 14),
                              Icon(Icons.timer_outlined,
                                  size: 13, color: kSecondary),
                              const SizedBox(width: 4),
                              Text(
                                '${duration.inMinutes} 分',
                                style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11, color: kOnSurface),
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
                    child: const Icon(Icons.keyboard_arrow_down,
                        color: kOutline, size: 22),
                  ),
                ],
              ),
            ),
          ),
          // 展開時: 種目リスト
          if (isExpanded) ...[
            const Divider(height: 1, color: kSurfaceContainerHigh),
            ...session.exercises.asMap().entries.map(
              (entry) => _buildExerciseRow(session, entry.key, entry.value),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseRow(WorkoutSession session, int exIdx, Exercise exercise) {
    final totalVol = exercise.sets
        .fold(0.0, (s, set) => s + set.weight * set.reps);
    final maxRM = exercise.sets.isEmpty
        ? 0.0
        : exercise.sets.map((s) => s.oneRM).reduce((a, b) => a > b ? a : b);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ExerciseRecordScreen(
            exercise: exercise,
            isEditMode: true,
          ),
        ),
      ).then((_) => _loadSessions()), // 戻ったらDBリフレッシュ
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: exIdx < session.exercises.length - 1
                  ? kSurfaceContainerHigh
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
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9,
                        color: kPrimary.withValues(alpha: 0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                  Row(
                    children: [
                      if (session.routineName != null)
                        Text('› ',
                            style: GoogleFonts.jetBrainsMono(
                                fontSize: 12, color: kPrimary)),
                      Text(
                        exercise.name,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kOnSurface,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: kSurfaceContainerHigh,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          exercise.muscleGroup.label,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            color: kOnSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // セットサマリー
                  Text(
                    '${exercise.sets.length} セット  •  ${totalVol.toStringAsFixed(0)} kg',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: kOnSurfaceVariant,
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
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: kOnSurfaceVariant,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${maxRM.toStringAsFixed(1)}kg',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: kOutline, size: 18),
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
        onSelected: (exercise) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExerciseRecordScreen(exercise: exercise),
            ),
          ).then((_) => _loadSessions());
        },
      ),
    );
  }
}
