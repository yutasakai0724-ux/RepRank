import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../models/workout.dart';
import '../services/session_manager.dart';
import 'daily_detail_screen.dart';

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

  List<WorkoutSession> _sessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    final sessions = await SessionManager.instance.getAllSessions();
    if (mounted) {
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    }
  }

  bool _isWorkoutDay(DateTime day) {
    return _sessions.any((s) {
      if (!_isSameDay(s.date, day)) return false;
      if (_searchFilter == null) return true;
      return s.exercises.any((e) => e.name == _searchFilter);
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isToday(DateTime day) => _isSameDay(day, DateTime.now());

  // 現在表示月のセッション
  List<WorkoutSession> get _monthSessions {
    return _sessions.where((s) =>
        s.date.year == _focusedMonth.year &&
        s.date.month == _focusedMonth.month).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface.withValues(alpha: 0.85),
        elevation: 0,
        title: Text(
          'WORKOUT',
          style: GoogleFonts.inter(
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
              backgroundColor: kSurfaceContainerLow,
              onRefresh: _loadSessions,
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
    final recentExercises = _sessions
        .expand((s) => s.exercises.map((e) => e.name))
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Autocomplete<String>(
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
            Future.microtask(() => _autocompleteController?.clear());
          },
          fieldViewBuilder: (ctx, ctrl, focusNode, onSubmitted) {
            _autocompleteController = ctrl;
            return Container(
              decoration: BoxDecoration(
                color: kSurfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: ctrl,
                focusNode: focusNode,
                onSubmitted: (_) => onSubmitted(),
                style: GoogleFonts.inter(fontSize: 14, color: kOnSurface),
                decoration: InputDecoration(
                  hintText: '種目を検索...',
                  hintStyle:
                      GoogleFonts.inter(fontSize: 14, color: kOnSurfaceVariant),
                  prefixIcon:
                      const Icon(Icons.search, color: kOnSurfaceVariant),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
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
                color: kSurfaceContainerLow,
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
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              color: kOnSurfaceVariant,
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
                                    horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    Icon(
                                      isRecent
                                          ? Icons.history
                                          : Icons.search,
                                      size: 14,
                                      color: kOnSurfaceVariant,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      option,
                                      style: GoogleFonts.inter(
                                          fontSize: 14, color: kOnSurface),
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
        if (_searchFilter != null) ...[
          const SizedBox(height: 8),
          InputChip(
            label: Text(
              _searchFilter!,
              style: GoogleFonts.inter(fontSize: 12, color: kPrimary),
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
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                '$year年$month月',
                style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kOnSurface),
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
                child: Text(d,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 11, color: kOnSurfaceVariant)),
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
          color: kSurfaceContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: kOnSurfaceVariant),
      ),
    );
  }

  Widget _buildDayCell(DateTime day) {
    final isSelected =
        _selectedDay != null && _isSameDay(_selectedDay!, day);
    final isToday = _isToday(day);
    final hasWorkout = _isWorkoutDay(day);

    Color bgColor = Colors.transparent;
    Color textColor = kOnSurface;
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
      onTap: () {
        setState(() => _selectedDay = day);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DailyDetailScreen(date: day)),
        ).then((_) => _loadSessions()); // 戻ったらリフレッシュ
      },
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
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight:
                    (isSelected || isToday) ? FontWeight.w700 : FontWeight.w400,
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
          style: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w700, color: kOnSurface),
        ),
        Text(
          '継続日数: $streak 日',
          style: GoogleFonts.jetBrainsMono(
              fontSize: 11, color: kPrimary, letterSpacing: 1),
        ),
      ],
    );
  }

  List<Widget> _buildSessionCards() {
    final day = _selectedDay ?? DateTime.now();
    final daySessions = _sessions.where((s) {
      if (!_isSameDay(s.date, day)) return false;
      if (_searchFilter == null) return true;
      return s.exercises.any((e) => e.name == _searchFilter);
    }).toList();

    if (daySessions.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text(
              'この日のトレーニング記録はありません',
              style:
                  GoogleFonts.inter(fontSize: 13, color: kOnSurfaceVariant),
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
        backgroundColor: kSurfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '記録を削除',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: kOnSurface),
        ),
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

  Widget _sessionCard(WorkoutSession session) {
    final volume = session.totalVolume;
    final duration = session.finishedAt?.difference(session.startedAt);
    final h = session.startedAt.hour.toString().padLeft(2, '0');
    final m = session.startedAt.minute.toString().padLeft(2, '0');
    final hasRoutine = session.routineName != null;
    final iconColor = hasRoutine ? kPrimary : kTertiary;
    final exerciseNames =
        session.exercises.map((e) => e.name).join(', ');

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DailyDetailScreen(date: session.date),
        ),
      ).then((_) => _loadSessions()),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
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
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: kOnSurface),
                      ),
                      Text(
                        '$h:$m',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 10, color: kOnSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    exerciseNames,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                        fontSize: 12, color: kOnSurfaceVariant),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.trending_up, size: 13, color: kTertiary),
                      const SizedBox(width: 4),
                      Text(
                        '${volume.toStringAsFixed(0)} kg',
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
            const Icon(Icons.chevron_right, color: kOutline, size: 20),
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
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            color: kOnSurfaceVariant,
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
                valueColor: kOnSurface,
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
                valueColor: kOnSurface,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                label: 'STREAK',
                value: '$streak Days',
                sub: null,
                subColor: null,
                valueColor: kOnSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 連続日数を計算（今日から遡って連続してワークアウトがある日数）
  int _calcStreak() {
    final workoutDates = _sessions.map((s) {
      final d = s.date;
      return DateTime(d.year, d.month, d.day);
    }).toSet();

    int streak = 0;
    DateTime day = DateTime.now();
    day = DateTime(day.year, day.month, day.day);

    while (workoutDates.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

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
        color: kSurfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 9,
                  color: kOnSurfaceVariant,
                  letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(value,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: valueColor)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.trending_up, size: 11, color: subColor),
                const SizedBox(width: 2),
                Text(sub,
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 9, color: subColor)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
