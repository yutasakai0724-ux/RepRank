import 'package:flutter/material.dart';
import '../utils/app_fonts.dart';
import '../theme.dart';
import '../services/user_preferences.dart';

class PrivacyConsentScreen extends StatelessWidget {
  const PrivacyConsentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      appBar: AppBar(
        backgroundColor: context.cBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'プライバシーポリシー',
          style: AppFonts.inter(
              fontSize: 17, fontWeight: FontWeight.w700, color: kPrimary),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _badge('最終更新: 2026年6月13日'),
                  const SizedBox(height: 16),
                  _body(context, 
                    'Rep Rank（以下「本アプリ」）をご利用いただきありがとうございます。本ポリシーでは、本アプリがどのようにデータを取り扱うかを説明します。',
                  ),

                  _h2(context, '1. 保存される情報'),
                  _body(context, '本アプリは以下の情報を保存します。'),
                  _ul(context, [
                    'ワークアウトの記録（種目名・重量・回数・日時）',
                    'ルーチン（マイセット）の設定',
                    'プロフィール情報（ユーザー名・体重・性別）',
                  ]),
                  _body(context, 
                    'アカウント未登録の場合、上記のデータはすべてデバイス上のローカルストレージにのみ保存され、外部には送信されません。\n\n'
                    'アカウント登録済みの場合、上記のデータはデバイス上のローカルストレージに加え、クラウド（Firebase Firestore）にも保存されます（詳細は 2.4 を参照）。',
                  ),

                  _h2(context, '2. 外部に送信される情報'),
                  _body(context, '本アプリは品質向上のため Google LLC が提供する Firebase サービスを利用しており、以下の情報を送信する場合があります。'),

                  _h3(context, '2.1 クラッシュ・診断データ（自動・常時）'),
                  _ul(context, [
                    '送信先: Firebase Crashlytics',
                    '内容: アプリのクラッシュ時のスタックトレース、デバイス機種、OS バージョン、アプリバージョン',
                    '目的: 不具合の特定および修正',
                    '個人を特定する情報は含まれません',
                  ]),

                  _h3(context, '2.2 使用状況データ（自動・常時）'),
                  _ul(context, [
                    '送信先: Firebase Analytics',
                    '内容: 画面遷移、機能の利用頻度など匿名の使用状況データ',
                    '目的: アプリの改善・ユーザー体験の向上',
                    '個人を特定する情報は含まれず、広告目的には使用しません',
                  ]),

                  _h3(context, '2.3 匿名統計データ（オプトイン・任意）'),
                  _ul(context, [
                    '送信先: Firebase Firestore',
                    '内容: 種目名と体重比（1RM ÷ 体重）の値、送信日時のみ',
                    '目的: 強度分布ヒストグラム機能の精度向上',
                    'プロフィール画面のトグルを ON にした場合のみ送信されます（デフォルト OFF）',
                    '個人を特定する情報（氏名・メールアドレス・正確な体重・トレーニング全履歴等）は送信されません',
                  ]),

                  _h3(context, '2.4 アカウントおよびクラウド同期データ（オプトイン・任意）'),
                  _ul(context, [
                    '送信先: Firebase Authentication / Firebase Firestore',
                    '対象: アカウント登録（メールアドレス・Google・Apple）を行った場合のみ',
                    '内容: ワークアウトの記録（種目名・重量・回数・日時）をクラウドにバックアップ',
                    '目的: 機種変更時のデータ引き継ぎ、複数デバイス間での同期',
                    'データはご自身のアカウントにのみ紐づけられ、他のユーザーはアクセスできません',
                  ]),

                  _h3(context, '2.5 広告（自動・常時）'),
                  _ul(context, [
                    '送信先: Google AdMob（Google LLC）',
                    '内容: 広告の表示に必要な匿名の端末情報',
                    '目的: アプリの運営・開発の継続',
                    '行動ターゲティング広告は使用しません。IDFA（広告識別子）の取得は行いません',
                  ]),

                  _h2(context, '3. 情報の利用目的'),
                  _ul(context, [
                    'ワークアウト履歴の表示・分析',
                    '1RM 推定・強度レベルの算出',
                    'アプリの不具合修正および品質向上',
                    '強度分布データの集計（匿名統計データを共有した場合のみ）',
                    'クラウドバックアップおよびデバイス間同期（アカウント登録した場合のみ）',
                  ]),

                  _h2(context, '4. 第三者への提供'),
                  _body(context, 
                    '本アプリはあなたの個人情報を販売しません。上記 Firebase サービスおよび Google AdMob 以外の第三者にデータを提供することはありません。',
                  ),

                  _h2(context, '5. 広告について'),
                  _body(context, 
                    '本アプリは Google AdMob によるバナー広告およびリワード広告を表示します。広告はユーザーの行動履歴に基づくターゲティングを行わず、IDFA（広告識別子）も取得しません。',
                  ),

                  _h2(context, '6. データの削除'),
                  _body(context, 
                    'アプリをデバイスから削除することで、ローカルに保存されたすべてのデータが完全に削除されます。\n\n'
                    'クラウド同期を利用している場合は、アプリ内のプロフィール画面からアカウントを削除することで、クラウド上のデータも削除されます。\n\n'
                    '匿名で送信済みの統計データおよび Analytics データは個人を特定できないため、個別の削除リクエストには対応できません。',
                  ),

                  _h2(context, '7. 子どものプライバシー'),
                  _body(context, 
                    '本アプリは 13 歳未満の子どもを対象としておらず、13 歳未満の方から意図的に情報を収集しません。',
                  ),

                  _h2(context, '8. ポリシーの変更'),
                  _body(context, 
                    '本ポリシーは予告なく変更される場合があります。重要な変更がある場合はアプリのアップデート時にお知らせします。',
                  ),

                  _h2(context, '9. お問い合わせ'),
                  _body(context, '本ポリシーに関するご質問は下記までご連絡ください。\nEmail: yutatsukinowa0724@gmail.com'),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // 同意ボタンエリア
          Container(
            decoration: BoxDecoration(
              color: context.cBg,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              children: [
                Text(
                  '上記のプライバシーポリシーに同意しますか？\n後からプロフィール画面で変更できます。',
                  textAlign: TextAlign.center,
                  style: AppFonts.inter(
                      fontSize: 12, color: context.cTextSub, height: 1.5),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await UserPreferences.instance.setPrivacyConsented();
                          await UserPreferences.instance.setShareStats(false);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: context.cBorderSub),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('同意しない',
                            style: AppFonts.inter(
                                fontSize: 15, color: context.cTextSub)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await UserPreferences.instance.setPrivacyConsented();
                          await UserPreferences.instance.setShareStats(true);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('同意する',
                            style: AppFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: kPrimary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: kPrimary.withValues(alpha: 0.3)),
        ),
        child: Text(text,
            style: AppFonts.inter(
                fontSize: 11, fontWeight: FontWeight.w700, color: kPrimary)),
      );

  Widget _h2(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text,
                style: AppFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.cText)),
            const SizedBox(height: 6),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          ],
        ),
      );

  Widget _h3(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(text,
            style: AppFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.cText)),
      );

  Widget _body(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: AppFonts.inter(
                fontSize: 13, color: context.cTextSub, height: 1.6)),
      );

  Widget _ul(BuildContext context, List<String> items) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5, right: 8),
                          child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: kPrimary, shape: BoxShape.circle)),
                        ),
                        Expanded(
                          child: Text(item,
                              style: AppFonts.inter(
                                  fontSize: 13,
                                  color: context.cTextSub,
                                  height: 1.6)),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      );
}
