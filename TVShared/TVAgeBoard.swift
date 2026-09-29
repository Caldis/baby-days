import SwiftUI

/// Apple TV 上的年龄展示: 全屏页面与顶部栏横幅共用
struct TVAgeBoard: View {
    enum Style {
        /// App 全屏, 1920 × 1080
        case fullScreen
        /// 顶部栏 inset 横幅, 1940 × 692
        case banner
    }

    let age: BabyAge
    let snake: Image
    var style: Style = .fullScreen
    @Environment(\.palette) private var palette

    private var isBanner: Bool { style == .banner }

    var body: some View {
        HStack(spacing: isBanner ? 56 : 90) {
            snake
                .resizable()
                .interpolation(.high)
                .aspectRatio(1, contentMode: .fit)
                .frame(width: isBanner ? 540 : 620)
            VStack(alignment: .leading, spacing: isBanner ? 14 : 26) {
                Text(age.caption)
                    .font(.cute(isBanner ? 40 : 52))
                    .foregroundStyle(palette.inkSoft)
                HeroNumber(age: age, size: isBanner ? 150 : 200)
                HStack(spacing: 14) {
                    Chip(text: age.detail, size: isBanner ? 28 : 34)
                    if !age.isInfant && age.detail != age.totalDaysNote {
                        Chip(text: age.totalDaysNote, size: isBanner ? 28 : 34)
                    }
                }
                if !isBanner {
                    FunFacts(age: age, scale: 2.3)
                        .padding(.top, 20)
                }
                BirthdayProgress(age: age, barHeight: isBanner ? 14 : 18, fontSize: isBanner ? 26 : 30)
                    .padding(.top, isBanner ? 10 : 16)
            }
            .frame(width: isBanner ? 860 : 820, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TVBackground())
    }
}

/// Apple TV 背景: 与小组件相同的渐变天空与装饰
struct TVBackground: View {
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                LinearGradient(colors: [palette.skyTop, palette.skyBottom], startPoint: .top, endPoint: .bottom)
                if palette.isNight {
                    Crescent().fill(palette.sparkle).rotationEffect(.degrees(-20))
                        .frame(width: h * 0.12, height: h * 0.12).position(x: w * 0.9, y: h * 0.16)
                } else {
                    Cloud().fill(palette.cloud).frame(width: h * 0.34, height: h * 0.17).position(x: w * 0.92, y: h * 0.14)
                }
                Cloud().fill(palette.cloud).frame(width: h * 0.3, height: h * 0.15).position(x: w * 0.04, y: h * 0.86)
                Twinkle().fill(palette.sparkle).frame(width: h * 0.05, height: h * 0.05).position(x: w * 0.08, y: h * 0.14)
                Twinkle().fill(palette.sparkleAlt).frame(width: h * 0.03, height: h * 0.03).position(x: w * 0.95, y: h * 0.5)
                Circle().fill(palette.sparkleAlt.opacity(0.8)).frame(width: h * 0.012, height: h * 0.012).position(x: w * 0.5, y: h * 0.08)
            }
        }
    }
}
