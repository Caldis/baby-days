import SwiftUI
#if canImport(WidgetKit)
import WidgetKit
#endif

/// 小组件尺寸, 与 WidgetFamily 的 systemSmall / systemMedium / systemLarge 对应
enum WidgetSize: String, CaseIterable, Sendable {
    case small, medium, large

    /// 430 pt 宽 iPhone (Plus / Pro Max) 的小组件尺寸, 用于 App 内预览与离线渲染
    var previewDimensions: CGSize {
        switch self {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 364, height: 170)
        case .large: CGSize(width: 364, height: 382)
        }
    }

    var title: String {
        switch self {
        case .small: "小"
        case .medium: "中"
        case .large: "大"
        }
    }
}

// MARK: - 小组件内容

/// 小组件前景内容, 背景由 SkyBackground 提供
struct BabyWidgetContent: View {
    let age: BabyAge
    let size: WidgetSize

    var body: some View {
        switch size {
        case .small: SmallLayout(age: age)
        case .medium: MediumLayout(age: age)
        case .large: LargeLayout(age: age)
        }
    }
}

private struct SmallLayout: View {
    let age: BabyAge
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CaptionRow(age: age, compactBadge: true)
            Spacer(minLength: 0)
            HeroNumber(age: age, size: 58)
            Chip(text: age.detail, size: 12)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct MediumLayout: View {
    let age: BabyAge
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                CaptionRow(age: age)
                Spacer(minLength: 0)
                HeroNumber(age: age, size: 58)
                Chip(text: age.detail, size: 12)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            BirthdayCard(age: age)
                .frame(width: 118)
        }
    }
}

private struct LargeLayout: View {
    let age: BabyAge
    @Environment(\.palette) private var palette
    @Environment(\.updateAvailable) private var updateAvailable

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(age.caption)
                            .font(.cute(18))
                            .foregroundStyle(palette.ink)
                        if updateAvailable { UpdateBadge() }
                    }
                    Text("\(age.birthDateText) 出生")
                        .font(.cute(11))
                        .foregroundStyle(palette.inkSoft)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                DateBadge(age: age)
            }
            Spacer(minLength: 0)
            HeroNumber(age: age, size: 88)
            HStack(spacing: 6) {
                Chip(text: age.detail, size: 14)
                if !age.isInfant && age.detail != age.totalDaysNote {
                    Chip(text: age.totalDaysNote, size: 14)
                }
            }
            Spacer(minLength: 0)
            FunFacts(age: age)
            BirthdayProgress(age: age, barHeight: 10, fontSize: 12)
                .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// 尚未设置生日时的提示, 点击小组件打开 App 完成设置
struct SetupPrompt: View {
    let size: WidgetSize
    @Environment(\.palette) private var palette

    var body: some View {
        if size == .medium {
            HStack(spacing: 16) {
                cake(44)
                texts(alignment: .leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: size == .small ? 10 : 14) {
                cake(size == .small ? 36 : 52)
                texts(alignment: .center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func cake(_ pointSize: CGFloat) -> some View {
        Image(systemName: "birthday.cake.fill")
            .font(.system(size: pointSize, weight: .semibold))
            .foregroundStyle(
                LinearGradient(colors: [palette.heroTop, palette.heroBottom], startPoint: .top, endPoint: .bottom)
            )
            .accentable()
    }

    private func texts(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text("宝宝多大")
                .font(.cute(size == .small ? 16 : 20))
                .foregroundStyle(palette.ink)
            Text(size == .large ? "打开 App 设置宝宝的生日" : "打开 App\n设置宝宝的生日")
                .font(.cute(size == .large ? 14 : 12))
                .foregroundStyle(palette.inkSoft)
                .multilineTextAlignment(alignment == .leading ? .leading : .center)
        }
    }
}

// MARK: - 组件

extension View {
    /// 系统着色时归入强调色分组; tvOS 没有 WidgetKit, 原样返回
    @ViewBuilder
    func accentable() -> some View {
        #if canImport(WidgetKit)
        widgetAccentable()
        #else
        self
        #endif
    }
}

/// 标题行, 有新版本时右侧显示提示
private struct CaptionRow: View {
    let age: BabyAge
    var compactBadge = false
    @Environment(\.palette) private var palette
    @Environment(\.updateAvailable) private var updateAvailable

    var body: some View {
        HStack(spacing: 4) {
            Text(age.caption)
                .font(.cute(15))
                .foregroundStyle(palette.inkSoft)
                .lineLimit(1)
                .fixedSize()
            Spacer(minLength: 0)
            if updateAvailable { UpdateBadge(compact: compactBadge) }
        }
    }
}

/// "有新版本" 提示, 点击小组件后打开 App 完成更新
struct UpdateBadge: View {
    /// 小号空间有限, 只显示 "更新"
    var compact = false
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 10, weight: .bold))
            Text(compact ? "更新" : "有新版本")
                .font(.cute(10))
        }
        .lineLimit(1)
        .fixedSize()
        .foregroundStyle(palette.isMono ? palette.ink : Color.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(palette.isMono ? Color.white.opacity(0.25) : palette.heroBottom))
        .accentable()
    }
}

/// 主数字与单位
struct HeroNumber: View {
    let age: BabyAge
    let size: CGFloat
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: size * 0.05) {
            ForEach(Array(age.heroSegments.enumerated()), id: \.offset) { _, segment in
                Text(segment.value)
                    .font(.hero(size))
                    .kerning(-size * 0.02)
                    .foregroundStyle(
                        LinearGradient(colors: [palette.heroTop, palette.heroBottom], startPoint: .top, endPoint: .bottom)
                    )
                    .shadow(color: palette.heroShadow, radius: 0, x: 0, y: size * 0.045)
                    .accentable()
                Text(segment.unit)
                    .font(.cute(size * 0.4))
                    .foregroundStyle(palette.ink)
            }
            if age.isBirthday {
                Image(systemName: "birthday.cake.fill")
                    .font(.system(size: size * 0.5, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(colors: [palette.heroTop, palette.heroBottom], startPoint: .top, endPoint: .bottom)
                    )
                    .padding(.leading, size * 0.08)
                    .accentable()
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

/// 胶囊标签
struct Chip: View {
    let text: String
    var size: CGFloat = 12
    @Environment(\.palette) private var palette

    var body: some View {
        Text(text)
            .font(.cute(size))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(palette.chipInk)
            .padding(.horizontal, size * 0.75)
            .padding(.vertical, size * 0.36)
            .background(Capsule().fill(palette.chip))
    }
}

/// 日期徽章
private struct DateBadge: View {
    let age: BabyAge
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 2) {
            Text(age.dateText)
                .font(.cute(13))
                .foregroundStyle(palette.ink)
            Text(age.weekdayText)
                .font(.cute(10))
                .foregroundStyle(palette.inkSoft)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(palette.chip))
    }
}

/// 生日倒计时与当前一岁的进度条
struct BirthdayProgress: View {
    let age: BabyAge
    var barHeight: CGFloat = 8
    var fontSize: CGFloat = 11
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: fontSize * 0.45) {
            HStack(spacing: 4) {
                Image(systemName: "birthday.cake.fill")
                    .font(.system(size: fontSize, weight: .semibold))
                    .foregroundStyle(palette.isMono ? palette.ink : palette.heroBottom)
                Text(age.countdown)
                    .font(.cute(fontSize))
                    .foregroundStyle(palette.inkSoft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            ProgressTrack(progress: age.birthdayProgress, height: barHeight)
        }
    }
}

/// 中号右侧的生日倒计时卡片
struct BirthdayCard: View {
    let age: BabyAge
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: "birthday.cake.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [palette.heroTop, palette.heroBottom], startPoint: .top, endPoint: .bottom)
                )
                .accentable()
            Text(age.countdownTitle)
                .font(.cute(12))
                .foregroundStyle(palette.inkSoft)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(age.countdownValue)
                    .font(.hero(30))
                    .foregroundStyle(palette.ink)
                Text(age.countdownUnit)
                    .font(.cute(12))
                    .foregroundStyle(palette.ink)
            }
            ProgressTrack(progress: age.birthdayProgress, height: 6)
                .padding(.top, 3)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(palette.chip))
    }
}

/// 圆角进度条
struct ProgressTrack: View {
    let progress: Double
    var height: CGFloat = 8
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.track)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [palette.trackFillStart, palette.trackFillEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(height, geo.size.width * progress))
                    .accentable()
            }
        }
        .frame(height: height)
    }
}

/// 换个角度看年龄: 周龄, 已度过的小时数, 心跳次数估算
struct FunFacts: View {
    let age: BabyAge
    /// 字号与间距的整体缩放, Apple TV 上放大使用
    var scale: CGFloat = 1
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 8 * scale) {
            tile(title: "周龄", segments: weekSegments)
            tile(title: "已经度过", segments: [(age.hoursText, "小时")])
            tile(title: "心跳约", segments: [age.heartbeats])
        }
    }

    private var weekSegments: [(value: String, unit: String)] {
        guard age.weekRemainderDays > 0 else { return [("\(age.weeks)", "周")] }
        return [("\(age.weeks)", "周"), ("\(age.weekRemainderDays)", "天")]
    }

    private func tile(title: String, segments: [(value: String, unit: String)]) -> some View {
        VStack(spacing: 3 * scale) {
            Text(title)
                .font(.cute(11 * scale))
                .foregroundStyle(palette.inkSoft)
            HStack(alignment: .firstTextBaseline, spacing: 1 * scale) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    Text(segment.value)
                        .font(.hero(22 * scale))
                        .foregroundStyle(palette.ink)
                    Text(segment.unit)
                        .font(.cute(11 * scale))
                        .foregroundStyle(palette.ink)
                        .padding(.trailing, 2 * scale)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
        .padding(.vertical, 9 * scale)
        .padding(.horizontal, 6 * scale)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous).fill(palette.chip))
    }
}

// MARK: - 背景

/// 天空背景与装饰, 作为小组件 containerBackground
struct SkyBackground: View {
    let size: WidgetSize
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { geo in
            let unit = min(geo.size.width, geo.size.height)
            ZStack {
                LinearGradient(colors: [palette.skyTop, palette.skyBottom], startPoint: .top, endPoint: .bottom)
                ForEach(Array(Decor.layout(for: size).enumerated()), id: \.offset) { _, decor in
                    if decor.visible(in: palette) {
                        decor.view(palette: palette)
                            .frame(width: decor.size * unit, height: decor.aspect * decor.size * unit)
                            .position(x: decor.x * geo.size.width, y: decor.y * geo.size.height)
                    }
                }
            }
        }
    }
}

/// 背景装饰物, 坐标为容器宽高的比例, 尺寸为容器短边的比例
struct Decor {
    enum Kind { case cloud, sparkle, sparkleAlt, dot, moon }
    enum Time { case always, day, night }

    let kind: Kind
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    var time: Time = .always

    var aspect: CGFloat { kind == .cloud ? 0.5 : 1 }

    func visible(in palette: Palette) -> Bool {
        switch time {
        case .always: true
        case .day: !palette.isNight
        case .night: palette.isNight
        }
    }

    @ViewBuilder
    func view(palette: Palette) -> some View {
        switch kind {
        case .cloud: Cloud().fill(palette.cloud)
        case .sparkle: Twinkle().fill(palette.sparkle)
        case .sparkleAlt: Twinkle().fill(palette.sparkleAlt)
        case .dot: Circle().fill(palette.sparkleAlt.opacity(0.8))
        case .moon:
            Crescent()
                .fill(palette.sparkle)
                .rotationEffect(.degrees(-20))
                .shadow(color: palette.sparkle.opacity(0.5), radius: 8)
        }
    }

    static func layout(for size: WidgetSize) -> [Decor] {
        switch size {
        case .small:
            [
                Decor(kind: .moon, x: 0.88, y: 0.13, size: 0.17, time: .night),
                Decor(kind: .cloud, x: 0.99, y: 0.12, size: 0.36, time: .day),
                Decor(kind: .cloud, x: 1.0, y: 0.24, size: 0.26, time: .night),
                Decor(kind: .cloud, x: 0.92, y: 0.95, size: 0.54),
                Decor(kind: .sparkle, x: 0.86, y: 0.36, size: 0.09),
                Decor(kind: .sparkleAlt, x: 0.95, y: 0.47, size: 0.055),
                Decor(kind: .dot, x: 0.72, y: 0.3, size: 0.03),
            ]
        case .medium:
            [
                Decor(kind: .moon, x: 0.5, y: 0.2, size: 0.2, time: .night),
                Decor(kind: .cloud, x: 0.5, y: 0.14, size: 0.4, time: .day),
                Decor(kind: .cloud, x: 0.55, y: 0.3, size: 0.28, time: .night),
                Decor(kind: .cloud, x: 0.5, y: 1.0, size: 0.5),
                Decor(kind: .sparkle, x: 0.56, y: 0.55, size: 0.09),
                Decor(kind: .sparkleAlt, x: 0.98, y: 0.05, size: 0.06),
                Decor(kind: .dot, x: 0.38, y: 0.1, size: 0.03),
                Decor(kind: .dot, x: 0.6, y: 0.76, size: 0.028),
            ]
        case .large:
            [
                Decor(kind: .moon, x: 0.86, y: 0.33, size: 0.14, time: .night),
                Decor(kind: .cloud, x: 0.92, y: 0.36, size: 0.32, time: .day),
                Decor(kind: .cloud, x: 0.95, y: 0.41, size: 0.24, time: .night),
                Decor(kind: .cloud, x: 0.06, y: 0.55, size: 0.3),
                Decor(kind: .sparkle, x: 0.2, y: 0.34, size: 0.07),
                Decor(kind: .sparkleAlt, x: 0.8, y: 0.55, size: 0.05),
                Decor(kind: .dot, x: 0.14, y: 0.46, size: 0.022),
                Decor(kind: .dot, x: 0.74, y: 0.27, size: 0.02),
            ]
        }
    }
}

// MARK: - 预览卡片

/// 模拟小组件外观的卡片, 用于 App 内预览与离线渲染
struct WidgetCard: View {
    let age: BabyAge
    let size: WidgetSize
    var dimensions: CGSize?
    var margin: CGFloat = 16

    var body: some View {
        let frame = dimensions ?? size.previewDimensions
        BabyWidgetContent(age: age, size: size)
            .padding(margin)
            .frame(width: frame.width, height: frame.height)
            .background(SkyBackground(size: size))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
