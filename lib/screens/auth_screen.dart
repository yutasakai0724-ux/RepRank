import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../utils/app_fonts.dart';
import '../theme.dart';
import '../services/auth_service.dart';

/// ログイン画面（Apple / Google のみ。初回はそのままアカウントが作成される）。
/// サインイン成功時に Navigator がポップする（呼び出し元で authStateChanges を監視）。
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isLoading = false;
  String? _errorMsg;

  Future<void> _signInGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
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
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
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
          'ログイン',
          style: AppFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: kPrimary,
          ),
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
                      color: kPrimary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    size: 36,
                    color: kPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Rep Rank',
                  style: AppFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: kPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'ログインするとデータをクラウドに\nバックアップ・同期できます',
                  textAlign: TextAlign.center,
                  style: AppFonts.inter(
                    fontSize: 13,
                    color: context.cTextSub,
                    height: 1.5,
                  ),
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
              const SizedBox(height: 12),
              Center(
                child: Text(
                  '初めての方も、そのままアカウントが作成されます',
                  style: AppFonts.inter(fontSize: 12, color: context.cTextSub),
                ),
              ),

              if (_isLoading) ...[
                const SizedBox(height: 20),
                const Center(child: CircularProgressIndicator(color: kPrimary)),
              ],

              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _errorMsg!,
                    style: AppFonts.inter(
                      fontSize: 13,
                      color: Colors.red.shade300,
                    ),
                  ),
                ),
              ],
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
            Text(
              label,
              style: AppFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
