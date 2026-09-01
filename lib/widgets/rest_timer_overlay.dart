import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/rest_timer_service.dart';
import '../utils/time_format.dart';

/// アプリ全体（どの画面上でも）に表示する休憩タイマーの共通オーバーレイ。
/// 記録画面自身にタイマーUIがある間は RestTimerService.overlaySuppressed により非表示になる。
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
    final timer = RestTimerService.instance;
    final visible = timer.state != RestState.idle && !timer.overlaySuppressed;

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
                    child: _buildBar(context, timer),
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildBar(BuildContext context, RestTimerService timer) {
    final isFinished = timer.state == RestState.finished;
    final isPaused = timer.state == RestState.paused;

    return Material(
      color: Colors.transparent,
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
                formatMMSS(timer.remainingSec),
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
              onTap: () => timer.stop(),
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
    );
  }
}
