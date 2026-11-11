import SwiftUI
import WidgetKit
import AppIntents

struct AgeEntry: TimelineEntry {
    let date: Date
    /// nil 表示尚未在 App 中设置生日
    var birth: BirthDate?
    var updateAvailable = false
    var babyID: String?
    var babyName: String = "宝宝"
    var missingBaby = false

    var age: BabyAge? { birth.map { BabyAge(birth: $0, on: date) } }
}

/// 每天 0 点切换一条记录, 一次排好未来 7 天, 并在次日 0 点后重新请求时间线
struct AgeProvider: AppIntentTimelineProvider {
    typealias Intent = SelectBabyIntent
    func placeholder(in context: Context) -> AgeEntry {
        AgeEntry(date: .now, birth: .sample())
    }

    func snapshot(for configuration: SelectBabyIntent, in context: Context) async -> AgeEntry {
        if !context.isPreview { await BabyCloudSync.shared.refresh() }
        let baby = BabyProfile.baby(id: configuration.babyID)
        if let baby { return entry(baby, date: .now) }
        if context.isPreview && configuration.babyID == nil { return AgeEntry(date: .now, birth: .sample()) }
        return AgeEntry(date: .now, missingBaby: configuration.babyID != nil)
    }

    func timeline(for configuration: SelectBabyIntent, in context: Context) async -> Timeline<AgeEntry> {
        await BabyCloudSync.shared.refresh()
        #if os(macOS)
        if UpdateFeed.isStaleProcess {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { exit(0) }
            return Timeline(entries: [AgeEntry(date: .now)], policy: .after(.now.addingTimeInterval(60)))
        }
        #endif
        #if os(macOS) && !APP_STORE
        let update = await UpdateFeed.isUpdateAvailable()
        #else
        let update = false
        #endif
        let baby = BabyProfile.baby(id: configuration.babyID)
        let calendar = BabyAge.calendar
        let today = calendar.startOfDay(for: .now)
        let upcoming = (1...7).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
        let entries = ([Date.now] + upcoming).map { date -> AgeEntry in
            guard let baby else { return AgeEntry(date: date, missingBaby: configuration.babyID != nil) }
            var result = entry(baby, date: date)
            result.updateAvailable = update
            return result
        }
        return Timeline(entries: entries, policy: .after(upcoming[0]))
    }
    private func entry(_ baby: Baby, date: Date) -> AgeEntry {
        AgeEntry(date: date, birth: baby.birth, babyID: baby.id, babyName: baby.displayName)
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
            .environment(\.babyName, entry.babyName)
            .widgetURL(entry.updateAvailable ? URL(string: "babydays://update") : entry.babyID.flatMap { URL(string: "babydays://baby/\($0)") })
            .containerBackground(for: .widget) {
                SkyBackground(size: size)
                    .environment(\.palette, palette)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let age = entry.age {
            BabyWidgetContent(age: age, size: size)
        } else if entry.missingBaby {
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle.badge.questionmark").font(.title)
                Text("宝宝已移除").font(.cute(16))
                Text("编辑小组件, 重新选择宝宝").font(.cute(12)).multilineTextAlignment(.center)
            }
            .foregroundStyle(palette.ink)
        } else {
            SetupPrompt(size: size)
        }
    }

    /// 系统着色时用单色; 背景被移除 (如 StandBy) 时内容直接落在黑底上, 改用夜间配色
    private var palette: Palette {
        guard renderingMode == .fullColor else { return .mono }
        return Palette.for(showsBackground ? colorScheme : .dark, zodiac: entry.birth.map(Zodiac.init(birth:)) ?? .snake)
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
        AppIntentConfiguration(kind: "BabyDaysWidget", intent: SelectBabyIntent.self, provider: AgeProvider()) { entry in
            BabyDaysWidgetView(entry: entry)
        }
        .configurationDisplayName("宝宝多大")
        .description("选择一位宝宝, 看看今天多大啦")
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
