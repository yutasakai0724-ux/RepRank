import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/auth_service.dart';

/// ログイン / 新規登録画面。
/// サインイン成功時に自動的に Navigator がポップする（呼び出し元で authStateChanges を監視）。
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscure = true;
  String? _errorMsg;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    final email = _emailCtrl.text.trim();
    final pass = _passwordCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorMsg = 'メールアドレスとパスワードを入力してください');
      return;
    }
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      if (_isLogin) {
        await AuthService.instance.signInWithEmail(email, pass);
      } else {
        await AuthService.instance.createWithEmail(email, pass);
      }
      if (mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _errorMsg = AuthService.errorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInGoogle() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final user = await AuthService.instance.signInWithGoogle();
      if (user != null && mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _errorMsg = AuthService.errorMessage(e));
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Google エラー: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInApple() async {
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      final user = await AuthService.instance.signInWithApple();
      if (user != null && mounted) Navigator.of(context).pop();
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _errorMsg = AuthService.errorMessage(e));
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Apple サインインエラー: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        backgroundColor: context.cBg,
        elevation: 0,
        title: Text(
          _isLogin ? 'ログイン' : 'アカウント作成',
          style: GoogleFonts.inter(
              fontSize: 18, fontWeight: FontWeight.w700, color: kPrimary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── ロゴ ──
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: kPrimary.withValues(alpha: 0.3), width: 2),
                  ),
                  child: const Icon(Icons.fitness_center,
                      size: 36, color: kPrimary),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text('Rep Rank',
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: kPrimary)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'ログインするとデータをクラウドに\nバックアップ・同期できます',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: context.cTextSub, height: 1.5),
                ),
              ),
              const SizedBox(height: 32),

              // ── ソーシャルログイン ──
              _socialButton(
                onTap: _signInApple,
                icon: Icons.apple,
                label: 'Apple でサインイン',
                bg: Colors.white,
                fg: Colors.black,
              ),
              const SizedBox(height: 10),
              _socialButton(
                onTap: _signInGoogle,
                icon: Icons.g_mobiledata,
                label: 'Google でサインイン',
                bg: const Color(0xFF4285F4),
                fg: Colors.white,
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: Divider(color: context.cCardHigh)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('または',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: context.cTextSub)),
                ),
                Expanded(child: Divider(color: context.cCardHigh)),
              ]),
              const SizedBox(height: 24),

              // ── メール/パスワード ──
              _inputField(
                controller: _emailCtrl,
                label: 'メールアドレス',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _inputField(
                controller: _passwordCtrl,
                label: 'パスワード',
                obscure: _obscure,
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      size: 20,
                      color: context.cTextSub),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),

              if (_isLogin) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: _showPasswordReset,
                    child: Text('パスワードを忘れた方',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: kPrimary)),
                  ),
                ),
              ],

              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Text(_errorMsg!,
                      style: GoogleFonts.inter(
                          fontSize: 13, color: Colors.red.shade300)),
                ),
              ],

              const SizedBox(height: 20),

              // ── 送信ボタン ──
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: kPrimary))
                  : GestureDetector(
                      onTap: _submitEmail,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: kPrimary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: kPrimary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            _isLogin ? 'ログイン' : 'アカウントを作成',
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ),

              const SizedBox(height: 20),

              // ── 切り替え ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLogin ? 'アカウントをお持ちでない方は' : 'すでにアカウントをお持ちの方は',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: context.cTextSub),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _isLogin = !_isLogin;
                      _errorMsg = null;
                    }),
                    child: Text(
                      _isLogin ? '新規登録' : 'ログイン',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kPrimary),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton({
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: fg, size: 22),
            const SizedBox(width: 10),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: fg)),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: GoogleFonts.inter(fontSize: 14, color: context.cText),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.inter(fontSize: 13, color: context.cTextSub),
        filled: true,
        fillColor: context.cCardLow,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: Colors.white.withValues(alpha: 0.06))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: kPrimary, width: 1.5)),
        suffixIcon: suffixIcon,
      ),
    );
  }

  void _showPasswordReset() {
    final ctrl = TextEditingController(text: _emailCtrl.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.cCardLow,
        title: Text('パスワードリセット',
            style: GoogleFonts.inter(
                fontWeight: FontWeight.w700, color: context.cText)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.inter(color: context.cText),
          decoration: InputDecoration(
            labelText: 'メールアドレス',
            labelStyle:
                GoogleFonts.inter(color: context.cTextSub),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('キャンセル',
                style: GoogleFonts.inter(color: context.cTextSub)),
          ),
          TextButton(
            onPressed: () async {
              final email = ctrl.text.trim();
              if (email.isEmpty) return;
              await AuthService.instance.sendPasswordReset(email);
              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('リセットメールを送信しました',
                        style: GoogleFonts.inter(color: Colors.white)),
                    backgroundColor: context.cCardHigh,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('送信',
                style: GoogleFonts.inter(
                    color: kPrimary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
