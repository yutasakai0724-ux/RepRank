import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'utils/app_fonts.dart';
import 'theme.dart';
import 'models/workout.dart';
import 'services/rest_timer_service.dart';
import 'services/stopwatch_service.dart';
import 'services/navigation_service.dart';
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
import 'screens/tutorial_screen.dart';
import 'screens/history_screen.dart';
import 'screens/exercise_record_screen.dart';
import 'screens/routines_screen.dart';
import 'screens/profile_screen.dart';
import 'widgets/exercise_picker_sheet.dart';
import 'widgets/banner_ad_widget.dart';
import 'widgets/rest_timer_overlay.dart';
import 'services/app_settings.dart';
import 'services/notification_service.dart';
import 'services/live_activity_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await FirebaseInit.initialize();
  await AdService.instance.initialize();
  await AppSettings.instance.load();
  await NotificationService.instance.initialize();
  await LiveActivityService.instance.initialize();
  // 通知タップでアプリが起動された場合の遷移先を保留しておく
  // （ハンドラは _AuthGateState.initState で登録される）
  unawaited(NotificationService.instance.checkLaunchDetails());

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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    AppSettings.instance.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    AppSettings.instance.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Rep Rank',
      debugShowCheckedModeBanner: false,
      themeMode: AppSettings.instance.themeMode,
      theme: buildLightTheme(),
      darkTheme: buildAppTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(AppSettings.instance.textScale),
        ),
        child: Stack(
          children: [
            child!,
            const RestTimerOverlay(),
          ],
        ),
      ),
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
    // 休憩タイマー通知タップ → 該当種目の記録画面へ遷移
    NotificationService.instance.setNavigationHandler(_navigateToExerciseTimer);
    // 通知の「タイマーをリセット」ボタン → 該当種目の休憩タイマーを停止
    NotificationService.instance
        .setResetHandler((key) => RestTimerService.instance.stop(key));
    // 通知の「タイマーをリセット」（ワークアウト時間） → ストップウォッチをリセット
    NotificationService.instance
        .setStopwatchResetHandler(() => StopwatchService.instance.reset());
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPrivacyConsent();
      await _checkTutorial();
      await _checkNotificationPrompt();
    });
  }

  /// 通知タップで渡された種目キー（種目名）から記録画面を復元して遷移する。
  /// アプリ実行中に開始されたタイマーなら RestTimerService に情報が残っているので
  /// それを優先し、なければ現在のセッション・過去のセッションから種目を探す。
  Future<void> _navigateToExerciseTimer(String exerciseKey) async {
    final entry = RestTimerService.instance.entryFor(exerciseKey);
    Exercise? exercise = entry?.exercise;
    String? sessionId = entry?.sessionId;

    if (exercise == null) {
      final active = SessionManager.instance.active;
      exercise =
          active?.exercises.where((e) => e.name == exerciseKey).firstOrNull;
      sessionId = active?.id;
    }
    if (exercise == null) {
      final sessions = await SessionManager.instance.getAllSessions();
      for (final s in sessions) {
        final found =
            s.exercises.where((e) => e.name == exerciseKey).firstOrNull;
        if (found != null) {
          exercise = found;
          sessionId = s.id;
          break;
        }
      }
    }
    if (exercise == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExerciseRecordScreen(
          exercise: exercise!,
          sessionId: sessionId,
        ),
      ),
    );
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
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PrivacyConsentScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _checkTutorial() async {
    final seen = await UserPreferences.instance.hasTutorialSeen();
    if (seen || !mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const TutorialScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  Future<void> _checkNotificationPrompt() async {
    final shown = await UserPreferences.instance.hasShownNotificationPrompt();
    if (shown || !mounted) return;
    await UserPreferences.instance.setNotificationPromptShown();

    final wantsNotification = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cCardLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('通知を許可しますか？',
            style: AppFonts.inter(
                fontWeight: FontWeight.w700, color: context.cText)),
        content: Text(
          'トレーニング時間の計測・休憩タイマーの終了をお知らせするために通知を使用します。'
          'アプリを離れていても経過時間や残り時間を確認できます。',
          style: AppFonts.inter(fontSize: 13, color: context.cTextSub),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('後で',
                style: AppFonts.inter(color: context.cTextSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('許可する',
                style: AppFonts.inter(
                    color: kPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (wantsNotification == true) {
      final granted = await NotificationService.instance.requestPermission();
      if (granted) {
        await UserPreferences.instance.setRestNotification(true);
      }
    }
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
      color: context.cCard,
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
            _navItem(3, Icons.settings_outlined, Icons.settings, '設定'),
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
