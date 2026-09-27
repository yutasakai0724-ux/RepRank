import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'firebase_init.dart';

/// Firebase Auth の全プロバイダ対応ラッパー。
///
/// 対応: 匿名 / メール / 電話番号 / Google / Apple
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  FirebaseAuth? get _auth => FirebaseInit.isReady ? FirebaseAuth.instance : null;

  /// 現在ログインしているユーザー
  User? get currentUser => _auth?.currentUser;

  /// 現在のユーザーが匿名かどうか
  bool get isAnonymous => currentUser?.isAnonymous ?? true;

  /// ログイン済みかつ非匿名かどうか
  bool get isSignedIn => currentUser != null && !isAnonymous;

  /// ログイン状態の変化ストリーム
  Stream<User?> get authStateChanges =>
      _auth?.authStateChanges() ?? const Stream.empty();

  // ── 匿名 ──────────────────────────────────────────────────────

  Future<User?> signInAnonymously() async {
    if (!FirebaseInit.isReady) return null;
    try {
      if (currentUser != null) return currentUser;
      final cred = await _auth!.signInAnonymously();
      debugPrint('[Auth] anonymous: ${cred.user?.uid}');
      return cred.user;
    } catch (e) {
      debugPrint('[Auth] signInAnonymously failed: $e');
      return null;
    }
  }

  // ── メール/パスワード ──────────────────────────────────────────

  Future<User?> signInWithEmail(String email, String password) async {
    if (!FirebaseInit.isReady) return null;
    try {
      final cred = await _auth!.signInWithEmailAndPassword(
          email: email, password: password);
      debugPrint('[Auth] email sign-in: ${cred.user?.uid}');
      return cred.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] email sign-in failed: ${e.code}');
      rethrow;
    }
  }

  Future<User?> createWithEmail(String email, String password) async {
    if (!FirebaseInit.isReady) return null;
    try {
      // 匿名ユーザーがいれば昇格（データを引き継ぐ）
      if (currentUser?.isAnonymous == true) {
        final credential =
            EmailAuthProvider.credential(email: email, password: password);
        final cred =
            await currentUser!.linkWithCredential(credential);
        debugPrint('[Auth] anonymous linked to email: ${cred.user?.uid}');
        return cred.user;
      }
      final cred = await _auth!.createUserWithEmailAndPassword(
          email: email, password: password);
      debugPrint('[Auth] email register: ${cred.user?.uid}');
      return cred.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] email register failed: ${e.code}');
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    if (!FirebaseInit.isReady) return;
    await _auth!.sendPasswordResetEmail(email: email);
  }

  // ── Google ────────────────────────────────────────────────────

  Future<User?> signInWithGoogle() async {
    if (!FirebaseInit.isReady) return null;
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null; // キャンセル
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      // 匿名ユーザーがいれば昇格を試みる
      if (currentUser?.isAnonymous == true) {
        try {
          final cred = await currentUser!.linkWithCredential(credential);
          debugPrint('[Auth] anonymous linked to Google: ${cred.user?.uid}');
          return cred.user;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            // すでに別アカウントに紐付け済み → そのアカウントでサインイン
            final cred = await _auth!.signInWithCredential(credential);
            debugPrint('[Auth] Google sign-in (existing): ${cred.user?.uid}');
            return cred.user;
          }
          rethrow;
        }
      }
      final cred = await _auth!.signInWithCredential(credential);
      debugPrint('[Auth] Google sign-in: ${cred.user?.uid}');
      return cred.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] Google sign-in failed: ${e.code}');
      rethrow;
    } catch (e) {
      debugPrint('[Auth] Google sign-in error: $e');
      rethrow;
    }
  }

  // ── Apple ─────────────────────────────────────────────────────

  Future<User?> signInWithApple() async {
    if (!FirebaseInit.isReady) return null;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        // iOS/macOS: ネイティブフロー
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );
        final oauthCredential = OAuthProvider('apple.com').credential(
          idToken: appleCredential.identityToken,
          accessToken: appleCredential.authorizationCode,
        );
        return await _signInWithCredential(oauthCredential, 'Apple');
      } else {
        // Android: Webリダイレクトフロー
        final provider = OAuthProvider('apple.com')
          ..addScope('email')
          ..addScope('name');
        UserCredential cred;
        if (currentUser?.isAnonymous == true) {
          try {
            cred = await currentUser!.linkWithProvider(provider);
          } on FirebaseAuthException catch (e) {
            if (e.code == 'credential-already-in-use') {
              cred = await _auth!.signInWithProvider(provider);
            } else {
              rethrow;
            }
          }
        } else {
          cred = await _auth!.signInWithProvider(provider);
        }
        debugPrint('[Auth] Apple sign-in (Android): ${cred.user?.uid}');
        return cred.user;
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[Auth] Apple sign-in failed: ${e.code}');
      rethrow;
    } catch (e) {
      debugPrint('[Auth] Apple sign-in error: $e');
      rethrow;
    }
  }

  Future<User?> _signInWithCredential(OAuthCredential credential, String provider) async {
    if (currentUser?.isAnonymous == true) {
      try {
        final cred = await currentUser!.linkWithCredential(credential);
        debugPrint('[Auth] anonymous linked to $provider: ${cred.user?.uid}');
        return cred.user;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          final cred = await _auth!.signInWithCredential(credential);
          debugPrint('[Auth] $provider sign-in (existing): ${cred.user?.uid}');
          return cred.user;
        }
        rethrow;
      }
    }
    final cred = await _auth!.signInWithCredential(credential);
    debugPrint('[Auth] $provider sign-in: ${cred.user?.uid}');
    return cred.user;
  }

  // ── アカウント削除 ─────────────────────────────────────────────

  Future<void> deleteAccount() async {
    if (!FirebaseInit.isReady) return;
    final user = currentUser;
    if (user == null) return;
    // クラウド上のユーザーデータ（記録・削除の印・設定）を先に削除する。
    // 認証が必要なため、アカウント削除より前に行う。
    await _deleteUserData(user.uid);
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await user.delete();
    debugPrint('[Auth] account deleted');
  }

  Future<void> _deleteUserData(String uid) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(uid);
    for (final name in ['sessions', 'deleted_sessions', 'settings']) {
      final snap = await userDoc.collection(name).get();
      // バッチは500件まで
      for (var i = 0; i < snap.docs.length; i += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final d in snap.docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
    await userDoc.delete();
    debugPrint('[Auth] cloud user data deleted');
  }

  // ── サインアウト ───────────────────────────────────────────────

  Future<void> signOut() async {
    if (!FirebaseInit.isReady) return;
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    try {
      await _auth!.signOut();
      debugPrint('[Auth] signed out');
    } catch (e) {
      debugPrint('[Auth] signOut failed: $e');
    }
  }

  // ── エラーメッセージ変換 ───────────────────────────────────────

  static String errorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'メールアドレスが登録されていません';
      case 'wrong-password':
        return 'パスワードが正しくありません';
      case 'invalid-credential':
        return 'メールアドレスまたはパスワードが正しくありません';
      case 'email-already-in-use':
        return 'このメールアドレスはすでに使用されています';
      case 'weak-password':
        return 'パスワードは6文字以上にしてください';
      case 'invalid-email':
        return 'メールアドレスの形式が正しくありません';
      case 'too-many-requests':
        return 'しばらく時間をおいてから再度お試しください';
      case 'credential-already-in-use':
        return 'このアカウントはすでに別のユーザーに紐づけられています';
      default:
        return 'エラーが発生しました（${e.code}）';
    }
  }
}
