import AppKit
import CoreText
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

/// 离线渲染工具: 输出小组件效果图与 App 图标图层
///
/// 用法: render <仓库根目录> snapshots <输出目录>   全部场景 × 配色 × 尺寸的检查图
///      render <仓库根目录> docs <输出目录>        README 配图
///      render <仓库根目录> icon <AppIcon.icon 目录> 图标图层
@main
struct Render {
    @MainActor
    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 4 else {
            print("usage: render <repo-root> snapshots|docs|icon <output-dir>")
            exit(1)
        }
        let root = URL(fileURLWithPath: arguments[1])
        let output = URL(fileURLWithPath: arguments[3])
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let font = root.appendingPathComponent("Resources/Fonts/ZCOOLKuaiLe-Regular.ttf")
        CTFontManagerRegisterFontsForURL(font as CFURL, .process, nil)

        switch arguments[2] {
        case "snapshots": try renderSnapshots(to: output)
        case "docs": try renderDocs(to: output)
        case "icon": try IconArtwork.render(to: output)
        default:
            print("unknown mode \(arguments[2])")
            exit(1)
        }
    }

    /// 效果图使用的示例生日, 各场景以相对出生的时长表示
    static let sampleBirth = BirthDate(year: 2025, month: 1, day: 1)

    static let scenarios: [(name: String, offset: DateComponents)] = [
        ("infant", DateComponents(month: 10, day: 8)),
        ("newborn", DateComponents(day: 12)),
        ("full-month", DateComponents(month: 11)),
        ("birthday", DateComponents(year: 1)),
        ("toddler", DateComponents(year: 1, month: 2, day: 13)),
        ("toddler-late", DateComponents(year: 2, month: 11, day: 9)),
    ]

    static func age(after offset: DateComponents) -> BabyAge {
        let calendar = BabyAge.calendar
        return BabyAge(birth: sampleBirth, on: calendar.date(byAdding: offset, to: sampleBirth.date())!)
    }

    @MainActor
    static func renderSnapshots(to output: URL) throws {
        let palettes: [(String, Palette, ColorScheme)] = [
            ("day", .day, .light),
            ("night", .night, .dark),
            ("mono", .mono, .dark),
        ]
        for scenario in scenarios {
            for (paletteName, palette, scheme) in palettes {
                let sheet = SnapshotSheet(age: age(after: scenario.offset), mono: palette.isMono)
                    .environment(\.palette, palette)
                    .environment(\.colorScheme, scheme)
                try write(sheet, scale: 2, to: output.appendingPathComponent("\(scenario.name)-\(paletteName).png"))
            }
        }
        let updateSheet = SnapshotSheet(age: age(after: scenarios[0].offset), mono: false)
            .environment(\.palette, .day)
            .environment(\.updateAvailable, true)
        try write(updateSheet, scale: 2, to: output.appendingPathComponent("update-available-day.png"))
        for (paletteName, palette, scheme) in palettes {
            let setup = SnapshotSheet(age: nil, mono: palette.isMono)
                .environment(\.palette, palette)
                .environment(\.colorScheme, scheme)
            try write(setup, scale: 2, to: output.appendingPathComponent("setup-\(paletteName).png"))
        }
        try write(IconArtwork.Composite(), scale: 0.25, to: output.appendingPathComponent("icon.png"))
    }

    @MainActor
    static func renderDocs(to output: URL) throws {
        let pages: [(String, DateComponents, Palette, ColorScheme)] = [
            ("widgets-infant", scenarios[0].offset, .day, .light),
            ("widgets-night", scenarios[0].offset, .night, .dark),
            ("widgets-toddler", scenarios[4].offset, .day, .light),
            ("widgets-birthday", scenarios[3].offset, .night, .dark),
        ]
        for (name, offset, palette, scheme) in pages {
            let sheet = DocSheet(age: age(after: offset))
                .environment(\.palette, palette)
                .environment(\.colorScheme, scheme)
            try write(sheet, scale: 2, to: output.appendingPathComponent("\(name).png"))
        }
        try write(IconArtwork.Composite(), scale: 0.25, to: output.appendingPathComponent("icon.png"))
    }

    @MainActor
    static func write<V: View>(_ view: V, scale: CGFloat, to url: URL) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.cgImage else { throw RenderError.emptyImage }
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw RenderError.writeFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw RenderError.writeFailed }
        print("wrote \(url.path)")
    }

    enum RenderError: Error { case emptyImage, writeFailed }
}

/// 三种尺寸拼在一张图上
private struct SnapshotSheet: View {
    /// nil 时渲染未设置生日的提示
    let age: BabyAge?
    let mono: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                card(.small)
                card(.medium)
            }
            HStack(alignment: .top, spacing: 20) {
                card(.large)
                VStack(alignment: .leading, spacing: 20) {
                    card(.small, dimensions: CGSize(width: 158, height: 158))
                    card(.medium, dimensions: CGSize(width: 338, height: 158))
                }
            }
            // macOS 桌面小组件尺寸
            HStack(alignment: .top, spacing: 20) {
                card(.large, dimensions: CGSize(width: 345, height: 345))
                VStack(alignment: .leading, spacing: 20) {
                    card(.small, dimensions: CGSize(width: 164, height: 164))
                    card(.medium, dimensions: CGSize(width: 345, height: 164))
                }
            }
        }
        .padding(24)
        .background(scheme == .dark ? Color(hex: 0x1C1C1E) : Color(hex: 0xECEBF2))
    }

    @ViewBuilder
    private func card(_ size: WidgetSize, dimensions: CGSize? = nil) -> some View {
        let frame = dimensions ?? size.previewDimensions
        Group {
            if let age {
                BabyWidgetContent(age: age, size: size)
            } else {
                SetupPrompt(size: size)
            }
        }
        .padding(16)
        .frame(width: frame.width, height: frame.height)
        .background {
            if mono { Color.white.opacity(0.08) } else { SkyBackground(size: size) }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

/// README 配图: 小号与中号一行, 大号居中
private struct DocSheet: View {
    let age: BabyAge
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .top, spacing: 20) {
                WidgetCard(age: age, size: .small)
                WidgetCard(age: age, size: .medium)
            }
            WidgetCard(age: age, size: .large)
        }
        .padding(28)
        .background(scheme == .dark ? Color(hex: 0x1C1C1E) : Color(hex: 0xF4F3F8))
    }
}
