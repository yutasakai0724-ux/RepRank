# リリース準備 手順書

## 目次
- [作業2: Bundle ID を変更する](#作業2-bundle-id-を変更する)
- [作業4: プライバシーポリシーを公開する（GitHub Pages）](#作業4-プライバシーポリシーを公開するgithub-pages)

---

## 作業2: Bundle ID を変更する

Bundle ID はアプリの「戸籍番号」です。  
現在 `com.yourname.kintorekioku` になっているため、  
**あなた自身のドメイン** を使った ID に変更する必要があり���す。

### Bundle ID の決め方

形式は `com.あなたのドメイン.アプリ名` （逆順ドメイン記法）。  
独自ドメインがなくても、以下のようにすれば問題ありません。

```
例:
  com.tsukinowa.reprank        ← 名前をドメイン的に使う
  io.github.あなたのGitHubID.reprank
  jp.co.yourcompany.reprank
```

> ⚠️ 一度 App Store に公開すると変更不可。慎重に決めてください。

---

### 手順

#### ステップ 1: Xcode を開く

ターミナルで以下を実行します。

```bash
open /Users/bossen/Desktop/kintorekioku/ios/Runner.xcworkspace
```

> **`.xcodeproj` ではなく `.xcworkspace` を開いてください。**

---

#### ステップ 2: Bundle ID を変更する

1. Xcode 左のファイルツリーで **Runner**（青いフォルダアイコン）をクリック  
2. 中央エリアに `TARGETS` 一覧が表示される  
3. **Runner** ターゲットをクリック  
4. 上部タブの **Signing & Capabilities** をクリック  
5. **Bundle Identifier** の欄を見つける（現在: `com.yourname.kintorekioku`）  
6. クリックして書き換える（例: `com.tsukinowa.reprank`）

```
Before: com.yourname.kintorekioku
After:  com.tsukinowa.reprank   ← あなたの ID に変更
```

---

#### ステップ 3: Apple Developer アカウントをサインイン

> Apple Developer アカウント（$99/年）の登録が先に必要です。  
> 未登録の場合は https://developer.apple.com/jp/programs/ から登録してください。

1. Xcode メニュー → **Xcode > Settings**（または `⌘,`）  
2. **Accounts** タブをクリック  
3. 左下の **+** ボ��ン → **Apple ID** を選択  
4. Apple Developer アカウントの Apple ID とパスワードでサインイン  
5. サインインすると `Personal Team` または会社名が表示される

---

#### ステップ 4: 自動署名を有効にする

**Signing & Capabilities** タブに戻り:

1. **Team** プルダ��ンをクリック → あなたのアカウントを選択  
2. **Automatically manage signing** にチェックを入れる  
3. Xcode が自動で Provisioning Profile を生成・更新します  

エラーが出た場合は **Try Again** または **Register Device** ボタンをクリック。

---

#### ステップ 5: `pubspec.yaml` の `name` を更新（任意）

`pubspec.yaml` の先頭にあるパッケージ名も合わせて変更しておくと整合性が取れます��

```yaml
# Before
name: kintorekioku

# After
name: reprank
```

変更後にターミナルで実行:

```bash
cd /Users/bossen/Desktop/kintorekioku
flutter pub get
```

---

#### ステップ 6: ビルド確認

```bash
cd /Users/bossen/Desktop/kintorekioku
flutter build ios --simulator --debug
```

エラーなく `✓ Built` と表示されれば完了です。

---

## 作業4: プライバシーポリシーを公開する（GitHub Pages）

App Store Connect にはプライバシーポリシーの **公開 URL** が必要です���  
GitHub Pages を使えば無料で URL を取得できます。

---

### 前提

- GitHub アカウントを持っている（なければ https://github.com で無料作成）
- ターミナルで `git` が使えること

---

### 手順

#### ステップ 1: GitHub にリポジトリを作成

1. https://github.com/new を開く  
2. 以下のように設定:

| 項目 | 設定値 |
|------|--------|
| Repository name | `reprank` （または任意の名前）|
| Visibility | **Public**（Pages を無料で使うため） |
| Initialize this repository with a README | チェックしなくてOK |

3. **Create repository** をクリック  

---

#### ステップ 2: プロジェクトを GitHub にプッシュ

ターミナルで以下を順番に実���してください。

```bash
cd /Users/bossen/Desktop/kintorekioku

# Git を初期化（まだの場合��
git init

# 全ファイルをステージング
git add .
git commit -m "Initial commit"

# リモートリポジトリを追加（あなたのGitHubユーザー名に変更）
git remote add origin https://github.com/あなたのGitHubユーザー名/reprank.git

# プッシュ
git branch -M main
git push -u origin main
```

> GitHub のユーザー名が `tsukinowa` であれば:  
> `https://github.com/tsukinowa/reprank.git`

パスワードを求められた場合は、GitHub の  
**Settings > Developer settings > Personal access tokens** で  
トークンを発行してパスワードとして使用してください。

---

#### ステップ 3: GitHub Pages を有効にする

1. GitHub のリポジトリページを開く  
   （例: `https://github.com/tsukinowa/reprank`）  
2. 上部タブの **Settings** をクリック  
3. 左メニューの **Pages** をクリック  
4. **Source** セクションで:

```
Branch: main
Folder: /docs
```

と設定して **Save** をクリック。

---

#### ステップ 4: URL を確認する

数分後（最長5分）に以下の URL でアクセスできるようになります。

```
https://あなたのGitHubユーザー名.github.io/reprank/privacy-policy.html
```

例:
```
https://tsukinowa.github.io/reprank/privacy-policy.html
```

ブラウザで開いてプライバシーポリシーが表示されれば完了��す。

---

#### ステップ 5: App Store Connect に URL を入力

1. https://appstoreconnect.apple.com を開く  
2. アプリの **App Information** ページ  
3. **Privacy Policy URL** 欄に上記 URL を入力して保存

---

### まとめ

| 作業 | 所要時間の目安 |
|------|--------------|
| Bundle ID 変更 | 10〜15分 |
| GitHub リポジ��リ作成 & プッシュ | 10〜20分 |
| GitHub Pages 有効化 | 5分 + 反映待ち最大5分 |
| App Store Connect に URL 入力 | 5分 |

---

### トラブル���ューティング

**Q: Xcode で「No accounts found」と出る**  
A: ステップ3のアカウント追加が完了していません。Xcode Settings > Accounts でサインインしてく��さい。

**Q: GitHub Pages の URL にアクセスしたら 404 エラー**  
A: Pages の有効化直後は反映に5〜10分かかります。少し待ってから再試行してください。  
または Settings > Pages で Source が正しく `/docs` に設定されているか確認してください。

**Q: `git push` で認証エラーが出る**  
A: GitHub の Personal Access Token が必要です。  
GitHub > Settings > Developer settings > Personal access tokens > Generate new token  
で `repo` スコープのトークンを作成し、パスワードとして使用してください。

**Q: Bundle ID がすでに使われていると言われる**  
A: App Store には同じ Bundle ID を持つアプリは存在できません。  
別の名前（例: `com.tsukinowa.reprank2026`）を試してください。
