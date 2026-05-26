import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'data/database_helper.dart';
import 'repositories/sqlite_workout_repository.dart';
import 'services/session_manager.dart';
import 'screens/analysis_screen.dart';
import 'screens/history_screen.dart';
import 'screens/exercise_record_screen.dart';
import 'screens/routines_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/exercise_picker_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 縦画面固定（Info.plist に加えてコードでも保証）
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // リポジトリを初期化して SessionManager に注入
  final repository = SqliteWorkoutRepository(DatabaseHelper.instance);
  SessionManager.instance.init(repository);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rep Rank',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // タブ切り替えごとに再生成することで常にフレッシュなデータを表示
  Widget _buildScreen(int index) {
    switch (index) {
      case 0: return const AnalysisScreen();
      case 1: return const HistoryScreen();
      case 2: return const RoutinesScreen();
      case 3: return const ProfileScreen();
      default: return const AnalysisScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildScreen(_currentIndex),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openExercisePicker(context),
        backgroundColor: kPrimary,
        foregroundColor: kOnPrimary,
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
    return BottomAppBar(
      color: kSurfaceContainer,
      elevation: 0,
      notchMargin: 6,
      shape: const CircularNotchedRectangle(),
      child: SizedBox(
        height: 60,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(0, Icons.analytics_outlined, Icons.analytics, '分析'),
            _navItem(1, Icons.calendar_month_outlined, Icons.calendar_month, 'カレンダー'),
            const SizedBox(width: 56),
            _navItem(2, Icons.flag_outlined, Icons.flag, 'ルーチン'),
            _navItem(3, Icons.person_outline, Icons.person, 'プロフィール'),
          ],
        ),
      ),
    );
  }

  Widget _navItem(int idx, IconData icon, IconData activeIcon, String label) {
    final active = _currentIndex == idx;
    return InkWell(
      onTap: () => setState(() => _currentIndex = idx),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? activeIcon : icon,
              size: 22,
              color: active ? kPrimary : kOnSurfaceVariant,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                color: active ? kPrimary : kOnSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openExercisePicker(BuildContext context) {
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
          );
        },
      ),
    );
  }
}
