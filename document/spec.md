# Rep Rank — アプリ仕様書

**バージョン**: 1.0.0  
**作成日**: 2026-06-15  
**バンドル ID**: `com.yutasakai.reprank`  
**対象プラットフォーム**: iOS（メイン）、Android（予定）

---

## 1. アプリ概要

筋トレの記録・分析に特化したシンプルなアプリ。重量と回数を入力するだけで 1RM を自動推定し、体重比による強度ティア（初心者〜エリート）を表示する。オフラインファースト設計で、アカウント登録によりクラウド同期が可能。

### コンセプト
- 記録のハードルを極力下げる（種目選択 → 重量・回数入力 → 保存）
- 自分の「強さ」を客観的な指標で可視化する
- シンプルさを最優先（不要な機能を持たない）

---

## 2. 技術スタック

| 項目 | 内容 |
|---|---|
| フレームワーク | Flutter（Dart） |
| ローカル DB | SQLite（sqflite） |
| クラウド DB | Firebase Firestore |
| 認証 | Firebase Authentication（メール/Google/Apple） |
| 分析 | Firebase Analytics |
| クラッシュ | Firebase Crashlytics |
| 広告 | Google AdMob（バナー・リワード） |
| フォント | Google Fonts（Inter, JetBrains Mono） |
| 状態管理 | StatefulWidget（Provider/Riverpod 未使用） |

---

## 3. データモデル

### 3-1. WorkoutSession（セッション）

1回のトレーニングセッション全体。

```
WorkoutSession
├── id: String（UUID）
├── sessionName: String?（任意のセッション名）
├── routineName: String?（使用したルーティン名）
├── date: DateTime（トレーニング日）
├── startedAt: DateTime（開始時刻）
├── finishedAt: DateTime?（終了時刻）
└── exercises: List<Exercise>
```

### 3-2. Exercise（種目）

セッション内の1種目。

```
Exercise
├── id: String（UUID）
├── name: String（種目名）
├── muscleGroup: MuscleGroup（部位）
└── sets: List<WorkoutSet>
```

### 3-3. WorkoutSet（セット）

種目内の1セット。

```
WorkoutSet
├── id: String（UUID）
├── setNumber: int（セット番号）
├── weight: double（重量 kg）
├── reps: int（回数）
└── recordedAt: DateTime?（記録時刻）
```

**1RM 計算式**: `weight × reps / 40 + weight`

### 3-4. MuscleGroup（部位）

```
all / chest（胸）/ back（背中）/ legs（脚）/
shoulders（肩）/ arms（腕）/ abs（腹筋）
```

---

## 4. 画面構成

ボトムナビゲーション4タブ構成。

```
App
├── [Tab 0] AnalysisScreen（分析）
├── [Tab 1] HistoryScreen（カレンダー）
├── [Tab 2] RoutinesScreen（ルーティン）
└── [Tab 3] ProfileScreen（プロフィール）
```

### 4-1. 分析画面（AnalysisScreen）

メイン画面。ホームとしての役割を持つ。

**表示内容**
- ストップウォッチ（ワークアウト全体の経過時間）
- 今日のセッション一覧（セッションカード）
- セッションカードをタップ → DailyDetailScreen へ
- 「今日のトレーニングを開始」ボタン → ExerciseRecordScreen へ
- 種目ごとの最高 1RM サマリーカード（タップで ExerciseAnalysisScreen へ）
- 「広告を見て応援する」ボタン（リワード広告）
- バナー広告（画面下部）

### 4-2. カレンダー画面（HistoryScreen）

**表示内容**
- 月次カレンダー（table_calendar）
- 記録がある日にはドット表示
- 日付タップ → その日のセッション一覧
- セッションタップ → DailyDetailScreen へ
- スワイプで削除

### 4-3. ルーティン画面（RoutinesScreen）

ユーザーが自由に作成・管理するルーティン一覧。

**表示内容**
- ルーティンカード一覧（名前・部位・種目数・目安時間）
- 追加ボタン → 作成ダイアログ
- ルーティンタップ → RoutineDetailScreen へ
- 編集モード（並び替え・削除）

**データ**: SharedPreferences に保存（揮発性）

### 4-4. プロフィール画面（ProfileScreen）

**表示内容**
- アカウントカード（未ログイン時はログインボタン）
- ユーザー名・体重・性別の設定
- 匿名統計データ共有トグル
- プライバシーポリシーリンク
- ログアウトボタン（ログイン時）

---

## 5. サブ画面

### 5-1. DailyDetailScreen

特定日の特定セッションの詳細・編集。

- 種目リストとセット一覧を表示
- セット追加・削除・重量/回数の編集
- 休憩タイマー内蔵（プリセット + カスタム秒数）
- 種目追加 → ExercisePickerSheet（ボトムシート）

### 5-2. ExerciseRecordScreen

新規トレーニングセッションの記録。

- セッション名の入力（任意）
- 種目追加 → ExercisePickerSheet
- セットの記録（重量・回数）
- 1RM のリアルタイム計算・表示
- 保存でセッションを DB に書き込み

### 5-3. ExerciseAnalysisScreen

特定種目の詳細分析。

- 1RM 推移グラフ（fl_chart）
- 体重比ティア表示
- ヒストグラム（将来実装予定）

### 5-4. RoutineDetailScreen

ルーティンの詳細・使用。

- 種目リストの表示
- 「このルーティンで開始」→ ExerciseRecordScreen へ（種目プリセット）

### 5-5. AuthScreen

ログイン / 新規登録。

- Apple でサインイン
- Google でサインイン
- メールアドレス + パスワード
- パスワードリセット

### 5-6. PrivacyConsentScreen

初回起動時のみ表示。プライバシーポリシー全文 + 同意/拒否ボタン。

---

## 6. ウィジェット

| ウィジェット | 役割 |
|---|---|
| ExercisePickerSheet | 部位別アコーディオン形式の種目選択ボトムシート。カスタム種目の追加機能付き |
| BannerAdWidget | AdMob バナー広告の表示。失敗時は SizedBox.shrink() |
| DurationPickerSheet | 休憩タイマーの秒数選択ボトムシート |

---

## 7. サービス層

### 7-1. SessionManager

進行中のセッションをメモリ上で管理するシングルトン。画面遷移をまたいで状態を保持する。

### 7-2. AuthService

Firebase Auth のラッパー。匿名→メール/Google/Apple へのアカウント昇格（リンク）機能付き。

### 7-3. SyncService

ログイン時のデータ同期。
- ローカル空 + クラウドにデータあり → クラウドからダウンロード
- ローカルにデータあり → クラウドへアップロード

### 7-4. CloudDataService

匿名統計データ（種目名・体重比）の Firestore への書き込み。オプトイン時のみ動作。

### 7-5. AdService

AdMob のバナー・リワード広告管理シングルトン。

### 7-6. AnalyticsService

Firebase Analytics のイベント送信ラッパー。

### 7-7. UserPreferences

SharedPreferences のラッパー。体重・ユーザー名・性別・休憩時間・統計共有フラグ・プライバシー同意フラグ・カスタム種目を管理。

### 7-8. StopwatchService

ワークアウト全体のストップウォッチ。

---

## 8. リポジトリ層

オフラインファースト設計。通常時は SQLite のみ使用し、ログイン後は Firestore にも同期する。

```
WorkoutRepository（インターフェース）
├── SqliteWorkoutRepository   ← 未ログイン時
├── FirestoreWorkoutRepository ← Firestore 単体
└── HybridWorkoutRepository   ← ログイン後（読み: SQLite / 書き: 両方）
```

**Firestore パス**: `users/{uid}/sessions/{sessionId}`

---

## 9. 強度基準（StrengthTier）

ExRx 基準の体重倍率をもとに5段階評価。

| ティア | 表示 | カラー |
|---|---|---|
| beginner | 初心者 | グレー #6B7280 |
| novice | 初級 | ブルー（kSecondary） |
| intermediate | 中級 | グリーン（kTertiary） |
| advanced | 上級 | オレンジ（kPrimary） |
| elite | エリート | ゴールド #FFD700 |

基準値は10種目分を個別定義し、未定義種目は部位別フォールバック値を使用。

---

## 10. デザインシステム

### カラーパレット（ダークテーマ固定）

| トークン | 値 | 用途 |
|---|---|---|
| kBackground | #131313 | 背景 |
| kSurface | #131313 | サーフェス |
| kSurfaceContainerLow | #1C1B1B | カード |
| kSurfaceContainerHigh | #2A2A2A | 入力フィールド |
| kPrimary | #FF6B00 | アクション・強調 |
| kSecondary | #ADC6FF | ブルー |
| kTertiary | #4DE082 | グリーン（成功） |
| kOnSurface | #E5E2E1 | 主要テキスト |
| kOnSurfaceVariant | #E2BFB0 | 補助テキスト（ウォーム） |

### フォント
- **本文・UI**: Inter（Google Fonts）
- **ラベル・タグ**: JetBrains Mono（Google Fonts）

---

## 11. Firebase 構成

| サービス | 用途 |
|---|---|
| Authentication | メール / Google / Apple サインイン、匿名認証 |
| Firestore | ワークアウトセッションのクラウド保存、匿名統計データ収集 |
| Analytics | 画面遷移・機能利用イベントの収集 |
| Crashlytics | クラッシュレポート |

### Firestore セキュリティルール方針
- `users/{uid}/sessions/` は本人のみ読み書き可
- `exercise_ratios/` は認証済みユーザーが読み書き可（更新・削除は不可）
- それ以外はすべて拒否

---

## 12. 広告構成

| 広告タイプ | 配置 | 備考 |
|---|---|---|
| バナー広告 | 全画面の下部 | BannerAdWidget |
| リワード広告 | 分析タブ下部「広告を見て応援する」ボタン | リワードは付与しない |

---

## 13. 既知の制約・TODO

| 項目 | 内容 |
|---|---|
| AdMob 本番 ID | テスト ID のまま。リリース前に AdMob Console で取得して差し替えが必要 |
| Apple Sign-In（Android） | Service ID の設定が未完了 |
| ルーティンの永続化 | 現状は揮発性（アプリ再起動で消える）。SharedPreferences への保存が必要 |
| ヒストグラム機能 | CloudDataService で収集中だが、表示 UI は未実装 |
| 女性向け強度基準 | 現状は男性基準のみ |
| ダークテーマ固定 | ライトテーマへの切り替えは未対応 |

---

## 14. ディレクトリ構成

```
lib/
├── main.dart                      # エントリーポイント・AuthGate・ナビゲーション
├── theme.dart                     # デザインシステム（カラー・テーマ）
├── firebase_options.dart          # Firebase 設定（自動生成）
│
├── models/
│   └── workout.dart               # WorkoutSession / Exercise / WorkoutSet / MuscleGroup
│
├── data/
│   ├── database_helper.dart       # SQLite 初期化
│   └── strength_standards.dart    # ExRx 基準値・StrengthTier
│
├── repositories/
│   ├── workout_repository.dart    # インターフェース
│   ├── sqlite_workout_repository.dart
│   ├── firestore_workout_repository.dart
│   └── hybrid_workout_repository.dart
│
├── services/
│   ├── session_manager.dart       # 進行中セッション管理
│   ├── auth_service.dart          # Firebase Auth ラッパー
│   ├── sync_service.dart          # ログイン時データ同期
│   ├── cloud_data_service.dart    # 匿名統計データ送信
│   ├── ad_service.dart            # AdMob 管理
│   ├── analytics_service.dart     # Firebase Analytics
│   ├── firebase_init.dart         # Firebase 初期化
│   ├── user_preferences.dart      # SharedPreferences ラッパー
│   └── stopwatch_service.dart     # ストップウォッチ
│
├── screens/
│   ├── analysis_screen.dart       # [Tab 0] 分析
│   ├── history_screen.dart        # [Tab 1] カレンダー
│   ├── routines_screen.dart       # [Tab 2] ルーティン
│   ├── profile_screen.dart        # [Tab 3] プロフィール
│   ├── daily_detail_screen.dart   # セッション詳細・編集
│   ├── exercise_record_screen.dart # 新規記録
│   ├── exercise_analysis_screen.dart # 種目別分析
│   ├── routine_detail_screen.dart # ルーティン詳細
│   ├── auth_screen.dart           # ログイン・新規登録
│   └── privacy_consent_screen.dart # 初回プライバシー同意
│
├── widgets/
│   ├── exercise_picker_sheet.dart # 種目選択ボトムシート
│   ├── banner_ad_widget.dart      # バナー広告
│   └── duration_picker_sheet.dart # 秒数選択
│
└── utils/
    └── time_format.dart           # 時間フォーマットユーティリティ
```
