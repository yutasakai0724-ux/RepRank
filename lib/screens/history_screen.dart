import 'package:flutter/material.dart';
import '../utils/app_fonts.dart';
import '../theme.dart';
import '../models/workout.dart';
import '../services/session_manager.dart';
import '../utils/time_format.dart';
import 'exercise_record_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedDay;
  String? _searchFilter;
  TextEditingController? _autocompleteController;
  FocusNode? _autocompleteFocus;

  List<WorkoutSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  // 集計キャッシュ（_sessions / _searchFilter が変わったときだけ再計算）
  final Map<int, List<WorkoutSession>> _byDay = {};
  Set<int> _filteredDays = {};
  int _streak = 0;
  List<String> _recentExercises = [];
  String? _indexedFilter;

  int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  Future<void> _loadSessions({bool force = false}) async {
    final sm = SessionManager.instance;
    final sessions = force
        ? await sm.getAllSessions()
        : await sm.getAllSessionsCached();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
        _rebuildIndex();
      });
    }
  }

  void _rebuildIndex() {
    _byDay.clear();
    for (final s in _sessions) {
      _byDay.putIfAbsent(_dayKey(s.date), () => []).add(s);
    }
    _recentExercises = _sessions
        .expand((s) => s.exercises.map((e) => e.name))
        .toSet()
        .toList();

    final today = DateTime.now();
    var day = DateTime(today.year, today.month, today.day);
    var streak = 0;
    while (_byDay.containsKey(_dayKey(day))) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    _streak = streak;
    _rebuildFilteredDays();
  }

  void _rebuildFilteredDays() {
    _indexedFilter = _searchFilter;
    final f = _searchFilter;
    _filteredDays = {
      for (final e in _byDay.entries)
        if (f == null ||
            e.value.any((s) => s.exercises.any((x) => x.name == f)))
          e.key,
    };
  }

  bool _isWorkoutDay(DateTime day) {
    if (_indexedFilter != _searchFilter) _rebuildFilteredDays();
    return _filteredDays.contains(_dayKey(day));
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime day) => _isSameDay(day, DateTime.now());

  // 現在表示月のセッション
  List<WorkoutSession> get _monthSessions {
    return _sessions
        .where(
          (s) =>
              s.date.year == _focusedMonth.year &&
              s.date.month == _focusedMonth.month,
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        backgroundColor: context.cBg.withValues(alpha: 0.85),
        elevation: 0,
        title: Text(
          'WORKOUT',
          style: AppFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: kPrimary,
            letterSpacing: -0.5,
          ),
        ),
        actions: const [],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : RefreshIndicator(
              color: kPrimary,
              backgroundColor: context.cCardLow,
              onRefresh: () => _loadSessions(force: true),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  const SizedBox(height: 16),
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                  _buildCalendarCard(),
                  const SizedBox(height: 16),
                  _buildDayHeader(),
                  const SizedBox(height: 12),
                  ..._buildSessionCards(),
                  const SizedBox(height: 16),
                  _buildMonthlySummary(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  // ── 検索バー ─────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    // 最近記録された種目名（重複なし）
    final recentExercises = _recentExercises;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TapRegion(
          onTapOutside: (_) => _autocompleteFocus?.unfocus(),
          child: Autocomplete<String>(
            optionsBuilder: (TextEditingValue tv) {
              if (tv.text.isEmpty) return recentExercises;
              final q = tv.text;
              return defaultExercises
                  .map((e) => e['name'] as String)
                  .where((name) => name.contains(q))
                  .take(8);
            },
            displayStringForOption: (s) => s,
            onSelected: (String selection) {
              setState(() => _searchFilter = selection);
              Future.microtask(() {
                _autocompleteController?.clear();
                _autocompleteFocus?.unfocus();
              });
            },
            fieldViewBuilder: (ctx, ctrl, focusNode, onSubmitted) {
              _autocompleteController = ctrl;
              _autocompleteFocus = focusNode;
              return Container(
                decoration: BoxDecoration(
                  color: context.cCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: ctrl,
                  focusNode: focusNode,
                  // 決定キーでは候補を自動選択しない（候補はタップで選ぶ）
                  onSubmitted: (_) => focusNode.unfocus(),
                  style: AppFonts.inter(fontSize: 14, color: context.cText),
                  decoration: InputDecoration(
                    hintText: '種目を検索...',
                    hintStyle: AppFonts.inter(
                      fontSize: 14,
                      color: context.cTextSub,
                    ),
                    prefixIcon: Icon(Icons.search, color: context.cTextSub),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              );
            },
            optionsViewBuilder: (ctx, onSelected, options) {
              final isRecent = _autocompleteController?.text.isEmpty ?? true;
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  color: context.cCardLow,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(ctx).size.width - 32,
                      maxHeight: 220,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isRecent)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                            child: Text(
                              '最近の記録',
                              style: AppFonts.jetBrainsMono(
                                fontSize: 9,
                                color: context.cTextSub,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        Flexible(
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, color: Colors.white12),
                            itemBuilder: (ctx2, i) {
                              final option = options.elementAt(i);
                              return InkWell(
                                onTap: () => onSelected(option),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isRecent ? Icons.history : Icons.search,
                                        size: 14,
                                        color: context.cTextSub,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        option,
                                        style: AppFonts.inter(
                                          fontSize: 14,
                                          color: context.cText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_searchFilter != null) ...[
          const SizedBox(height: 8),
          InputChip(
            label: Text(
              _searchFilter!,
              style: AppFonts.inter(fontSize: 12, color: kPrimary),
            ),
            backgroundColor: kPrimary.withValues(alpha: 0.12),
            side: BorderSide(color: kPrimary.withValues(alpha: 0.3)),
            deleteIconColor: kPrimary,
            onDeleted: () {
              setState(() => _searchFilter = null);
              _autocompleteController?.clear();
            },
            visualDensity: VisualDensity.compact,
          ),
        ],
      ],
    );
  }

  // ── カレンダー ────────────────────────────────────────────────────
  Widget _buildCalendarCard() {
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final startWeekday = (firstDay.weekday - 1) % 7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$year年$month月',
                style: AppFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.cText,
                ),
              ),
              const Spacer(),
              _calNavBtn(Icons.chevron_left, () {
                setState(() => _focusedMonth = DateTime(year, month - 1));
              }),
              const SizedBox(width: 4),
              _calNavBtn(Icons.chevron_right, () {
                setState(() => _focusedMonth = DateTime(year, month + 1));
              }),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((d) {
              return Expanded(
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: AppFonts.jetBrainsMono(
                    fontSize: 11,
                    color: context.cTextSub,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: startWeekday + lastDay.day,
            itemBuilder: (_, idx) {
              if (idx < startWeekday) return const SizedBox();
              final day = DateTime(year, month, idx - startWeekday + 1);
              return _buildDayCell(day);
            },
          ),
        ],
      ),
    );
  }

  Widget _calNavBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.cCard,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: context.cTextSub),
      ),
    );
  }

  Widget _buildDayCell(DateTime day) {
    final isSelected = _selectedDay != null && _isSameDay(_selectedDay!, day);
    final isToday = _isToday(day);
    final hasWorkout = _isWorkoutDay(day);

    Color bgColor = Colors.transparent;
    Color textColor = context.cText;
    Border? border;

    if (isSelected) {
      bgColor = kPrimary.withValues(alpha: 0.2);
      textColor = kPrimary;
      border = Border.all(color: kPrimary.withValues(alpha: 0.4));
    } else if (isToday) {
      bgColor = kSecondary.withValues(alpha: 0.15);
      textColor = kSecondary;
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedDay = day),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: AppFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: (isSelected || isToday)
                    ? FontWeight.w700
                    : FontWeight.w400,
                color: textColor,
              ),
            ),
            if (hasWorkout)
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(top: 2),
                decoration: const BoxDecoration(
                  color: kPrimary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 日別セッション ──────────────────────────────────────────────
  Widget _buildDayHeader() {
    final day = _selectedDay ?? DateTime.now();
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final weekday = weekdays[day.weekday - 1];
    final streak = _calcStreak();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${day.month}月${day.day}日($weekday)',
          style: AppFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.cText,
          ),
        ),
        Text(
          '継続日数: $streak 日',
          style: AppFonts.jetBrainsMono(
            fontSize: 11,
            color: kPrimary,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSessionCards() {
    final day = _selectedDay ?? DateTime.now();
    final daySessions = (_byDay[_dayKey(day)] ?? const <WorkoutSession>[])
        .where((s) {
          if (_searchFilter == null) return true;
          return s.exercises.any((e) => e.name == _searchFilter);
        })
        .toList();

    if (daySessions.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              'この日のトレーニング記録はありません',
              style: AppFonts.inter(fontSize: 13, color: context.cTextSub),
            ),
          ),
        ),
      ];
    }

    return [
      for (final s in daySessions) ...[
        Dismissible(
          key: ValueKey(s.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) => _confirmDelete(s),
          onDismissed: (_) async {
            await SessionManager.instance.deleteSession(s.id);
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
          child: _sessionCard(s),
        ),
        const SizedBox(height: 10),
      ],
    ];
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

  Widget _sessionCard(WorkoutSession session) {
    final volume = session.totalVolume;
    final duration = session.finishedAt?.difference(session.startedAt);
    final startLabel = formatHM(session.startedAt);
    final hasRoutine = session.routineName != null;
    final iconColor = hasRoutine ? kPrimary : kTertiary;
    final exerciseNames = session.exercises.map((e) => e.name).join(', ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.fitness_center, color: iconColor, size: 26),
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
                            fontWeight: FontWeight.w600,
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
                    Text(
                      exerciseNames,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppFonts.inter(
                        fontSize: 12,
                        color: context.cTextSub,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.trending_up, size: 13, color: kTertiary),
                        const SizedBox(width: 4),
                        Text(
                          '${volume.toStringAsFixed(0)} kg',
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
            ],
          ),
          if (session.exercises.isNotEmpty) ...[
            const SizedBox(height: 10),
            Divider(height: 1, color: context.cCardHigh),
            const SizedBox(height: 6),
            for (final e in session.exercises) _exerciseRow(session, e),
          ],
        ],
      ),
    );
  }

  /// 種目1行。タップでその種目の記録画面へ遷移する。
  Widget _exerciseRow(WorkoutSession session, Exercise e) {
    final best = e.sets.isEmpty
        ? 0.0
        : e.sets.map((s) => s.oneRM).reduce((a, b) => a > b ? a : b);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ExerciseRecordScreen(exercise: e, sessionId: session.id),
        ),
      ).then((_) => _loadSessions()),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                e.name,
                style: AppFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.cText,
                ),
              ),
            ),
            Text(
              '${e.sets.length}セット',
              style: AppFonts.jetBrainsMono(
                fontSize: 11,
                color: context.cTextSub,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${best.toStringAsFixed(1)}kg',
              style: AppFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kPrimaryLight,
              ),
            ),
            Icon(Icons.chevron_right, color: context.cBorder, size: 18),
          ],
        ),
      ),
    );
  }

  // ── 月間サマリー ────────────────────────────────────────────────
  Widget _buildMonthlySummary() {
    final ms = _monthSessions;
    final totalVolume = ms.fold(0.0, (s, sess) => s + sess.totalVolume);
    final totalReps = ms
        .expand((s) => s.exercises)
        .expand((e) => e.sets)
        .fold(0, (s, set) => s + set.reps);
    final streak = _calcStreak();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MONTHLY OVERVIEW',
          style: AppFonts.jetBrainsMono(
            fontSize: 10,
            color: context.cTextSub,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statCard(
                label: '月間レップ数',
                value: totalReps >= 1000
                    ? '${(totalReps / 1000).toStringAsFixed(1)}k'
                    : '$totalReps',
                sub: null,
                subColor: null,
                valueColor: kPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                label: 'TOTAL VOLUME',
                value: totalVolume >= 1000
                    ? '${(totalVolume / 1000).toStringAsFixed(1)}t'
                    : '${totalVolume.toStringAsFixed(0)}kg',
                sub: null,
                subColor: null,
                valueColor: context.cText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _statCard(
                label: 'WORKOUTS',
                value: '${ms.length}',
                sub: null,
                subColor: null,
                valueColor: context.cText,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                label: 'STREAK',
                value: '$streak Days',
                sub: null,
                subColor: null,
                valueColor: context.cText,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 連続日数を計算（今日から遡って連続してワークアウトがある日数）
  int _calcStreak() => _streak;

  Widget _statCard({
    required String label,
    required String value,
    required String? sub,
    required Color? subColor,
    required Color valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppFonts.jetBrainsMono(
              fontSize: 9,
              color: context.cTextSub,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppFonts.jetBrainsMono(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.trending_up, size: 11, color: subColor),
                const SizedBox(width: 2),
                Text(
                  sub,
                  style: AppFonts.jetBrainsMono(fontSize: 9, color: subColor),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
