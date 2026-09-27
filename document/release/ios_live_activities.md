# iOS Live Activities セットアップ手順（休憩タイマー・ストップウォッチ）

休憩タイマーの残り時間・ストップウォッチの経過時間をロック画面 / Dynamic Island にリアルタイム表示するための設定。

Dart 側のコード（`lib/services/live_activity_service.dart`、`rest_timer_service.dart`、`stopwatch_service.dart`への配線）は実装済み。
本手順は **Xcode 側で必須の作業**（Widget Extension の追加）。ここは自動化できないため手動で行う。

> ⚠️ Live Activities は **iOS 16.1+** でのみ動作。それ未満の端末では何も起きない（アプリ側で自動的に無視される設計）。

---

## 前提

- `pubspec.yaml` に `live_activities: ^2.5.1` を追加済み
- `Info.plist` の `Runner` に `NSSupportsLiveActivities = true` を追加済み
- アプリ内の App Group ID は **`group.com.yutasakai.reprank`** を使用する前提（Dart 側 [`live_activity_service.dart`](../../lib/services/live_activity_service.dart) にハードコードされている）

---

## STEP 1: Widget Extension を追加

1. `open ios/Runner.xcworkspace` で Xcode を開く
2. メニュー **File → New → Target...**
3. **Widget Extension** を選択 → **Next**
4. Product Name: `RepRankWidget`（任意。以降このドキュメントでは `RepRankWidget` とする）
5. "Embed in Application" が **Runner** になっていることを確認 → **Finish**
6. 「Activate "RepRankWidgetExtension" scheme?」のアラートが出たら **Activate**

---

## STEP 2: Info.plist に Live Activities フラグを追加（両ターゲット）

`Runner` の `Info.plist` には既に追加済み。**`RepRankWidget` の Info.plist にも同様に追加**する：

```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

---

## STEP 3: Push Notifications capability を Runner に追加

1. Xcode 左ペインで **Runner** プロジェクト → **TARGETS → Runner** を選択
2. **Signing & Capabilities** タブ
3. **+ Capability** → **Push Notifications** を追加

> `RepRankWidget` 側には追加不要。Runner のみ。

---

## STEP 4: App Group capability を両ターゲットに追加

**Runner** と **RepRankWidgetExtension** の両方の **Signing & Capabilities** タブで：

1. **+ Capability** → **App Groups** を追加
2. 「+」でグループを新規作成し、ID を以下に設定：

```
group.com.yutasakai.reprank
```

3. 両ターゲットで **同じ ID にチェックが入っている**ことを確認

---

## STEP 5: Widget の Swift コードを実装

Xcode が自動生成した `RepRankWidget/RepRankWidgetLiveActivity.swift`（ファイル名は環境により異なる。`ActivityAttributes` を含むファイルを探す）を以下の内容に**置き換える**。

> ⚠️ `ActivityAttributes` の型名は **必ず `LiveActivitiesAppAttributes`** にすること（プラグインの制約。リネームすると動作しない）。

```swift
import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Attributes（プラグインの規約で型名固定）

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {}

    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}

// MARK: - App Group 経由で Flutter から渡されたデータを読む

let sharedDefaults = UserDefaults(suiteName: "group.com.yutasakai.reprank")!

// MARK: - Widget 本体

struct RepRankWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            // ロック画面 / バナー表示
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(Color.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    ContentView(context: context)
                        .padding(.vertical, 4)
                }
            } compactLeading: {
                Image(systemName: iconName(context))
                    .foregroundColor(.orange)
            } compactTrailing: {
                CompactTimeView(context: context)
            } minimal: {
                Image(systemName: iconName(context))
                    .foregroundColor(.orange)
            }
        }
    }

    private func iconName(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) -> String {
        let kind = sharedDefaults.string(forKey: context.attributes.prefixedKey("kind")) ?? "rest"
        return kind == "stopwatch" ? "stopwatch.fill" : "timer"
    }
}

// MARK: - サブビュー

struct LockScreenView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>

    var body: some View {
        HStack {
            Image(systemName: kind == "stopwatch" ? "stopwatch.fill" : "timer")
                .foregroundColor(.orange)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(kind == "stopwatch" ? "ワークアウト計測中" : "休憩タイマー")
                    .font(.caption)
                    .foregroundColor(.gray)
                ContentView(context: context)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Spacer()
        }
        .padding()
    }

    private var kind: String {
        sharedDefaults.string(forKey: context.attributes.prefixedKey("kind")) ?? "rest"
    }
}

/// 種別に応じて残り時間（カウントダウン）または経過時間（カウントアップ）を表示
struct ContentView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>

    var body: some View {
        let kind = sharedDefaults.string(forKey: context.attributes.prefixedKey("kind")) ?? "rest"

        if kind == "stopwatch" {
            if let startMs = sharedDefaults.object(forKey: context.attributes.prefixedKey("startTime")) as? Double {
                let start = Date(timeIntervalSince1970: startMs / 1000)
                Text(start, style: .timer)
            } else {
                Text("--:--")
            }
        } else {
            if let endMs = sharedDefaults.object(forKey: context.attributes.prefixedKey("endTime")) as? Double {
                let end = Date(timeIntervalSince1970: endMs / 1000)
                Text(timerInterval: Date()...end, countsDown: true)
            } else {
                Text("--:--")
            }
        }
    }
}

struct CompactTimeView: View {
    let context: ActivityViewContext<LiveActivitiesAppAttributes>

    var body: some View {
        ContentView(context: context)
            .font(.caption2)
            .monospacedDigit()
    }
}
```

---

## STEP 6: 実機で確認

Live Activities は**シミュレータでも表示可能**（iOS 16.1+ シミュレータ）だが、Dynamic Island の見た目確認は **iPhone 14 Pro 以降の実機/シミュレータ**が必要。

```bash
flutter build ios --debug
```

Xcode から実行し、記録画面で休憩タイマーをスタート → ロック画面をスリープさせてロック画面に表示されるか確認。

---

## トラブルシューティング

| 症状 | 原因 |
|---|---|
| Activity が作成されない（`createActivity` が失敗） | App Group ID が Runner / Widget Extension で一致していない |
| ロック画面に何も表示されない | `ActivityAttributes` の型名が `LiveActivitiesAppAttributes` になっていない |
| Xcode ビルドエラー（Widget Extension 側） | `NSSupportsLiveActivities` が Widget Extension の Info.plist に未追加 |
| 残り時間が更新されない | `Text(timerInterval:)` / `Text(date, style: .timer)` を使わず自前で毎秒更新しようとしている（iOS はこれらのネイティブAPIでのみ自動更新される） |

---

## 参考

- [live_activities パッケージ](https://pub.dev/packages/live_activities)
- [Apple: Displaying live data with Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities)
