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
                Text(kind == "stopwatch" ? "ワークアウト計測中" : (exerciseName ?? "休憩タイマー"))
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

    private var exerciseName: String? {
        sharedDefaults.string(forKey: context.attributes.prefixedKey("exerciseName"))
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
