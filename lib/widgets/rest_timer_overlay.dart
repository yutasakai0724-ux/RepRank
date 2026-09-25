import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/rest_timer_service.dart';
import '../services/navigation_service.dart';
import '../utils/time_format.dart';
import '../screens/exercise_record_screen.dart';

/// アプリ全体（どの画面上でも）に表示する休憩タイマーの共通オーバーレイ。
/// 種目ごとに独立したタイマーを、進行中のものだけ上から順に縦に並べて表示する。
/// 記録画面自身にタイマーUIがある間は、その種目分だけ RestTimerService の
/// isSuppressed により非表示になる。バーをタップするとその種目の記録画面に遷移する。
class RestTimerOverlay extends StatefulWidget {
  const RestTimerOverlay({super.key});

  @override
  State<RestTimerOverlay> createState() => _RestTimerOverlayState();
}

class _RestTimerOverlayState extends State<RestTimerOverlay> {
  @override
  void initState() {
    super.initState();
    RestTimerService.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    RestTimerService.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final service = RestTimerService.instance;
    final entries = service.activeEntries
        .where((e) => !service.isSuppressed(e.key))
        .toList();
    final visible = entries.isNotEmpty;

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: visible
            ? SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final entry in entries) ...[
                          _buildBar(context, entry),
                          const SizedBox(height: 6),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  void _openExercise(RestTimerEntry entry) {
    // このウィジェットは MaterialApp.builder 内、Navigator の外側（兄弟要素）に
    // 配置されているため、Navigator.of(context) では親 Navigator が見つからない。
    // ルートの GlobalKey 経由で遷移する。
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ExerciseRecordScreen(
          exercise: entry.exercise,
          sessionId: entry.sessionId,
        ),
      ),
    );
  }

  Widget _buildBar(BuildContext context, RestTimerEntry entry) {
    final isFinished = entry.state == RestState.finished;
    final isPaused = entry.state == RestState.paused;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openExercise(entry),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isFinished ? kTertiary : context.cCardHigh,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isFinished ? Icons.check_circle : Icons.timer,
                color: isFinished ? Colors.white : kSecondary,
                size: 18,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  entry.exercise.name,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isFinished
                        ? Colors.white.withValues(alpha: 0.9)
                        : context.cTextSub,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              if (isFinished)
                Text(
                  '休憩終了！',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                )
              else ...[
                Text(
                  formatMMSS(entry.remainingSec),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isPaused ? context.cTextSub : kSecondary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isPaused ? '一時停止中' : '休憩中',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: context.cTextSub,
                  ),
                ),
              ],
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => RestTimerService.instance.stop(entry.key),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: isFinished
                      ? Colors.white.withValues(alpha: 0.8)
                      : context.cTextSub,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
