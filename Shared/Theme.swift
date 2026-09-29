import SwiftUI

/// 小组件配色, 取自布偶小蛇的嫩绿与奶白; 白天为草地晴空, 夜晚为林间星空, 单色用于系统着色与桌面浅色化模式
struct Palette: Sendable {
    enum Kind: Sendable { case day, night, mono }

    let kind: Kind
    let skyTop: Color
    let skyBottom: Color
    let ink: Color
    let inkSoft: Color
    let heroTop: Color
    let heroBottom: Color
    let heroShadow: Color
    let chip: Color
    let chipInk: Color
    let cloud: Color
    let sparkle: Color
    let sparkleAlt: Color
    let track: Color
    let trackFillStart: Color
    let trackFillEnd: Color
    /// App 说明步骤的序号底色
    let accents: [Color]

    var isMono: Bool { kind == .mono }
    var isNight: Bool { kind == .night }

    static let day = Palette(
        kind: .day,
        skyTop: Color(hex: 0xF3F6E4),
        skyBottom: Color(hex: 0xDDE9C2),
        ink: Color(hex: 0x3A4722),
        inkSoft: Color(hex: 0x3A4722).opacity(0.6),
        heroTop: Color(hex: 0xA3C752),
        heroBottom: Color(hex: 0x5E8F2F),
        heroShadow: Color(hex: 0x3F6B1E).opacity(0.25),
        chip: Color(hex: 0xFFFDF4).opacity(0.78),
        chipInk: Color(hex: 0x3A4722),
        cloud: Color.white.opacity(0.85),
        sparkle: Color(hex: 0xF2C94C),
        sparkleAlt: Color(hex: 0x9CC24A),
        track: Color(hex: 0xFFFDF4).opacity(0.75),
        trackFillStart: Color(hex: 0xC3DA7A),
        trackFillEnd: Color(hex: 0x6E9E34),
        accents: [0x9CC24A, 0xE8B84A, 0x6FA37A].map { Color(hex: $0) }
    )

    static let night = Palette(
        kind: .night,
        skyTop: Color(hex: 0x1B2A1F),
        skyBottom: Color(hex: 0x2F4531),
        ink: Color(hex: 0xF1F5E2),
        inkSoft: Color(hex: 0xF1F5E2).opacity(0.66),
        heroTop: Color(hex: 0xEEF7C4),
        heroBottom: Color(hex: 0xAACF5F),
        heroShadow: Color.black.opacity(0.3),
        chip: Color.white.opacity(0.12),
        chipInk: Color(hex: 0xF1F5E2),
        cloud: Color.white.opacity(0.08),
        sparkle: Color(hex: 0xF4E3A0),
        sparkleAlt: Color(hex: 0xB6D66C),
        track: Color.white.opacity(0.15),
        trackFillStart: Color(hex: 0xEEF7C4),
        trackFillEnd: Color(hex: 0xAACF5F),
        accents: [0x8DB64A, 0xD9A93E, 0x5F9670].map { Color(hex: $0) }
    )

    /// 系统接管着色时只保留透明度层次
    static let mono = Palette(
        kind: .mono,
        skyTop: .clear,
        skyBottom: .clear,
        ink: .white,
        inkSoft: .white.opacity(0.7),
        heroTop: .white,
        heroBottom: .white,
        heroShadow: .clear,
        chip: .white.opacity(0.18),
        chipInk: .white,
        cloud: .white.opacity(0.12),
        sparkle: .white.opacity(0.5),
        sparkleAlt: .white.opacity(0.35),
        track: .white.opacity(0.2),
        trackFillStart: .white,
        trackFillEnd: .white,
        accents: Array(repeating: .white, count: 3)
    )

    static func `for`(_ scheme: ColorScheme) -> Palette {
        scheme == .dark ? .night : .day
    }
}

// MARK: - Environment

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.day
}

private struct UpdateAvailableKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }

    /// 更新清单中有更高版本时为 true, 小组件据此显示 "有新版本"
    var updateAvailable: Bool {
        get { self[UpdateAvailableKey.self] }
        set { self[UpdateAvailableKey.self] = newValue }
    }
}

// MARK: - 字体与颜色工具

extension Font {
    static let cuteFontName = "ZCOOLKuaiLe-Regular"

    /// 站酷快乐体, 用于中文文案
    static func cute(_ size: CGFloat) -> Font {
        .custom(cuteFontName, fixedSize: size)
    }

    /// SF Rounded 特粗体, 用于主数字
    static func hero(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
