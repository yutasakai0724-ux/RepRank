import 'package:flutter/material.dart';
import '../theme.dart';
import '../screens/exercise_record_screen.dart';
import '../services/session_manager.dart';
import 'exercise_picker_sheet.dart';

/// メイン画面（分析〜設定）の下部ナビゲーション。
/// メインタブ画面と、過去記録の編集画面などの詳細画面で共通に使う。
/// 中央の＋ボタンは [MainBottomBar.addButton] を Scaffold の
/// floatingActionButton（centerDocked）に置いて使う。
class MainBottomBar extends StatelessWidget {
  final int? currentIndex;
  final ValueChanged<int> onTap;

  const MainBottomBar({super.key, required this.currentIndex, required this.onTap});

  static Widget addButton(BuildContext context) => FloatingActionButton(
        onPressed: () => openTodayExercisePicker(context),
        backgroundColor: kPrimary,
        foregroundColor: kOnPrimary,
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      );

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: context.cCard,
      elevation: 0,
      notchMargin: 6,
      shape: const CircularNotchedRectangle(),
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(context, 0, Icons.analytics_outlined, Icons.analytics, '分析'),
            _navItem(context, 1, Icons.calendar_month_outlined, Icons.calendar_month, 'カレンダー'),
            const SizedBox(width: 56),
            _navItem(context, 2, Icons.flag_outlined, Icons.flag, 'ルーチン'),
            _navItem(context, 3, Icons.settings_outlined, Icons.settings, '設定'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(BuildContext context, int idx, IconData icon, IconData activeIcon, String label) {
    final active = currentIndex == idx;
    return InkWell(
      onTap: () => onTap(idx),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? activeIcon : icon,
                size: 22,
                color: active ? kPrimary : context.cTextSub),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? kPrimary : context.cTextSub,
                )),
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
        final existing =
            await SessionManager.instance.findTodayExercise(exercise.name);
        if (!context.mounted) return;
        if (existing != null) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ExerciseRecordScreen(
              exercise: existing.exercise,
              sessionId: existing.session.id,
            ),
          ));
        } else {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ExerciseRecordScreen(exercise: exercise),
          ));
        }
      },
    ),
  );
}
