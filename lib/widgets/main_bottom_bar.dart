import 'package:flutter/material.dart';
import '../theme.dart';
import '../screens/exercise_record_screen.dart';
import '../services/navigation_service.dart';
import '../services/session_manager.dart';
import 'exercise_picker_sheet.dart';

/// 全画面共通の下部ナビゲーション（MaterialApp.builder で全ページの下に表示する）。
/// 中央の＋は今日の記録に種目を追加する。
class MainBottomBar extends StatelessWidget {
  /// タブ下端からアイコン下端までの距離 = 下余白6 + ラベル12 + 隙間2
  static const double _iconBottomInset = 20;

  /// 表示上のバー上端（80pxの範囲の上から）。＋の中心 = 下から48px = 上から32px。
  static const double _barVisualTop = 32;

  const MainBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ValueListenableBuilder<int>(
        valueListenable: mainTabIndex,
        builder: (context, index, _) => _buildBar(context, index),
      ),
    );
  }

  Widget _buildBar(BuildContext context, int currentIndex) {
    // 範囲（高さ80）はそのままに、見た目は初期デザイン（＋を囲う円形の凹み付き）。
    // 表示上のバーは下から48px。＋（56px）の中心がバー上端に乗る = 初期のフロートボタンと同じ位置関係。
    return CustomPaint(
      painter: _NotchedBarPainter(
        color: context.cCard,
        barTop: _barVisualTop,
        notchGuestRadius: 34,
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _navItem(
                context,
                currentIndex,
                0,
                Icons.analytics_outlined,
                Icons.analytics,
                '分析',
              ),
              _navItem(
                context,
                currentIndex,
                1,
                Icons.calendar_month_outlined,
                Icons.calendar_month,
                'カレンダー',
              ),
              _addItem(context),
              _navItem(
                context,
                currentIndex,
                2,
                Icons.flag_outlined,
                Icons.flag,
                'ルーチン',
              ),
              _navItem(
                context,
                currentIndex,
                3,
                Icons.settings_outlined,
                Icons.settings,
                '設定',
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 一番目立たせたい機能なので、初期のフロートボタンと同じ角丸四角・56pxサイズ。
  /// 下端は他のタブの「アイコン」の下端に揃える（ラベル文字の下端ではない）。
  Widget _addItem(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _iconBottomInset),
      child: Material(
        color: kPrimary,
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => openTodayExercisePicker(
            rootNavigatorKey.currentContext ?? context,
          ),
          borderRadius: BorderRadius.circular(16),
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.add, size: 28, color: kOnPrimary),
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    int currentIndex,
    int idx,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final active = currentIndex == idx;
    return InkWell(
      onTap: () => goToMainTab(idx),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? activeIcon : icon,
              size: 22,
              color: active ? kPrimary : context.cTextSub,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                height: 1.2, // ラベル高さを12pxに固定（アイコン下端の位置計算用）
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? kPrimary : context.cTextSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ＋ボタン: 種目を選んで「今日（リアルタイム）」の記録に追加する。
void openTodayExercisePicker(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ExercisePickerSheet(
      onSelected: (exercise) async {
        final existing = await SessionManager.instance.findTodayExercise(
          exercise.name,
        );
        if (!context.mounted) return;
        if (existing != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExerciseRecordScreen(
                exercise: existing.exercise,
                sessionId: existing.session.id,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ExerciseRecordScreen(exercise: exercise),
            ),
          );
        }
      },
    ),
  );
}

/// 平らなバーの上端に、＋ボタンを囲う円形の凹みをつけて描く。
class _NotchedBarPainter extends CustomPainter {
  final Color color;
  final double barTop;
  final double notchGuestRadius;

  const _NotchedBarPainter({
    required this.color,
    required this.barTop,
    required this.notchGuestRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final host = Rect.fromLTRB(0, barTop, size.width, size.height);
    final guest = Rect.fromCircle(
      center: Offset(size.width / 2, barTop),
      radius: notchGuestRadius,
    );
    final path = const CircularNotchedRectangle().getOuterPath(host, guest);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_NotchedBarPainter old) =>
      old.color != color ||
      old.barTop != barTop ||
      old.notchGuestRadius != notchGuestRadius;
}
