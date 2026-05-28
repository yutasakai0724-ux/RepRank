# Rep Rank - App Store リリース手順

最終更新: 2026-05-28
バンドル ID: `com.yutasakai.reprank`

## 進捗チェックリスト

- [x] Apple Developer Program 登録
- [x] アプリアイコン設置（19サイズ）
- [x] スクリーンショット撮影
- [x] `PrivacyInfo.xcprivacy` 配置（Firebase 利用を反映）
- [x] `ITSAppUsesNonExemptEncryption=false` 設定
- [x] リリースビルド検証
- [x] プライバシーポリシー本文作成（Firebase 利用を明記済み）
- [x] Firebase コード組み込み（pubspec + 各サービス）
- [x] **Firebase Console でプロジェクト作成 & iOS アプリ登録**
- [x] **`flutterfire configure` 実行**
- [x] **`GoogleService-Info.plist` を Xcode プロジェクトに追加**
- [ ] **Firestore セキュリティルール設定**
- [ ] GitHub Pages 公開設定の確認
- [ ] プライバシーポリシーを Git commit & push
- [ ] App Store Connect でアプリ登録
- [ ] アーカイブ作成 & アップロード
- [ ] App Privacy 申告
- [ ] 審査提出

---

## 1. プライバシーポリシーの公開（最優先）

ポリシー本文は `docs/privacy-policy.html` に作成済み。日本語＋英語の両対応。  
**公開して URL でアクセスできるようにする**作業が必要。

### 1.1 GitHub Pages を有効化

リポジトリ: <https://github.com/yutasakai0724-ux/RepRank>

```bash
cd /Users/bossen/Desktop/kintorekioku
git add docs/privacy-policy.html RELEASE.md
git commit -m "docs: publish privacy policy"
git push origin main
```

GitHub Web UI で：
1. リポジトリの **Settings** タブ
2. 左メニュー **Pages**
3. 「Source」を **Deploy from a branch** に設定
4. Branch: **main** / Folder: **/docs**
5. **Save** をクリック
6. 数分待つと公開される

### 1.2 公開 URL

```
https://yutasakai0724-ux.github.io/RepRank/privacy-policy.html
```

⚠️ リポジトリが **Private** の場合、GitHub Pages は無料プランでは使用不可。  
リポジトリを Public に変更するか、別ホスティング（Vercel/Cloudflare Pages 等）を検討。

### 1.3 公開確認

ブラウザで上記 URL を開き、以下を確認：
- [ ] ページが正常表示される
- [ ] 文字化けなし
- [ ] メールリンクが機能する
- [ ] 「最終更新」日が現在の日付

### 1.4 アプリ内リンク（推奨・任意）

プロフィール画面にリンク追加：

```dart
// pubspec.yaml に追加
dependencies:
  url_launcher: ^6.3.0

// profile_screen.dart の任意の位置
ListTile(
  leading: Icon(Icons.privacy_tip_outlined),
  title: Text('プライバシーポリシー'),
  onTap: () => launchUrl(
    Uri.parse('https://yutasakai0724-ux.github.io/RepRank/privacy-policy.html'),
    mode: LaunchMode.externalApplication,
  ),
);
```

---

## 2. Firebase セットアップ

Crashlytics（クラッシュレポート）+ Firestore（匿名統計） + Auth（匿名認証）を使用。  
コード組み込みは完了済み。Firebase 側の設定が必要。

### 2.1 Firebase Console でプロジェクト作成

<https://console.firebase.google.com/>

1. 「プロジェクトを追加」→ 名前: `Rep Rank`（任意）
2. Google Analytics: **無効**（アプリは使用しない）
3. 作成完了後、ダッシュボードに移動

### 2.2 iOS アプリを登録

1. プロジェクト概要 → 「iOS」アイコンをクリック
2. Apple バンドル ID: `com.yutasakai.reprank`
3. App ニックネーム: `Rep Rank`
4. App Store ID: 後で App Store Connect で取得した後に入力（今は空欄でOK）
5. **`GoogleService-Info.plist` をダウンロード**

### 2.3 flutterfire CLI セットアップ

```bash
# 初回のみ: CLI インストール
dart pub global activate flutterfire_cli

# Firebase CLI もログインしておく
npm install -g firebase-tools  # 未インストールの場合
firebase login

# プロジェクト構成を Flutter プロジェクトに紐付け
cd /Users/bossen/Desktop/kintorekioku
flutterfire configure
```

対話で：
- Firebase プロジェクトを選択
- 対象プラットフォーム: iOS のみ
- 完了後、`lib/firebase_options.dart` が自動生成される（コードは未使用だが置いておく）

### 2.4 GoogleService-Info.plist を Xcode に追加

```bash
# ダウンロードした plist を配置
mv ~/Downloads/GoogleService-Info.plist ios/Runner/
```

Xcode で：
1. `open ios/Runner.xcworkspace`
2. 左ペインの `Runner` フォルダを右クリック → 「Add Files to "Runner"...」
3. `ios/Runner/GoogleService-Info.plist` を選択
4. 「Copy items if needed」**チェックを外す**（既に正しい場所にある）
5. Target: `Runner` にチェック → 「Add」

### 2.5 Firestore セキュリティルール

Firebase Console → Firestore Database → ルール:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // 匿名認証ユーザーは exercise_ratios に書き込みのみ可能
    match /exercise_ratios/{doc} {
      allow create: if request.auth != null
                    && request.resource.data.keys().hasOnly(['exerciseName', 'ratio', 'recordedAt'])
                    && request.resource.data.ratio is number
                    && request.resource.data.ratio > 0
                    && request.resource.data.ratio < 10;
      allow read, update, delete: if false;  // 読み取り・更新・削除は禁止
    }
  }
}
```

集計取得用に読み取りを許可する場合は別途検討（推奨: Cloud Functions で集計後の結果のみ公開）。

### 2.6 Authentication で匿名認証を有効化

Firebase Console → Authentication → Sign-in method → **「匿名」を有効化**

### 2.7 動作確認

```bash
flutter clean
flutter run
```

- アプリ起動時にコンソールに `[Firebase] initialized` が表示されればOK
- プロフィール画面で「匿名統計データを共有」をONにして保存
- 種目記録 → Firebase Console の Firestore で `exercise_ratios` コレクションに新規ドキュメントが追加されているか確認

> ⚠️ デバッグビルドでは Crashlytics 送信は無効化されています（`firebase_init.dart` の `kDebugMode` 判定）。
> 本番動作確認は **`flutter run --release`** で行うこと。

---

## 3. App Store Connect でアプリ登録

URL: <https://appstoreconnect.apple.com/>

### 3.1 新規アプリ作成

「マイアプリ」→ 「＋」 → 「新規 App」

| 項目 | 値 |
|---|---|
| プラットフォーム | iOS |
| 名前 | Rep Rank |
| プライマリ言語 | 日本語 |
| バンドル ID | com.yutasakai.reprank（Xcode と一致必須） |
| SKU | reprank-001（任意の一意な英数字） |
| ユーザーアクセス | フルアクセス |

### 3.2 「App 情報」タブ

- **カテゴリ**: ヘルスケア／フィットネス
- **コンテンツ著作権**: 自分の名前
- **年齢制限**: 4+（運動アプリなので通常）
- **プライバシーポリシー URL**: `https://yutasakai0724-ux.github.io/RepRank/privacy-policy.html`

### 3.3 「価格および配信状況」タブ

- **価格**: 無料
- **配信可能地域**: 日本のみ（または全世界）

### 3.4 「App プライバシー」タブ（重要）

`PrivacyInfo.xcprivacy` の内容と整合させること。Firebase 利用のため以下を申告：

| 質問 | 回答 |
|---|---|
| データを収集していますか？ | **はい** |
| データを使用してユーザーを追跡しますか？ | **いいえ** |

**データタイプの選択**:

| データタイプ | 用途 | リンク | 追跡 |
|---|---|---|---|
| 診断（クラッシュデータ） | アプリの機能 | リンクされていない | しない |
| 診断（その他の診断データ） | アプリの機能 | リンクされていない | しない |
| その他のユーザーコンテンツ（体重比） | 分析 | リンクされていない | しない |

> ⚠️ 「ユーザーを追跡」が **はい** の場合は ATT 同意ダイアログが必要。本アプリは追跡しないため **いいえ**。  
> ⚠️ 体重比は「ユーザーID とリンクされていない」を選択（uid はデータと紐付けない設計のため）。

### 3.5 バージョン情報（最初の "1.0" ページ）

- **プロモーション用テキスト**（任意・170字）: 機能追加なしでもアップデート可能
- **説明**（4000字）: 機能の説明文
- **キーワード**（100字）: `筋トレ,1RM,ベンチプレス,スクワット,デッドリフト,ワークアウト記録,カレンダー,体重比,強度分析`
- **サポート URL**: GitHub の Issues か連絡先ページ
- **マーケティング URL**: 任意
- **スクリーンショット**:
  - 6.9 インチ（iPhone 16/17 Pro Max）— 必須
  - 6.5 インチ（任意・推奨）
- **App プレビュー**（動画）: 任意

#### 説明文テンプレート

```
Rep Rank（レップランク）は、筋トレの記録に特化したシンプルなアプリです。

■ 主な機能
・重量と回数を入力するだけで 1RM（最大挙上重量）を自動推定
・体重比に基づく強度ティア（初心者〜エリート）の分析
・部位別の種目選択（胸・背中・脚・肩・腕・腹筋）
・カレンダー表示で過去の記録を確認・編集
・休憩タイマー（プリセット + カスタム秒数）
・ワークアウト全体のストップウォッチ

■ プライバシー重視
ワークアウト記録はあなたのデバイス内のみに保存されます。
アカウント登録不要、広告なし。
※ アプリの品質向上のため匿名のクラッシュレポートを送信します（個人情報は含みません）。
※ ヒストグラム機能を有効化した場合のみ、種目名と体重比を匿名で送信します（任意設定）。

■ こんな人におすすめ
・自分の成長を客観的に把握したい人
・ジムや自宅でのトレーニングを継続したい人
・複雑な機能より使いやすさを重視する人
```

---

## 4. アーカイブ作成 & アップロード

### 4.1 事前確認

```bash
# バージョン番号の確認
grep "^version:" pubspec.yaml
# version: 1.0.0+1
```

`pubspec.yaml` の `version: <マーケティング>+<ビルド>` を必要に応じて更新:
- マーケティングバージョン（1.0.0）: 表示用
- ビルド番号（1）: アップロードごとに **必ず増やす**

### 4.2 Flutter リリースビルド

```bash
flutter clean
flutter pub get
flutter build ios --release
```

### 4.3 Xcode でアーカイブ

```bash
open ios/Runner.xcworkspace
```

1. Xcode 上部のデバイスターゲットを「**Any iOS Device (arm64)**」に切替
2. メニュー: **Product → Archive**
3. ビルド完了後、Organizer が自動で開く
4. **Distribute App** → **App Store Connect** → **Upload** を選択
5. 自動署名 or 手動署名（Personal Team は不可、有料 Apple Developer Program のみ）
6. 自動の Bitcode/symbol オプションはデフォルトのままで OK
7. アップロード完了まで約 5〜15 分

### 4.4 ビルド処理待ち（App Store Connect 側）

アップロード後、App Store Connect が再処理する:
- 通常: 15分〜2時間
- ステータス: 「処理中」→「アップロード済」に変わるまで待つ
- 「コンプライアンス情報がありません」と出たら → 暗号化使用なしを選択（`ITSAppUsesNonExemptEncryption=false` 設定済みなので自動でクリアされるはず）

---

## 5. TestFlight でテスト（強く推奨）

審査前に実機で必ず動作確認。

1. App Store Connect → 「TestFlight」タブ
2. 「内部テスト」または「外部テスト」を選択
3. テスター（自分の Apple ID）を追加
4. TestFlight アプリを iPhone にインストール
5. 招待リンクから Rep Rank をインストール
6. 一通りの機能を確認:
   - [ ] 種目追加 → 記録 → 戻る → DB 保存されている
   - [ ] カレンダーから過去日を開く → 編集 → 保存される
   - [ ] 同日に同種目を追加 → 編集モードで開く
   - [ ] 休憩タイマー（START/PAUSE/STOP）
   - [ ] ストップウォッチ（START/STOP/RESET）
   - [ ] ティア分析画面の表示
   - [ ] 1RM 推移グラフ
   - [ ] アプリを終了 → 再起動 → データ残存
   - [ ] アクセシビリティ: 文字サイズ最大でレイアウト崩れなし

---

## 6. 審査提出

### 6.1 提出前最終チェック

- [ ] バージョン番号がストア未公開のものか
- [ ] スクリーンショットがアプリの最新画面を反映している
- [ ] プライバシーポリシー URL がアクセス可能か
- [ ] 説明文に誤字脱字なし
- [ ] App プライバシーセクションの回答が `PrivacyInfo.xcprivacy` と一致

### 6.2 「審査へ提出」

App Store Connect → バージョン詳細 → 「審査へ提出」

- **コンプライアンス**: 暗号化を使用していない → 「いいえ」
- **広告 ID（IDFA）の使用**: 使用していない
- **コンテンツの権利**: 自分が権利保有

### 6.3 レビュー時間

- 通常: 24〜48時間（最近は短くなる傾向）
- リジェクトされた場合: メタデータ・コード両方の修正可能

---

## 7. よくあるリジェクト理由と対策

| 理由 | 対策 |
|---|---|
| Guideline 5.1.1（プライバシー） | ポリシー URL が無効 / 内容不一致 → 公開状態と App プライバシー欄を再確認 |
| Guideline 4.0（デザイン） | 「未完成に見える」「機能が薄い」と判断される → 説明文で機能を網羅、TestFlight でクラッシュチェック |
| Guideline 2.1（アプリの完全性） | 機能が動かない / クラッシュする → リリースビルドで実機テスト必須 |
| Metadata | スクリーンショットと実際のアプリが違う → 最新版で撮り直す |

---

## 8. リリース後の運用

### 8.1 バージョンアップ手順

1. `pubspec.yaml` の version を bump（例: `1.0.0+1` → `1.0.1+2`）
2. App Store Connect で「新規バージョン」作成
3. リリースノート（「このバージョンの新機能」）を記入
4. アーカイブ → アップロード → 提出

### 8.2 アナリティクス確認

App Store Connect → 「分析」タブ:
- 表示回数、ダウンロード数、クラッシュ数を確認

### 8.3 ユーザーレビュー対応

App Store Connect → 「評価とレビュー」:
- 1-2 営業日以内にデベロッパー返信
- 否定的なレビューには丁寧に対応

---

## 9. 将来の機能追加時の注意点

### Firebase 等を導入する場合（既出）

- プライバシーポリシーを更新
- App Store Connect の App プライバシー欄を更新
- `PrivacyInfo.xcprivacy` にデータ収集タイプを追記
- アプリ内通知でユーザーに変更を知らせる

### 在庫の課金（IAP）を追加する場合

- App Store Connect で「App 内課金」を設定
- `in_app_purchase` パッケージを導入
- 税務情報・銀行情報の登録が必要

---

## 参考リンク

- [App Store Connect](https://appstoreconnect.apple.com/)
- [Apple Developer Documentation](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Flutter iOS デプロイ手順](https://docs.flutter.dev/deployment/ios)
- [PrivacyInfo.xcprivacy リファレンス](https://developer.apple.com/documentation/bundleresources/privacy_manifest_files)
