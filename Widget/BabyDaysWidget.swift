import SwiftUI
import WidgetKit

struct AgeEntry: TimelineEntry {
    let date: Date
    /// nil 表示尚未在 App 中设置生日
    var birth: BirthDate?
    var updateAvailable = false

    var age: BabyAge? { birth.map { BabyAge(birth: $0, on: date) } }
}

/// 每天 0 点切换一条记录, 一次排好未来 7 天, 并在次日 0 点后重新请求时间线
struct AgeProvider: TimelineProvider {
    func placeholder(in context: Context) -> AgeEntry {
        AgeEntry(date: .now, birth: .sample())
    }

    /// 小组件库预览: 未设置生日时使用示例生日
    func getSnapshot(in context: Context, completion: @escaping (AgeEntry) -> Void) {
        completion(AgeEntry(date: .now, birth: BabyProfile.birthDate ?? .sample()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AgeEntry>) -> Void) {
        #if os(macOS)
        if UpdateFeed.isStaleProcess {
            // 旧版本进程交回一条 1 分钟后过期的时间线后退出, 系统下次请求时启动新版本扩展
            completion(Timeline(entries: [AgeEntry(date: .now)], policy: .after(.now.addingTimeInterval(60))))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { exit(0) }
            return
        }
        #endif
        Task {
            #if os(macOS) && !APP_STORE
            let updateAvailable = await UpdateFeed.isUpdateAvailable()
            #else
            let updateAvailable = false
            #endif
            let birth = BabyProfile.birthDate
            let calendar = BabyAge.calendar
            let today = calendar.startOfDay(for: .now)
            let upcoming = (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
            let entries = ([Date.now] + upcoming).map {
                AgeEntry(date: $0, birth: birth, updateAvailable: updateAvailable)
            }
            completion(Timeline(entries: entries, policy: .after(upcoming[0])))
        }
    }
}

struct BabyDaysWidgetView: View {
    let entry: AgeEntry
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.showsWidgetContainerBackground) private var showsBackground

    var body: some View {
        content
            .environment(\.palette, palette)
            .environment(\.updateAvailable, entry.updateAvailable)
            .widgetURL(entry.updateAvailable ? URL(string: "babydays://update") : nil)
            .containerBackground(for: .widget) {
                SkyBackground(size: size)
                    .environment(\.palette, palette)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let age = entry.age {
            BabyWidgetContent(age: age, size: size)
        } else {
            SetupPrompt(size: size)
        }
    }

    /// 系统着色时用单色; 背景被移除 (如 StandBy) 时内容直接落在黑底上, 改用夜间配色
    private var palette: Palette {
        guard renderingMode == .fullColor else { return .mono }
        return showsBackground ? Palette.for(colorScheme) : .night
    }

    private var size: WidgetSize {
        switch family {
        case .systemMedium: .medium
        case .systemLarge: .large
        default: .small
        }
    }
}

@main
struct BabyDaysWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BabyDaysWidget", provider: AgeProvider()) { entry in
            BabyDaysWidgetView(entry: entry)
        }
        .configurationDisplayName("宝宝多大")
        .description("看看宝宝今天多大啦")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview("小", as: .systemSmall) {
    BabyDaysWidget()
} timeline: {
    AgeEntry(date: .now, birth: .sample())
    AgeEntry(date: .now)
}

#Preview("中", as: .systemMedium) {
    BabyDaysWidget()
} timeline: {
    AgeEntry(date: .now, birth: .sample())
}

#Preview("大", as: .systemLarge) {
    BabyDaysWidget()
} timeline: {
    AgeEntry(date: .now, birth: .sample())
}
