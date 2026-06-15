import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'firebase_init.dart';
import 'user_preferences.dart';

/// ヒストグラム用の匿名データ収集サービス。
///
/// プロフィール画面のオプトイントグルが ON の場合のみ、
/// 「種目名 + 体重比 + タイムスタンプ」を匿名で Firestore に送信する。
///
/// **送信される情報**: exerciseName, ratio, recordedAt のみ
/// **送信されない情報**: 体重そのもの、ユーザー名、デバイス情報、回数/重量
class CloudDataService {
  CloudDataService._();
  static final CloudDataService instance = CloudDataService._();

  FirebaseFirestore? get _db =>
      FirebaseInit.isReady ? FirebaseFirestore.instance : null;

  /// ユーザーが匿名統計データの提供に同意しているか
  Future<bool> isShareEnabled() => UserPreferences.instance.getShareStats();

  /// 体重比データを匿名で送信。
  /// 未同意・Firebase 未設定・認証失敗時はサイレントに no-op。
  Future<void> recordRatio({
    required String exerciseName,
    required double ratio,
  }) async {
    if (!FirebaseInit.isReady) return;
    if (!await isShareEnabled()) return;

    // 認可のため匿名サインイン
    final user = await AuthService.instance.signInAnonymously();
    if (user == null) return;

    try {
      await _db!.collection('exercise_ratios').add({
        'exerciseName': exerciseName,
        'ratio': double.parse(ratio.toStringAsFixed(3)),
        'recordedAt': FieldValue.serverTimestamp(),
        // 注意: uid は送信しない（認証は書き込み認可のためだけ）
      });
    } catch (e) {
      debugPrint('[CloudData] write failed: $e');
    }
  }

  /// 指定種目のヒストグラム用集計を取得（将来の Cloud Functions 集計を想定したスタブ）
  ///
  /// 現状は生データを最大 N 件取得して Dart 側で集計する簡易実装。
  /// 本番ではセキュリティルールで読み取り制限することを推奨。
  Future<List<double>> fetchRatiosForExercise(
    String exerciseName, {
    int limit = 500,
  }) async {
    if (!FirebaseInit.isReady) return [];
    try {
      final snap = await _db!
          .collection('exercise_ratios')
          .where('exerciseName', isEqualTo: exerciseName)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => (d.data()['ratio'] as num).toDouble())
          .toList();
    } catch (e) {
      debugPrint('[CloudData] fetch failed: $e');
      return [];
    }
  }
}
