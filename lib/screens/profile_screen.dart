import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/user_preferences.dart';
import '../services/session_manager.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl   = TextEditingController();
  final _weightCtrl = TextEditingController();
  String _gender = '男性';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = UserPreferences.instance;
    final name   = await prefs.getUsername();
    final weight = await prefs.getBodyWeight();
    final gender = await prefs.getGender();
    if (mounted) {
      setState(() {
        _nameCtrl.text   = name;
        _weightCtrl.text = weight.toStringAsFixed(1);
        _gender          = gender;
        _isLoading       = false;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePrefs() async {
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

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('プロフィールを保存しました',
            style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: kSurfaceContainerHigh,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kSurface.withValues(alpha: 0.85),
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
                  child: Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: kSurfaceContainerLow,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child:
                            const Icon(Icons.person, size: 48, color: kOutline),
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
                    const Divider(height: 1, color: kSurfaceContainerHigh),
                    _fieldRow(
                      label: '体重',
                      child: _textField(
                        _weightCtrl,
                        inputType: TextInputType.number,
                        suffix: 'kg',
                      ),
                    ),
                    const Divider(height: 1, color: kSurfaceContainerHigh),
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
                                      active ? kPrimary : kOutlineVariant,
                                ),
                              ),
                              child: Text(
                                g,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: active
                                      ? kPrimary
                                      : kOnSurfaceVariant,
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

                // ── 統計 ──
                _sectionHeader('統計'),
                const SizedBox(height: 12),
                _buildStatsRow(),
                const SizedBox(height: 32),

                // ── 保存ボタン ──
                GestureDetector(
                  onTap: _savePrefs,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: kPrimary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: kPrimary.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '保存',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
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
          fontSize: 10, color: kOnSurfaceVariant, letterSpacing: 1.5),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceContainerLow,
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
                  color: kOnSurfaceVariant,
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
        style: GoogleFonts.inter(fontSize: 14, color: kOnSurface),
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
              fontSize: 12, color: kOnSurfaceVariant),
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
        color: kSurfaceContainerLow,
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
                      color: kOnSurface,
                      height: 1),
                ),
                TextSpan(
                  text: unit,
                  style: GoogleFonts.jetBrainsMono(
                      fontSize: 11, color: kOnSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: GoogleFonts.jetBrainsMono(
                  fontSize: 9, color: kOnSurfaceVariant),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
