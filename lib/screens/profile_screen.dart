import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../services/app_settings.dart';
import '../services/auth_service.dart';
import '../services/user_preferences.dart';
import '../services/session_manager.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl   = TextEditingController();
  final _weightCtrl = TextEditingController();
  String _gender = '男性';
  bool _shareStats = false;
  bool _isLoading = true;
  String? _imagePath;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = UserPreferences.instance;
    final name      = await prefs.getUsername();
    final weight    = await prefs.getBodyWeight();
    final gender    = await prefs.getGender();
    final share     = await prefs.getShareStats();
    final imagePath = await prefs.getProfileImagePath();
    if (mounted) {
      setState(() {
        _nameCtrl.text   = name;
        _weightCtrl.text = weight.toStringAsFixed(1);
        _gender          = gender;
        _shareStats      = share;
        _imagePath       = imagePath;
        _isLoading       = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 400,
    );
    if (image == null || !mounted) return;
    final docsDir = await getApplicationDocumentsDirectory();
    final ext     = p.extension(image.path).isNotEmpty ? p.extension(image.path) : '.jpg';
    final dest    = p.join(docsDir.path, 'profile_image$ext');
    await File(image.path).copy(dest);
    await UserPreferences.instance.setProfileImagePath(dest);
    if (mounted) setState(() => _imagePath = dest);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePrefs() async {
    FocusScope.of(context).unfocus();
    final weight = double.tryParse(_weightCtrl.text);
    if (weight == null || weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('体重に正しい数値を入力してください',
              style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: Colors.red.shade800,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final prefs = UserPreferences.instance;
    await prefs.setUsername(_nameCtrl.text.trim());
    await prefs.setBodyWeight(weight);
    await prefs.setGender(_gender);
    await prefs.setShareStats(_shareStats);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('プロフィールを保存しました',
            style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: context.cCardHigh,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        backgroundColor: context.cBg.withValues(alpha: 0.85),
        elevation: 0,
        title: Text(
          'PROFILE',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: kPrimary,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimary))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              children: [
                // ── アバター ──
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: context.cCardLow,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _imagePath != null && File(_imagePath!).existsSync()
                              ? Image.file(File(_imagePath!), fit: BoxFit.cover)
                              : Icon(Icons.person, size: 48, color: context.cBorder),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: kPrimary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit,
                                size: 15, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── ユーザー情報 ──
                _sectionHeader('ユーザー情報'),
                const SizedBox(height: 12),
                _buildCard(
                  children: [
                    _fieldRow(
                      label: 'ユーザー名',
                      child: _textField(_nameCtrl),
                    ),
                    Divider(height: 1, color: context.cCardHigh),
                    _fieldRow(
                      label: '体重',
                      child: _textField(
                        _weightCtrl,
                        inputType: TextInputType.number,
                        suffix: 'kg',
                      ),
                    ),
                    Divider(height: 1, color: context.cCardHigh),
                    _fieldRow(
                      label: '性別',
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: ['男性', '女性'].map((g) {
                          final active = _gender == g;
                          return GestureDetector(
                            onTap: () => setState(() => _gender = g),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 7),
                              decoration: BoxDecoration(
                                color: active
                                    ? kPrimary.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color:
                                      active ? kPrimary : context.cBorderSub,
                                ),
                              ),
                              child: Text(
                                g,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? kPrimary
                                      : context.cTextSub,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── アカウント ──
                _sectionHeader('アカウント'),
                const SizedBox(height: 12),
                _buildAccountCard(),
                const SizedBox(height: 24),

                // ── プライバシー ──
                _sectionHeader('プライバシー'),
                const SizedBox(height: 12),
                _buildPrivacyCard(),
                const SizedBox(height: 8),
                _buildPrivacyPolicyLink(),
                const SizedBox(height: 24),

                // ── 表示設定 ──
                _sectionHeader('表示設定'),
                const SizedBox(height: 12),
                _buildDisplayCard(),
                const SizedBox(height: 24),

                // ── サポート ──
                _sectionHeader('サポート'),
                const SizedBox(height: 12),
                _buildSupportCard(),
                const SizedBox(height: 24),

                // ── 統計 ──
                _sectionHeader('統計'),
                const SizedBox(height: 12),
                _buildStatsRow(),
                const SizedBox(height: 32),

                // ── 保存ボタン ──
                ElevatedButton(
                  onPressed: _savePrefs,
                  child: const Text('保存'),
                ),
              ],
            ),
    );
  }

  // ── 表示設定カード ────────────────────────────────────────────
  Widget _buildDisplayCard() {
    final isLight = AppSettings.instance.themeMode == ThemeMode.light;
    final scale   = AppSettings.instance.textScale;
    return Container(
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                Text('ライトモード',
                    style: GoogleFonts.jetBrainsMono(
                        fontSize: 11, color: context.cTextSub, letterSpacing: 0.5)),
                const Spacer(),
                Switch(
                  value: isLight,
                  activeThumbColor: kPrimary,
                  onChanged: (v) => AppSettings.instance
                      .setThemeMode(v ? ThemeMode.light : ThemeMode.dark),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.cCardHigh),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('文字サイズ',
                        style: GoogleFonts.jetBrainsMono(
                            fontSize: 11, color: context.cTextSub, letterSpacing: 0.5)),
                    const Spacer(),
                    Text(
                      scale <= 1.0 ? '標準' : scale <= 1.15 ? '大' : '特大',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: context.cText, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Slider(
                  value: scale,
                  min: 1.0,
                  max: 1.3,
                  divisions: 2,
                  activeColor: kPrimary,
                  inactiveColor: context.cCardHigh,
                  onChanged: (v) {
                    final snapped = v < 1.08 ? 1.0 : v < 1.22 ? 1.15 : 1.3;
                    AppSettings.instance.setTextScale(snapped);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── サポートカード ────────────────────────────────────────────
  Widget _buildSupportCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: InkWell(
        onTap: _showBugReportDialog,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: kTertiary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.bug_report_outlined,
                    size: 20, color: kTertiary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('不具合を報告',
                        style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.cText)),
                    const SizedBox(height: 2),
                    Text('バグ・改善要望をメールで送信',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: context.cTextSub)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, size: 20, color: context.cTextSub),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showBugReportDialog() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cCardLow,
        title: Text('不具合を報告',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: context.cText)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('発生した不具合や改善要望を入力してください。',
                style: GoogleFonts.inter(
                    fontSize: 13, color: context.cTextSub, height: 1.4)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: '例）カレンダーから記録すると保存されない...',
                filled: true,
                fillColor: context.cCardHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              style: GoogleFonts.inter(fontSize: 13, color: context.cText),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('キャンセル',
                style: GoogleFonts.inter(color: context.cTextSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('送信',
                style: GoogleFonts.inter(
                    color: kPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final body = Uri.encodeComponent(ctrl.text.trim().isEmpty
        ? '（内容なし）'
        : ctrl.text.trim());
    final uri = Uri.parse(
        'mailto:yuta.sakai.0724@gmail.com'
        '?subject=RepRank%20不具合報告'
        '&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  // ── 統計行（実データから計算）──────────────────────────────────
  Widget _buildStatsRow() {
    return FutureBuilder<List<dynamic>>(
      future: SessionManager.instance.getAllSessions(),
      builder: (context, snap) {
        final sessions = snap.data ?? [];
        final totalVolume = sessions.fold(
            0.0, (s, sess) => s + (sess.totalVolume as double));
        final streak = _calcStreak(sessions);

        return Row(
          children: [
            Expanded(
              child: _statCard(
                icon: Icons.fitness_center,
                label: 'トレーニング',
                value: '${sessions.length}',
                unit: '回',
                color: kPrimary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                icon: Icons.local_fire_department,
                label: '継続日数',
                value: '$streak',
                unit: '日',
                color: kTertiary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _statCard(
                icon: Icons.trending_up,
                label: '総ボリューム',
                value: totalVolume >= 1000
                    ? (totalVolume / 1000).toStringAsFixed(1)
                    : totalVolume.toStringAsFixed(0),
                unit: totalVolume >= 1000 ? 't' : 'kg',
                color: kSecondary,
              ),
            ),
          ],
        );
      },
    );
  }

  int _calcStreak(List sessions) {
    final dates = sessions.map((s) {
      final d = s.date as DateTime;
      return DateTime(d.year, d.month, d.day);
    }).toSet();
    int streak = 0;
    DateTime day = DateTime.now();
    day = DateTime(day.year, day.month, day.day);
    while (dates.contains(day)) {
      streak++;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ── ウィジェットヘルパー ────────────────────────────────────────

  Widget _sectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.jetBrainsMono(
          fontSize: 10, color: context.cTextSub, letterSpacing: 1.5),
    );
  }

  Widget _buildAccountCard() {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snap) {
        final user = snap.data;
        final isSignedIn = user != null && !(user.isAnonymous);

        if (isSignedIn) {
          // ログイン済み
          return Container(
            decoration: BoxDecoration(
              color: context.cCardLow,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle,
                            size: 20, color: kPrimary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('同期中',
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: kPrimary)),
                            const SizedBox(height: 2),
                            Text(
                              user.email ?? user.uid,
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: context.cTextSub),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: context.cCardHigh),
                InkWell(
                  onTap: _signOut,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Icon(Icons.logout,
                            size: 18, color: context.cTextSub),
                        const SizedBox(width: 12),
                        Text('ログアウト',
                            style: GoogleFonts.inter(
                                fontSize: 14, color: context.cTextSub)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // 未ログイン
        return GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const AuthScreen())),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: context.cCardLow,
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: context.cCardHigh,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.cloud_upload_outlined,
                      size: 20, color: context.cTextSub),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ログイン / アカウント作成',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: context.cText)),
                      const SizedBox(height: 2),
                      Text('データをバックアップ・複数端末で同期',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: context.cTextSub)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 20, color: context.cTextSub),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cCardLow,
        title: Text('ログアウト',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: context.cText)),
        content: Text('ログアウトしますか？\nデータはこの端末に保持されます。',
            style: GoogleFonts.inter(color: context.cTextSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('キャンセル',
                style: GoogleFonts.inter(color: context.cTextSub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('ログアウト',
                style: GoogleFonts.inter(
                    color: kPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true) await AuthService.instance.signOut();
  }

  Widget _buildPrivacyCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '匿名統計データを共有',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.cText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ヒストグラム機能の精度向上のため、種目名と体重比のみを匿名で送信します。個人を特定する情報は送信されません。',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: context.cTextSub,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: _shareStats,
            onChanged: (v) => setState(() => _shareStats = v),
            activeThumbColor: kPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPolicyLink() {
    return GestureDetector(
      onTap: () => launchUrl(
        Uri.parse(
            'https://yutasakai0724-ux.github.io/RepRank/privacy-policy.html'),
        mode: LaunchMode.externalApplication,
      ),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.cCardLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(Icons.privacy_tip_outlined,
                size: 18, color: context.cTextSub),
            const SizedBox(width: 12),
            Text(
              'プライバシーポリシー',
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.cText),
            ),
            const Spacer(),
            Icon(Icons.open_in_new,
                size: 14, color: context.cTextSub),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(children: children),
    );
  }

  Widget _fieldRow({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(label,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  color: context.cTextSub,
                  letterSpacing: 0.5)),
          const Spacer(),
          child,
        ],
      ),
    );
  }

  Widget _textField(TextEditingController ctrl,
      {TextInputType inputType = TextInputType.text, String? suffix}) {
    return SizedBox(
      width: 140,
      child: TextField(
        controller: ctrl,
        keyboardType: inputType,
        textAlign: TextAlign.right,
        style: GoogleFonts.inter(fontSize: 14, color: context.cText),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: kPrimary, width: 1),
          ),
          suffixText: suffix,
          suffixStyle: GoogleFonts.jetBrainsMono(
              fontSize: 12, color: context.cTextSub),
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: context.cCardLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: context.cText,
                      height: 1),
                ),
                TextSpan(
                  text: unit,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 11, color: context.cTextSub),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 9, color: context.cTextSub),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
