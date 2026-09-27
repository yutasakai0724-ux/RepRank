# Rep Rank — Android リリース手順

最終更新: 2026-06-15  
アプリ ID: `com.yutasakai.reprank`  
現在バージョン: `1.0.0+1`

---

## 進捗チェックリスト

- [x] Firebase Console に Android アプリ登録
- [x] `google-services.json` を `android/app/` に配置
- [x] `build.gradle.kts` に Firebase / Crashlytics プラグイン追加済み
- [x] 署名キーストア作成済み（`android/app/reprank-release.jks`）
- [x] `key.properties` 設定済み（git 管理外）
- [x] AdMob 本番アプリ ID を差し替え
- [x] Google Play Console でアプリ登録
- [ ] 内部テストトラックにアップロード
- [ ] ストア情報・スクリーンショット入力
- [ ] 本番トラックに昇格・公開

---

## 1. AdMob 本番 ID の差し替え（リリース前に必須）

現在はテスト ID が設定されています。本番 ID を取得して差し替えてください。

### 1-1. AdMob Console でアプリ登録

1. [AdMob Console](https://admob.google.com/) にアクセス
2. 「アプリを追加」→ Android を選択
3. アプリ名: **Rep Rank**、パッケージ名: `com.yutasakai.reprank`
4. 「アプリ ID」（`ca-app-pub-XXXX~XXXX` 形式）を控える
5. 広告ユニット（バナー・リワード）を作成し、それぞれの広告ユニット ID を控える

### 1-2. AndroidManifest.xml を差し替え

`android/app/src/main/AndroidManifest.xml` の該当行を編集:

```xml
<!-- 変更前（テスト ID） -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713"/>

<!-- 変更後（本番 ID） -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>
```

### 1-3. ad_service.dart を差し替え

`lib/services/ad_service.dart` 内の Android 用広告ユニット ID を本番 ID に変更する。  
（バナー・リワードそれぞれ）

---

## 2. リリースビルドの作成

### 2-1. 署名設定の確認

`android/key.properties` が以下の形式で存在することを確認:

```
storePassword=reprank2026
keyPassword=reprank2026
keyAlias=reprank
storeFile=app/reprank-release.jks
```

> `key.properties` と `reprank-release.jks` は `.gitignore` で git 管理対象外。  
> 紛失するとアップデート不能になるため、必ず安全な場所にバックアップを保管すること。

### 2-2. AAB（Android App Bundle）をビルド

Google Play への提出は APK ではなく **AAB 形式**が必要。

```bash
cd /Users/bossen/Desktop/kintorekioku
flutter build appbundle --release
```

ビルド成功後の出力先:

```
build/app/outputs/bundle/release/app-release.aab
```

---

## 3. Google Play Console でアプリ登録

1. [Google Play Console](https://play.google.com/console/) にアクセス
2. 「アプリを作成」をクリック
3. 以下を入力:
   - アプリ名: **Rep Rank**
   - デフォルト言語: **日本語**
   - アプリの種類: **アプリ**
   - 無料 / 有料: **無料**
4. 「Google Play デベロッパー販売 / 配布契約」に同意して作成

---

## 4. 内部テストトラックへのアップロード

本番公開前に内部テストで動作確認することを推奨。

1. Play Console の左メニュー「テスト」→「内部テスト」
2. 「新しいリリースを作成」
3. 「App Bundle をアップロード」→ `app-release.aab` を選択
4. リリースノート（任意）を入力して「リリースを保存」
5. 「内部テストに公開」→テスター（自分のアカウント）を追加
6. テスター URL からアプリをインストールして動作確認

---

## 5. ストア掲載情報の入力

Play Console の「ストアへの掲載情報」から以下を入力。

### 5-1. メインのストア掲載情報

| 項目 | 内容 |
|---|---|
| アプリ名 | Rep Rank |
| 短い説明（80文字以内） | 重量と回数を入力するだけで強さが分かる、シンプルな筋トレ記録アプリ |
| 詳細な説明（4000文字以内） | ※後述のテンプレートを使用 |

**詳細な説明テンプレート（App Store 版と同内容で可）:**

```
Rep Rankは、筋トレの記録・分析に特化したシンプルなアプリです。
重量と回数を入力するだけで、1RMが自動計算され、あなたの「強さ」を5段階で評価します。

【主な機能】
• ワークアウト記録 — 種目・重量・回数・セット数をすばやく入力
• 1RM 自動計算 — 入力値から最大挙上重量を即座に推定
• 強度ティア表示 — 初心者〜エリートの5段階で現在地を可視化
• カレンダー履歴 — 過去のトレーニングをひと目で振り返る
• ルーティン管理 — よく使う種目セットを登録して素早くスタート
• クラウド同期 — アカウント登録でデバイス間のデータを同期

【シンプル設計】
余計な機能は持たず、記録のしやすさを最優先に設計。
オフラインでも完全に動作します。
```

### 5-2. スクリーンショット

必要なサイズ（最低1枚、最大8枚）:

| デバイス | 要件 |
|---|---|
| スマートフォン | 16:9 縦向き（例: 1080×1920px）最低2枚 |
| 7インチタブレット | 任意 |
| 10インチタブレット | 任意 |

**撮影方法（Android エミュレーターを使用する場合）:**

```bash
# Android エミュレーターでデバッグ起動
flutter run

# Android Studio の「Device Manager」でエミュレーターのスクリーンショットボタンを使用
# または adb コマンドで取得:
adb shell screencap -p /sdcard/screenshot.png
adb pull /sdcard/screenshot.png ~/Desktop/
```

### 5-3. アイコン

Play Console に **512×512px PNG** をアップロード。  
（`flutter_launcher_icons` で生成した素材を使用可）

### 5-4. フィーチャーグラフィック（必須）

**1024×500px PNG または JPEG** が必要。  
（シンプルな横向きのアプリ紹介バナー。Canva 等で作成可）

---

## 6. アプリのコンテンツ設定（必須）

Play Console の「コンテンツのレーティング」「ターゲット層」「データセーフティ」の3項目を入力。

### 6-1. コンテンツのレーティング

「レーティングを開始」→ アンケートに回答（暴力・性的表現なし → 全年齢対象）

### 6-2. ターゲット層

- 対象年齢: **18歳以上**（または 13歳以上でも可）
- 子ども向け機能なし

### 6-3. データセーフティ（重要）

「データセーフティ」セクションで以下の通り申告:

| 項目 | 申告内容 |
|---|---|
| ユーザーのデータを第三者と共有するか | **はい**（Firebase / AdMob） |
| ユーザーのデータを収集するか | **はい** |

**収集するデータの種類（チェックを入れる）:**

- **健康とフィットネス** — ワークアウト記録（任意）
- **個人情報** — メールアドレス（アカウント登録時のみ）
- **アプリのアクティビティ** — アプリ内操作（Firebase Analytics）
- **クラッシュログ** — Firebase Crashlytics

> ※ プライバシーポリシー URL:  
> `https://yutasakai0724-ux.github.io/RepRank/privacy-policy.html`

---

## 7. 本番トラックへの昇格と公開

1. 内部テストで問題がないことを確認
2. Play Console「本番」→「新しいリリースを作成」
3. 内部テストと同じ AAB を選択（または新たにビルドして追加）
4. 「リリースノート」を入力（例: `初回リリース`）
5. 「本番への公開を開始」→「公開」

> 初回審査は通常 **1〜3日** かかる。

---

## 8. バージョンアップの手順（2回目以降）

### 8-1. pubspec.yaml のバージョンを上げる

```yaml
# 例: 1.0.0+1 → 1.0.1+2
version: 1.0.1+2
```

- `+` より前（`1.0.1`）: ユーザーに表示されるバージョン名
- `+` より後（`2`）: versionCode（Play Store 内部管理番号。毎回必ず増やす）

### 8-2. 再ビルドして AAB を生成

```bash
flutter build appbundle --release
```

### 8-3. Play Console にアップロード

「本番」→「新しいリリースを作成」→ 新しい AAB をアップロード → 公開

---

## 9. Firebase SHA-1 の登録（Google Sign-In に必要）

Android で Google Sign-In を動作させるには、署名証明書の SHA-1 フィンガープリントを Firebase に登録する必要があります。

### 9-1. デバッグ用 SHA-1 の取得

```bash
cd /Users/bossen/Desktop/kintorekioku/android
./gradlew signingReport
```

出力の `Variant: debug` セクションにある `SHA1:` の値を控える。

### 9-2. リリース用 SHA-1 の取得

```bash
keytool -list -v \
  -keystore /Users/bossen/Desktop/kintorekioku/android/app/reprank-release.jks \
  -alias reprank
# パスワード: reprank2026
```

### 9-3. Firebase Console に登録

1. [Firebase Console](https://console.firebase.google.com/) → Rep Rank プロジェクト
2. 「プロジェクトの設定」→「アプリ」→ Android アプリを選択
3. 「フィンガープリントを追加」→ SHA-1 を貼り付けて保存
4. `google-services.json` を再ダウンロードして `android/app/` に上書き

> デバッグ用・リリース用の両方を登録しておくことを推奨。

---

## 10. 実機テスト用ビルド

リリース署名済みAPKを実機にインストールして動作確認する手順。

### 10-1. デバッグビルド（署名不要・最速）

```bash
flutter build apk --debug
flutter install
```

> Google Sign-In などOAuth機能はデバッグSHA-1をFirebaseに登録済みであれば動作する。

### 10-2. リリース署名済みAPK（本番と同じ署名）

Play Storeと同じ署名でテストしたい場合に使用。

```bash
flutter build apk --release
```

出力先:
```
build/app/outputs/flutter-apk/app-release.apk
```

実機にインストール（USBデバッグ有効・端末を接続した状態で）:
```bash
flutter install --release
# または
adb install build/app/outputs/flutter-apk/app-release.apk
```

> **注意:** Play Storeからインストール済みの場合は先にアンインストールが必要（署名の競合）。

### 10-3. 特定端末を指定してインストール

複数端末が接続されている場合:
```bash
# 接続端末一覧
flutter devices

# 端末を指定してインストール
flutter install -d <device-id>
```

---

## 11. よく使うコマンド

```bash
# リリースビルド（AAB）
flutter build appbundle --release

# リリース APK（動作確認用・実機インストール）
flutter build apk --release

# 署名確認
keytool -list -v \
  -keystore android/app/reprank-release.jks \
  -alias reprank

# ビルド番号確認
grep "^version" pubspec.yaml
```
