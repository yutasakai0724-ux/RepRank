import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme.dart';
import 'data/database_helper.dart';
import 'repositories/sqlite_workout_repository.dart';
import 'repositories/firestore_workout_repository.dart';
import 'repositories/hybrid_workout_repository.dart';
import 'services/firebase_init.dart';
import 'services/analytics_service.dart';
import 'services/ad_service.dart';
import 'services/auth_service.dart';
import 'services/sync_service.dart';
import 'services/session_manager.dart';
import 'services/user_preferences.dart';
import 'screens/analysis_screen.dart';
import 'screens/privacy_consent_screen.dart';
import 'screens/history_screen.dart';
import 'screens/exercise_record_screen.dart';
import 'screens/routines_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/exercise_picker_sheet.dart';
import 'widgets/banner_ad_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await FirebaseInit.initialize();
  await AdService.instance.initialize();

  // 初期リポジトリ（SQLiteのみ）で起動
  final local = SqliteWorkoutRepository(DatabaseHelper.instance);
  SessionManager.instance.init(local);

  // ログイン済みならハイブリッドリポジトリに差し替え
  final user = AuthService.instance.currentUser;
  if (user != null && !user.isAnonymous) {
    _switchToHybrid(user.uid);
  }

  runApp(const MyApp());
}

/// ログイン時にリポジトリをハイブリッド（SQLite + Firestore）に切り替える
void _switchToHybrid(String uid) {
  final local = SqliteWorkoutRepository(DatabaseHelper.instance);
  final cloud = FirestoreWorkoutRepository(uid);
  SessionManager.instance.init(
    HybridWorkoutRepository(local: local, cloud: cloud),
  );
}

/// ローカルのみのリポジトリに戻す（ログアウト時）
void _switchToLocal() {
  final local = SqliteWorkoutRepository(DatabaseHelper.instance);
  SessionManager.instance.init(local);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rep Rank',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AuthGate(),
    );
  }
}

/// 認証状態を監視してリポジトリを切り替えるゲート。
/// UIは変えず、バックグラウンドで同期処理を行う。
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  @override
  void initState() {
    super.initState();
    AuthService.instance.authStateChanges.listen(_onAuthChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkPrivacyConsent());
  }

  Future<void> _onAuthChanged(User? user) async {
    if (user != null && !user.isAnonymous) {
      _switchToHybrid(user.uid);
      await SyncService.instance.syncOnLogin(user.uid);
    } else {
      _switchToLocal();
    }
  }

  Future<void> _checkPrivacyConsent() async {
    final consented = await UserPreferences.instance.hasConsentedToPrivacy();
    if (consented || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PrivacyConsentScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => const MainNavigation();
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  static const _screenNames = ['analysis', 'history', 'routines', 'profile'];

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    AnalyticsService.instance.logScreenView(_screenNames[index]);
  }

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
      body: Column(
        children: [
          Expanded(child: _buildScreen(_currentIndex)),
          const BannerAdWidget(),
        ],
      ),
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
      onTap: () => _onTabTapped(idx),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? activeIcon : icon,
                size: 22,
                color: active ? kPrimary : kOnSurfaceVariant),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight:
                      active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? kPrimary : kOnSurfaceVariant,
                )),
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
}
