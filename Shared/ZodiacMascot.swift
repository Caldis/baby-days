import SwiftUI

private struct ZodiacImageKey: EnvironmentKey {
    static let defaultValue: (Zodiac) -> Image = { Image($0.widgetAssetName) }
}

private struct ZodiacOverrideKey: EnvironmentKey {
    static let defaultValue: Zodiac? = nil
}

extension EnvironmentValues {
    /// 离线工具从源图片加载, App 与扩展使用各自打包的小尺寸图片
    var zodiacImageProvider: (Zodiac) -> Image {
        get { self[ZodiacImageKey.self] }
        set { self[ZodiacImageKey.self] = newValue }
    }
    var zodiacOverride: Zodiac? {
        get { self[ZodiacOverrideKey.self] }
        set { self[ZodiacOverrideKey.self] = newValue }
    }
}

/// 无日历生肖, 使用固定占位尺寸, 保留年龄数字的布局空间
struct ZodiacMascot: View {
    let birth: BirthDate
    @Environment(\.palette) private var palette
    @Environment(\.zodiacImageProvider) private var image
    @Environment(\.zodiacOverride) private var override

    var body: some View {
        image(override ?? Zodiac(birth: birth))
            .renderingMode(palette.isMono ? .template : .original)
            .resizable()
            .scaledToFit()
            .foregroundStyle(palette.ink)
            .accentable()
            .accessibilityHidden(true)
    }
}
