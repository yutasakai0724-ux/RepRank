import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/user_preferences.dart';

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final _pageCtrl = PageController();
  int _page = 0;

  static const _totalPages = 2;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await UserPreferences.instance.setTutorialSeen();
    if (mounted) Navigator.of(context).pop();
  }

  void _next() {
    if (_page < _totalPages - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: Text(
                  'スキップ',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: context.cTextSub),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _TutorialPage1(),
                  _TutorialPage2(),
                ],
              ),
            ),
            // ドット インジケーター
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalPages, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _page == i ? kPrimary : context.cBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: ElevatedButton(
                onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: Text(
                  _page < _totalPages - 1 ? '次へ' : 'はじめる',
                  style: GoogleFonts.inter(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialPage1 extends StatelessWidget {
  const _TutorialPage1();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline, size: 44, color: kPrimary),
          ),
          const SizedBox(height: 28),
          Text(
            'プロフィールを設定しよう',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.cText,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _item(
            context,
            icon: Icons.fitness_center,
            title: '体重・性別を入力する',
            body: '体重と性別を登録すると、あなたの強度レベル（ティア）が自動で計算されます。',
          ),
          const SizedBox(height: 16),
          _item(
            context,
            icon: Icons.save_outlined,
            title: '必ず「保存」ボタンを押す',
            body: 'ユーザー情報の変更は保存ボタンを押すまで反映されません。設定後は忘れずに保存してください。',
          ),
          const SizedBox(height: 16),
          _item(
            context,
            icon: Icons.cloud_outlined,
            title: 'バックアップにはアカウント登録が必要',
            body: 'アカウント登録（Google・Apple・メール）するとトレーニング記録がクラウドに自動バックアップされます。未登録の場合、機種変更や再インストール時にデータが失われます。',
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context,
      {required IconData icon, required String title, required String body}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: kPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.cText,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: context.cTextSub,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TutorialPage2 extends StatelessWidget {
  const _TutorialPage2();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: kPrimary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_circle_outline,
                size: 44, color: kPrimary),
          ),
          const SizedBox(height: 28),
          Text(
            'トレーニングを記録しよう',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: context.cText,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          _item(
            context,
            icon: Icons.add,
            title: '＋ボタンで種目を追加',
            body: '画面下中央の＋ボタンを押して種目を選択すると、トレーニングの記録を開始できます。',
          ),
          const SizedBox(height: 16),
          _item(
            context,
            icon: Icons.bolt,
            title: 'セットごとに自動保存',
            body: '重量や回数を入力するたびに自動で保存されます。保存ボタンは不要です。',
          ),
          const SizedBox(height: 16),
          _item(
            context,
            icon: Icons.list_alt_outlined,
            title: 'ルーチンで効率よく管理',
            body: 'ルーチン画面で種目をまとめておくと、ワークアウト中に次の種目をすばやく選択できます。',
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context,
      {required IconData icon, required String title, required String body}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: kPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: kPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: context.cText,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                body,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: context.cTextSub,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
