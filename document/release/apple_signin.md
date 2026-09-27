# Apple Sign-In 設定手順（Rep Rank）

---

## 概要

Apple Sign-In を有効にするには以下の3箇所で設定が必要です。

| 場所 | 作業 |
|---|---|
| Apple Developer Portal | Sign In with Apple を有効化 |
| Firebase Console | Apple プロバイダを有効化 |
| Xcode | Capability を追加 |

---

## STEP 1: Apple Developer Portal

### 1-1. App ID に Sign In with Apple を追加

1. [https://developer.apple.com/account](https://developer.apple.com/account) にアクセス
2. **Certificates, Identifiers & Profiles** → **Identifiers** を開く
3. `com.yutasakai.reprank` をクリック
4. Capabilities の一覧から **Sign In with Apple** にチェックを入れる
5. 右上の **Save** をクリック

### 1-2. Key を作成（Firebase 連携に必要）

1. 左メニューの **Keys** → **+** ボタン
2. Key Name: `RepRank Sign In with Apple`（任意）
3. **Sign In with Apple** にチェック → **    Configure** をクリック
4. Primary App ID: `com.yutasakai.reprank` を選択 → **Save**
5. **Continue** → **Register**
6. **Download** ボタンで `.p8` ファイルをダウンロード（⚠️ 1回しかダウンロードできない）
7. **Key ID** をメモしておく（後で Firebase に入力）

---

## STEP 2: Firebase Console

1. [https://console.firebase.google.com/](https://console.firebase.google.com/) を開く
2. **rep rank** プロジェクトを選択
3. 左メニュー **Authentication** → **Sign-in method** タブ
4. **Apple** をクリック
5. **有効にする** トグルをオン
6. 以下を入力：
   - **Services ID**: 空欄でOK（iOSネイティブのみの場合）
   - **Apple Team ID**: `SC9XCQV5U4`
   - **Key ID**: STEP 1-2 でメモした Key ID
   - **Private Key (.p8)**: STEP 1-2 でダウンロードした `.p8` ファイルの中身をテキストエディタで開いてコピー＆ペースト
7. **保存** をクリック

---

## STEP 3: Xcode

1. ターミナルで以下を実行して Xcode を開く：
   ```bash
   open /Users/bossen/Desktop/kintorekioku/ios/Runner.xcworkspace
   ```

2. 左ペインで **Runner**（プロジェクトアイコン）をクリック
3. **TARGETS** → **Runner** を選択
4. **Signing & Capabilities** タブを開く
5. 左上の **+ Capability** ボタンをクリック
6. 検索欄に `Sign In with Apple` と入力
7. ダブルクリックで追加
8. Capability の一覧に **Sign In with Apple** が追加されたことを確認

---

## STEP 4: 動作確認

ターミナルで以下を実行してエラーなくビルドできるか確認：

```bash
cd /Users/bossen/Desktop/kintorekioku
flutter build ios --debug
```

実機またはシミュレーターで Auth 画面を開き、**Apple でサインイン** ボタンが動作することを確認。

---

## トラブルシューティング

| エラー | 原因 | 対処 |
|---|---|---|
| `invalid_client` | Firebase の Team ID / Key ID が間違い | STEP 2 を再確認 |
| `The operation couldn't be completed` | Xcode の Capability 未追加 | STEP 3 を再確認 |
| ボタンが表示されない | iOS 13 未満 | iOS 13 以上でのみ動作（対象外） |
| `credential-already-in-use` | 別アカウントに紐づき済み | AuthService のエラー処理で対応済み |

---

## 参考リンク

- Apple Developer: https://developer.apple.com/sign-in-with-apple/
- Firebase Apple Sign-In: https://firebase.google.com/docs/auth/ios/apple
- flutter sign_in_with_apple: https://pub.dev/packages/sign_in_with_apple

---

*作成日: 2026-05-28 / Rep Rank v1.0*
