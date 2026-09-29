import SwiftUI

/// App Store 截图: iPhone 1284 × 2778 (6.5 英寸栏位), Apple TV 1920 × 1080
enum AppStoreArt {
    @MainActor
    static func render(to output: URL) throws {
        let pages: [(String, String, String, DateComponents, Palette, [WidgetSize])] = [
            ("iphone-1", "一眼看见宝宝多大", "桌面小组件每天 0 点自动更新", Render.scenarios[0].offset, .day, [.medium, .large]),
            ("iphone-2", "满周岁后显示几岁几个月", "还有生日倒计时与趣味换算", Render.scenarios[4].offset, .day, [.small, .large]),
            ("iphone-3", "深色模式下是林间夜空", "小, 中, 大三种尺寸随心摆放", Render.scenarios[0].offset, .night, [.medium, .large]),
        ]
        for (name, title, subtitle, offset, palette, sizes) in pages {
            let page = PhonePage(title: title, subtitle: subtitle, age: Render.age(after: offset), sizes: sizes)
                .environment(\.palette, palette)
            try Render.write(page, scale: 3, to: output.appendingPathComponent("\(name).png"))
        }
        let snake = Image(decorative: PencilSnake.image(
            size: CGSize(width: 512, height: 512), scale: 2, parts: [.snake],
            snakeRect: CGRect(x: 0, y: 0, width: 512, height: 512)
        ), scale: 2)
        let tvPages: [(String, DateComponents, Palette)] = [
            ("tv-1", Render.scenarios[0].offset, .day),
            ("tv-2", Render.scenarios[4].offset, .night),
        ]
        for (name, offset, palette) in tvPages {
            let board = TVAgeBoard(age: Render.age(after: offset), snake: snake)
                .frame(width: 1920, height: 1080)
                .environment(\.palette, palette)
            try Render.write(board, scale: 1, to: output.appendingPathComponent("\(name).png"))
        }
    }

    /// 竖屏背景: 渐变天空与少量装饰
    private struct PhoneBackground: View {
        @Environment(\.palette) private var palette

        var body: some View {
            ZStack {
                LinearGradient(colors: [palette.skyTop, palette.skyBottom], startPoint: .top, endPoint: .bottom)
                if palette.isNight {
                    Crescent().fill(palette.sparkle).rotationEffect(.degrees(-20)).frame(width: 44, height: 44).position(x: 382, y: 56)
                } else {
                    Cloud().fill(palette.cloud).frame(width: 150, height: 75).position(x: 398, y: 60)
                }
                Cloud().fill(palette.cloud).frame(width: 180, height: 90).position(x: 30, y: 884)
                Twinkle().fill(palette.sparkle).frame(width: 26, height: 26).position(x: 36, y: 70)
                Twinkle().fill(palette.sparkleAlt).frame(width: 16, height: 16).position(x: 402, y: 470)
            }
        }
    }

    /// 一页 iPhone 截图: 顶部标题, 下方为小组件
    private struct PhonePage: View {
        let title: String
        let subtitle: String
        let age: BabyAge
        let sizes: [WidgetSize]
        @Environment(\.palette) private var palette

        var body: some View {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    Text(title)
                        .font(.cute(38))
                        .foregroundStyle(palette.ink)
                    Text(subtitle)
                        .font(.cute(19))
                        .foregroundStyle(palette.inkSoft)
                }
                .padding(.top, 96)
                ForEach(Array(sizes.enumerated()), id: \.offset) { _, size in
                    WidgetCard(age: age, size: size)
                        .shadow(color: .black.opacity(palette.isNight ? 0.4 : 0.12), radius: 18, y: 10)
                }
                Spacer(minLength: 0)
            }
            .frame(width: 428, height: 926)
            .background(PhoneBackground())
        }
    }
}
