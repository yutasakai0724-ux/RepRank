import 'package:flutter/material.dart';
import '../utils/app_fonts.dart';
import '../theme.dart';
import '../models/workout.dart';
import '../services/session_manager.dart';
import '../utils/time_format.dart';
import 'exercise_record_screen.dart';

/// 種目の「日ごとの記録」1件分（その日のベスト 1RM と、その記録への参照）。
class ExerciseHistoryPoint {
  final String date;
  final DateTime dateTime;
  final double oneRM;
  final int setCount;
  final double? sessionBodyWeightKg;
  final String sessionId;
  final Exercise exercise;
  const ExerciseHistoryPoint({
    required this.date,
    required this.dateTime,
    required this.oneRM,
    required this.setCount,
    required this.sessionId,
    required this.exercise,
    this.sessionBodyWeightKg,
  });
}

/// 指定種目の記録を日ごとにまとめる（同じ日に複数ある場合は 1RM が最大のもの）。
/// 日付の古い順で返す。
List<ExerciseHistoryPoint> buildExerciseHistory(
    List<WorkoutSession> sessions, String exerciseName) {
  final Map<String, ExerciseHistoryPoint> byDate = {};
  for (final s in sessions) {
    final dateKey = formatYMD(s.date);
    for (final ex in s.exercises) {
      if (ex.name != exerciseName || ex.sets.isEmpty) continue;
      final maxRM =
          ex.sets.map((x) => x.oneRM).reduce((a, b) => a > b ? a : b);
      if (maxRM > (byDate[dateKey]?.oneRM ?? 0)) {
        byDate[dateKey] = ExerciseHistoryPoint(
          date: dateKey,
          dateTime: s.date,
          oneRM: maxRM,
          setCount: ex.sets.length,
          sessionBodyWeightKg: s.bodyWeightKg,
          sessionId: s.id,
          exercise: ex,
        );
      }
    }
  }
  return byDate.values.toList()..sort((a, b) => a.date.compareTo(b.date));
}

/// 過去の記録の 1 行（日付・セット数・1RM）。ベストは強調表示する。
class ExerciseHistoryRow extends StatelessWidget {
  final ExerciseHistoryPoint point;
  final bool isBest;
  final VoidCallback onTap;

  const ExerciseHistoryRow({
    super.key,
    required this.point,
    required this.isBest,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = point;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isBest
              ? kTertiary.withValues(alpha: 0.1)
              : context.cCardHigh.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: isBest
              ? Border.all(color: kTertiary.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          children: [
            if (isBest) ...[
              const Icon(Icons.star, size: 14, color: kTertiary),
              const SizedBox(width: 6),
            ],
            Expanded(
              flex: 3,
              child: Text(
                formatJpDate(p.dateTime),
                style: AppFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.cText,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${p.setCount}セット',
                textAlign: TextAlign.center,
                style: AppFonts.jetBrainsMono(
                  fontSize: 11,
                  color: context.cTextSub,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '${p.oneRM.toStringAsFixed(1)}kg',
                textAlign: TextAlign.right,
                style: AppFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isBest ? kTertiary : kPrimaryLight,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: context.cBorder),
          ],
        ),
      ),
    );
  }
}

/// 種目の過去の記録一覧。新しい順に、月ごとの見出し付きで全件を表示する。
/// 行のタップでその記録の編集画面へ遷移し、戻ったときに一覧を読み直す。
class ExerciseHistoryScreen extends StatefulWidget {
  final String exerciseName;

  const ExerciseHistoryScreen({super.key, required this.exerciseName});

  @override
  State<ExerciseHistoryScreen> createState() => _ExerciseHistoryScreenState();
}

class _ExerciseHistoryScreenState extends State<ExerciseHistoryScreen> {
  List<ExerciseHistoryPoint> _points = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sessions = await SessionManager.instance.getAllSessions();
    final points = buildExerciseHistory(sessions, widget.exerciseName)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime)); // 新しい順
    if (mounted) {
      setState(() {
        _points = points;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 月ごとの見出しと記録を、1本のリストにする
    final items = <Object>[];
    String? lastMonth;
    for (final p in _points) {
      final month = '${p.dateTime.year}年${p.dateTime.month}月';
      if (month != lastMonth) {
        items.add(month);
        lastMonth = month;
      }
      items.add(p);
    }
    final best = _points.isEmpty
        ? 0.0
        : _points.map((p) => p.oneRM).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        backgroundColor: context.cBg.withValues(alpha: 0.85),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('過去の記録',
                style: AppFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.cText)),
            Text(widget.exerciseName,
                style: AppFonts.jetBrainsMono(
                    fontSize: 10, color: context.cTextSub)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : _points.isEmpty
              ? Center(
                  child: Text('記録がありません',
                      style: AppFonts.inter(
                          fontSize: 13, color: context.cTextSub)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    if (item is String) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                        child: Text(item,
                            style: AppFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: context.cTextSub,
                              letterSpacing: 1,
                            )),
                      );
                    }
                    final p = item as ExerciseHistoryPoint;
                    return ExerciseHistoryRow(
                      point: p,
                      isBest: p.oneRM == best,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ExerciseRecordScreen(
                            exercise: p.exercise,
                            sessionId: p.sessionId,
                          ),
                        ),
                      ).then((_) => _load()),
                    );
                  },
                ),
    );
  }
}
