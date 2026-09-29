import SwiftUI
import WidgetKit

/// App 主界面: 未设置生日时引导设置, 设置后展示三种尺寸的小组件效果与添加方法
struct GalleryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(BabyProfile.birthDateKey, store: BabyProfile.defaults) private var birthValue = ""
    @State private var today = Date.now
    @State private var width: CGFloat = 0
    @State private var editingBirthday = false

    private let spacing: CGFloat = 20
    private let wideLayoutWidth: CGFloat = 170 + 364 + 20

    var body: some View {
        let palette = Palette.for(colorScheme)
        ScrollView {
            VStack(spacing: 32) {
                if let birth = BirthDate(storageValue: birthValue) {
                    let age = BabyAge(birth: birth, on: today)
                    header(age)
                    if width >= wideLayoutWidth {
                        wideGallery(age)
                    } else {
                        narrowGallery(age)
                    }
                    GuideCard()
                } else {
                    welcome
                }
                #if os(macOS)
                UpdateFooter()
                #endif
            }
            .padding(.horizontal, spacing)
            .padding(.vertical, 36)
            .frame(maxWidth: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width - spacing * 2 } action: { width = $0 }
        }
        .scrollIndicators(.never)
        .background(AppBackground().ignoresSafeArea())
        .environment(\.palette, palette)
        .sheet(isPresented: $editingBirthday) {
            BirthdayForm(
                title: "修改宝宝的生日",
                actionTitle: "保存",
                initial: BirthDate(storageValue: birthValue)?.date() ?? .now,
                onSave: { save($0); editingBirthday = false },
                onCancel: { editingBirthday = false }
            )
            .environment(\.palette, palette)
            .presentationBackground(palette.skyTop)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            today = .now
            WidgetCenter.shared.reloadAllTimelines()
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 600)
        .onOpenURL { url in
            // 小组件在有新版本时跳转 babydays://update
            if url.host == "update" { Updater.shared.checkForUpdates() }
        }
        #endif
    }

    private var title: some View {
        let palette = Palette.for(colorScheme)
        return HStack(spacing: 12) {
            Twinkle().fill(palette.sparkle).frame(width: 24, height: 24)
            Text("宝宝多大")
                .font(.cute(36))
                .foregroundStyle(palette.ink)
            Twinkle().fill(palette.sparkleAlt).frame(width: 16, height: 16)
        }
    }

    private var welcome: some View {
        let palette = Palette.for(colorScheme)
        return VStack(spacing: 24) {
            VStack(spacing: 12) {
                title
                Text("设置宝宝的生日, 桌面小组件每天告诉你宝宝多大啦")
                    .font(.cute(14))
                    .foregroundStyle(palette.inkSoft)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)
            BirthdayForm(title: "宝宝的生日", actionTitle: "开始", initial: .now, onSave: save)
        }
    }

    private func header(_ age: BabyAge) -> some View {
        let palette = Palette.for(colorScheme)
        return VStack(spacing: 12) {
            title
            HStack(spacing: 10) {
                Text("\(age.birthDateText) 出生 · 每天醒来都长大一点点")
                    .font(.cute(14))
                    .foregroundStyle(palette.inkSoft)
                Button {
                    editingBirthday = true
                } label: {
                    Label("修改生日", systemImage: "pencil")
                        .font(.cute(12))
                        .foregroundStyle(palette.chipInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(palette.chip))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 24)
    }

    private func save(_ date: Date) {
        birthValue = BirthDate(date: date).storageValue
        today = .now
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func wideGallery(_ age: BabyAge) -> some View {
        VStack(spacing: spacing) {
            HStack(alignment: .top, spacing: spacing) {
                PreviewItem(age: age, size: .small, scale: 1)
                PreviewItem(age: age, size: .medium, scale: 1)
            }
            PreviewItem(age: age, size: .large, scale: 1)
        }
    }

    private func narrowGallery(_ age: BabyAge) -> some View {
        let scale = min(1, max(width, 1) / WidgetSize.medium.previewDimensions.width)
        return VStack(alignment: .leading, spacing: spacing) {
            PreviewItem(age: age, size: .small, scale: scale)
            PreviewItem(age: age, size: .medium, scale: scale)
            PreviewItem(age: age, size: .large, scale: scale)
        }
    }
}

/// 带尺寸标签的小组件预览
private struct PreviewItem: View {
    let age: BabyAge
    let size: WidgetSize
    let scale: CGFloat
    @Environment(\.palette) private var palette

    var body: some View {
        let dimensions = size.previewDimensions
        VStack(alignment: .leading, spacing: 8) {
            WidgetCard(age: age, size: size)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: dimensions.width * scale, height: dimensions.height * scale, alignment: .topLeading)
                .shadow(color: palette.isNight ? .black.opacity(0.35) : Color(hex: 0x9C7BB0).opacity(0.25), radius: 16, y: 8)
            Text("\(size.title)号")
                .font(.cute(13))
                .foregroundStyle(palette.inkSoft)
                .padding(.leading, 6)
        }
    }
}

/// 生日选择卡片, 用于首次设置与修改
private struct BirthdayForm: View {
    let title: String
    let actionTitle: String
    let onSave: (Date) -> Void
    var onCancel: (() -> Void)?
    @State private var date: Date
    @Environment(\.palette) private var palette

    init(title: String, actionTitle: String, initial: Date, onSave: @escaping (Date) -> Void, onCancel: (() -> Void)? = nil) {
        self.title = title
        self.actionTitle = actionTitle
        self.onSave = onSave
        self.onCancel = onCancel
        _date = State(initialValue: initial)
    }

    var body: some View {
        VStack(spacing: 18) {
            Text(title)
                .font(.cute(20))
                .foregroundStyle(palette.ink)
            #if os(macOS)
            // macOS 的日历无法快速跳转年月, 上方的日期输入框用于直接输入
            DatePicker("宝宝的生日", selection: $date, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.stepperField)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
                .environment(\.calendar, BabyAge.calendar)
            #endif
            DatePicker("宝宝的生日", selection: $date, in: ...Date.now, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(palette.heroBottom)
                .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
                .environment(\.calendar, BabyAge.calendar)
                .frame(maxWidth: 340)
            HStack(spacing: 12) {
                if let onCancel {
                    Button(action: onCancel) {
                        Text("取消")
                            .font(.cute(15))
                            .foregroundStyle(palette.chipInk)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 9)
                            .background(Capsule().fill(palette.chip))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    onSave(date)
                } label: {
                    Text(actionTitle)
                        .font(.cute(15))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 9)
                        .background(
                            Capsule().fill(
                                LinearGradient(colors: [palette.heroTop, palette.heroBottom], startPoint: .top, endPoint: .bottom)
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(maxWidth: 420)
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(palette.chip))
    }
}

/// 添加小组件的操作说明
private struct GuideCard: View {
    @Environment(\.palette) private var palette

    private var steps: [String] {
        #if os(macOS)
        ["右键点按桌面空白处, 选择「编辑小组件」", "在小组件库中搜索「宝宝多大」", "选择喜欢的尺寸, 拖到桌面上"]
        #else
        ["长按主屏幕空白处, 进入编辑状态", "点击左上角「编辑」, 选择「添加小组件」", "搜索「宝宝多大」, 选择喜欢的尺寸"]
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(palette.sparkle)
                Text("放到桌面上")
                    .font(.cute(18))
                    .foregroundStyle(palette.ink)
            }
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(palette.accents[index]))
                    Text(step)
                        .font(.cute(14))
                        .foregroundStyle(palette.ink)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: 520, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(palette.chip))
    }
}

#if os(macOS)
/// 版本号与手动检查更新
private struct UpdateFooter: View {
    @ObservedObject private var updater = Updater.shared
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 12) {
            Text(updater.versionText)
                .font(.cute(12))
                .foregroundStyle(palette.inkSoft)
            Button {
                updater.checkForUpdates()
            } label: {
                Text("检查更新")
                    .font(.cute(12))
                    .foregroundStyle(palette.chipInk)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(palette.chip))
            }
            .buttonStyle(.plain)
            .disabled(!updater.canCheckForUpdates)
        }
    }
}
#endif

/// 全屏渐变背景与零星装饰
private struct AppBackground: View {
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            LinearGradient(colors: [palette.skyTop, palette.skyBottom], startPoint: .top, endPoint: .bottom)
            GeometryReader { geo in
                let w = geo.size.width
                Cloud().fill(palette.cloud).frame(width: 180, height: 90).position(x: w - 40, y: 120)
                Cloud().fill(palette.cloud).frame(width: 140, height: 70).position(x: 20, y: 250)
                Twinkle().fill(palette.sparkle).frame(width: 26, height: 26).position(x: 60, y: 110)
                Twinkle().fill(palette.sparkleAlt).frame(width: 16, height: 16).position(x: w - 90, y: 220)
            }
        }
    }
}

#Preview {
    GalleryView()
}
