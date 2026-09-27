# app-ads.txt 設定手順書

> 対象アプリ: Rep Rank  
> 目的: AdMob 広告収益の保護・広告配信の維持

---

## はじめに

**app-ads.txt** とは、アプリの広告枠を販売する権限を持つ広告システムを宣言するファイルです。  
Google は定期的にこのファイルをチェックしており、**未設定のアプリは広告インプレッションが段階的に減少する**可能性があります。

---

## 全体の流れ

```
①デベロッパーサイトを用意
       ↓
②Google Play / App Store の掲載情報にサイトURLを登録
       ↓
③app-ads.txt ファイルを作成
       ↓
④サイトのルートディレクトリに配置
       ↓
⑤AdMob がクロール（最大 24 時間）
       ↓
⑥AdMob コンソールで「確認済み」を確認
```

---

## 事前準備：AdMob パブリッシャー ID を確認する

1. [AdMob コンソール](https://admob.google.com/) にログイン
2. 左メニュー「**アカウント**」→「**アカウント情報**」を開く
3. 「**パブリッシャー ID**」をコピーして控える

```
例: pub-1234567890123456
```

---

## STEP 1 — デベロッパーウェブサイトを用意する

app-ads.txt を置くためのウェブサイトが必要です。  
個人開発者には **GitHub Pages** が無料で最も手軽です。

### GitHub Pages を使う場合（推奨）

#### 1-1. GitHub にリポジトリを作成する

1. [github.com](https://github.com) にログイン
2. 右上「**＋**」→「**New repository**」をクリック
3. 以下の設定で作成する

| 項目 | 設定値 |
|------|--------|
| Repository name | `app-ads` （任意） |
| Visibility | **Public**（必須） |
| Add a README file | チェックを入れる |

4. 「**Create repository**」をクリック

#### 1-2. GitHub Pages を有効にする

1. 作成したリポジトリを開く
2. 上部メニュー「**Settings**」をクリック
3. 左メニュー「**Pages**」をクリック
4. 「Source」のドロップダウンを「**main**」ブランチに変更
5. 「**Save**」をクリック

数分後、以下の URL でアクセスできるようになる：
```
https://[GitHubユーザー名].github.io/app-ads/
```

> ✅ この URL が「デベロッパーウェブサイト」になります

---

## STEP 2 — アプリストアの掲載情報にウェブサイト URL を登録する

### Google Play の場合

1. [Google Play Console](https://play.google.com/console) にログイン
2. 対象アプリを選択
3. 左メニュー「**ストアの設定**」→「**メインのストア掲載情報**」
4. 「**デベロッパーの連絡先情報**」セクションの「**ウェブサイト**」欄に入力

```
https://[GitHubユーザー名].github.io/app-ads/
```

5. 「**保存**」をクリック

### App Store の場合

1. [App Store Connect](https://appstoreconnect.apple.com) にログイン
2. 対象アプリ →「**App 情報**」
3. 「**マーケティング URL**」または「**サポート URL**」欄に同じ URL を入力
4. 「**保存**」をクリック

---

## STEP 3 — app-ads.txt ファイルを作成する

テキストエディタ（メモ帳など）で以下の内容のファイルを作成する。

### ファイル内容

```
google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0
```

### 各項目の意味

| 項目 | 値 | 説明 |
|------|-----|------|
| 広告システム | `google.com` | Google AdMob（固定） |
| パブリッシャーID | `pub-XXXXXXXXXXXXXXXX` | **自分のIDに置き換える** |
| 関係性 | `DIRECT` | 直接契約（固定） |
| 認証キー | `f08c47fec0942fa0` | Google の公式キー（固定） |

### ファイル名・形式の注意

| 項目 | 内容 |
|------|------|
| ファイル名 | `app-ads.txt`（ハイフンあり、小文字） |
| 文字コード | UTF-8 |
| 改行コード | LF または CRLF どちらでも可 |
| 拡張子 | `.txt` |

---

## STEP 4 — GitHub にファイルをアップロードする

1. 作成したリポジトリのページを開く
2. 「**Add file**」→「**Upload files**」をクリック
3. `app-ads.txt` ファイルをドラッグ＆ドロップ
4. 下部「**Commit changes**」をクリック

アップロード後、以下の URL でファイルにアクセスできることをブラウザで確認する：

```
https://[GitHubユーザー名].github.io/app-ads/app-ads.txt
```

ブラウザで以下のように表示されれば成功：
```
google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0
```

> ⚠️ GitHub Pages の反映には数分かかる場合があります

---

## STEP 5 — AdMob でクロールを依頼する（任意・推奨）

自動クロールを待つ（最大 24 時間）か、手動でクロールを依頼できます。

1. AdMob コンソール → 左メニュー「**アプリ**」
2. 対象アプリを選択
3. 「**app-ads.txt**」タブを開く
4. 「**アップデートを確認**」ボタンをクリック

---

## STEP 6 — 確認済みステータスを確認する

クロール完了後、AdMob コンソールで以下を確認する：

| ステータス | 意味 |
|-----------|------|
| ✅ 確認済み | 正常。設定完了 |
| ⚠️ 見つかりません | ファイルの URL が間違っているか、まだ反映中 |
| ❌ エラー | ファイルの形式が正しくない |

---

## トラブルシューティング

### ファイルが見つからない

- ブラウザで `https://[サイトURL]/app-ads.txt` に直接アクセスして確認
- GitHub Pages が有効になっているか再確認（Settings → Pages）
- リポジトリが **Public** になっているか確認

### サブドメインに関する注意

AdMob のクローラーはサブドメインの **第1レベルまで**遡ってチェックします。

```
掲載情報のURL: support.help.example.com
↓ クローラーがチェックするURL
help.example.com/app-ads.txt  ← ここを確認する
```

また、`www.` と `m.` のサブドメインは**除外**されます：

```
www.example.com  →  example.com/app-ads.txt を確認
m.example.com   →  example.com/app-ads.txt を確認
```

### 24 時間経っても確認済みにならない

1. AdMob コンソールの「アップデートを確認」ボタンを押す
2. ファイルの内容に余分なスペースや文字が入っていないか確認
3. HTTPS で正しくアクセスできるか確認

---

## 完成イメージ

```
リポジトリ構成（GitHub）:
app-ads/
├── README.md
└── app-ads.txt   ← このファイルを追加

アクセスURL:
https://[ユーザー名].github.io/app-ads/app-ads.txt
```

---

## 参考リンク

- [AdMob 公式ヘルプ - app-ads.txt](https://support.google.com/admob/answer/9363762?hl=ja)
- [IAB Tech Lab - app-ads.txt 仕様](https://iabtechlab.com/ads-txt/)
