import SwiftUI
import WidgetKit

/// 每个宝宝有独立的生日与生肖主题, 主界面可随时切换预览
struct GalleryView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(BabyProfile.recordsKey, store: BabyProfile.defaults) private var records = Data()
    @State private var preview: BabyCollection?
    init(preview: BabyCollection? = nil) { _preview = State(initialValue: preview) }
    @State private var today = Date.now
    @State private var editor: Baby?
    @State private var settings = false
    @State private var widgetHelp = false
    @State private var deleting: Baby?
    @State private var iconError: String?
    private let spacing: CGFloat = 20
    private var collection: BabyCollection { preview ?? BabyProfile.decode(records) ?? BabyProfile.load() }
    private var selected: Baby? { collection.selected }
    private var palette: Palette { Palette.for(colorScheme, zodiac: selected?.zodiac ?? .snake) }
    private func contentWidth(for width: CGFloat) -> CGFloat { min(width, width >= 780 ? 748 : 554) }

    var body: some View {
        GeometryReader { geometry in
            let width = max(0, geometry.size.width - spacing * 2)
            ScrollView {
                VStack(spacing: 28) {
                    toolbar(availableWidth: width)
                    if let baby = selected {
                        header(baby, availableWidth: width)
                        let age = BabyAge(birth: baby.birth, on: today)
                        if width >= 780 { expandedGallery(age) }
                        else if width >= 554 { wideGallery(age) }
                        else { narrowGallery(age, availableWidth: width) }
                        Button { widgetHelp = true } label: {
                            Label("添加小组件", systemImage: "plus.rectangle.on.rectangle")
                        }
                        .buttonStyle(.bordered)
                        .font(.system(size: 14))
                    } else {
                        VStack(spacing: 20) {
                            Image(Zodiac.snake.assetName).resizable().scaledToFit().frame(height: 180)
                            Button("添加宝宝") { editor = Baby(name: "", birth: BirthDate(date: .now)) }
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 40)
                    }
                    #if os(macOS) && !APP_STORE
                    UpdateFooter()
                    #endif
                }
                .foregroundStyle(palette.ink)
                .padding(.horizontal, spacing).padding(.vertical, 28)
                .frame(maxWidth: .infinity)
            }
        }
        .scrollIndicators(.never)
        .background(AppBackground().ignoresSafeArea())
        .tint(palette.heroBottom)
        .environment(\.palette, palette)
        .environment(\.babyName, selected?.displayName ?? "宝宝")
        .sheet(item: $editor) { baby in
            BabyEditor(baby: baby, isExisting: collection.babies.contains { $0.id == baby.id }) { value in
                var state = collection
                state.upsert(value)
                state.selectedID = value.id
                commit(state)
                editor = nil
            } onCancel: { editor = nil }
            .environment(\.palette, palette)
        }
        .sheet(isPresented: $settings) {
            IconSettings(collection: collection, onChange: commit)
                .environment(\.palette, palette)
        }
        .sheet(isPresented: $widgetHelp) {
            WidgetHelpView().environment(\.palette, palette)
        }
        .alert("删除\(deleting?.displayName ?? "宝宝")?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            Button("取消", role: .cancel) { deleting = nil }
            Button("删除", role: .destructive) {
                if let baby = deleting {
                    var state = collection
                    state.remove(id: baby.id)
                    commit(state)
                }
                deleting = nil
            }
        } message: {
            Text(BabyCloudSync.shared.isEnabled
                 ? "删除会同步到其他设备, 此宝宝的小组件需要重新选择宝宝"
                 : "此宝宝的小组件需要重新选择宝宝")
        }
        .alert("图标暂未更换", isPresented: Binding(get: { iconError != nil }, set: { if !$0 { iconError = nil } })) {
            Button("好", role: .cancel) { iconError = nil }
        } message: { Text(iconError ?? "") }
        .onAppear { if preview == nil { _ = BabyProfile.load(); BabyCloudSync.shared.refresh(); applyIcon() } }
        .onChange(of: collection.iconZodiac) { _, _ in applyIcon() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            today = .now
            if preview == nil { BabyCloudSync.shared.refresh() }
            applyIcon()
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onOpenURL { url in
            if url.host == "baby", let id = url.pathComponents.last,
               collection.babies.contains(where: { $0.id == id }) {
                var state = collection; state.selectedID = id; commit(state)
            }
            #if os(macOS) && !APP_STORE
            if url.host == "update" { Updater.shared.checkForUpdates() }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 640, minHeight: 600)
        #endif
    }

    private func toolbar(availableWidth: CGFloat) -> some View {
        HStack {
            Text("宝宝多大").font(.cute(28))
            Spacer()
            Button { settings = true } label: { Label("设置", systemImage: "gearshape") }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .accessibilityIdentifier("settings")
                .accessibilityLabel("设置")
                .help("设置")
        }
        .frame(maxWidth: contentWidth(for: availableWidth))
    }

    private func header(_ baby: Baby, availableWidth: CGFloat) -> some View {
        VStack(spacing: 14) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(collection.babies) { item in
                            let active = item.id == baby.id
                            Button {
                                var state = collection
                                state.selectedID = item.id
                                commit(state)
                            } label: {
                                VStack(spacing: 8) {
                                    Image(item.zodiac.assetName).resizable().scaledToFit()
                                        .frame(width: 64, height: 64).padding(8)
                                        .background(Circle().fill(active ? palette.chip : .clear))
                                        .overlay(Circle().strokeBorder(active ? palette.heroBottom : .clear, lineWidth: 2))
                                    Text(item.displayName)
                                        .font(.system(size: 14, weight: active ? .semibold : .regular))
                                        .lineLimit(1).minimumScaleFactor(0.75)
                                        .frame(width: 84)
                                }
                            }
                            .id(item.id)
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(item.displayName), 属\(item.zodiac.name)")
                            .accessibilityAddTraits(.isButton)
                            .accessibilityValue(active ? "已选择" : "")
                            .accessibilityAddTraits(active ? [.isSelected] : [])
                            .accessibilityIdentifier("baby-\(item.id)")
                        }
                        Button { editor = newBaby } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .medium))
                                .frame(width: 64, height: 64).padding(8)
                                .background(Circle().fill(palette.chip))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("添加宝宝")
                        .accessibilityIdentifier("add-baby")
                    }
                    .padding(.horizontal, 2).padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .onChange(of: selected?.id) { _, id in
                    if let id { proxy.scrollTo(id, anchor: .center) }
                }
            }
            HStack(spacing: 14) {
                Label(baby.birth.displayText, systemImage: "birthday.cake")
                    .font(.system(size: 14)).foregroundStyle(palette.inkSoft)
                Spacer()
                Button { editor = baby } label: { Label("编辑宝宝", systemImage: "pencil") }
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("edit-baby")
                    .accessibilityLabel("编辑宝宝")
                    .help("编辑宝宝")
                Button(role: .destructive) { deleting = baby } label: { Label("删除宝宝", systemImage: "trash") }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.red)
                    .tint(.red)
                    .accessibilityIdentifier("delete-baby")
                    .accessibilityLabel("删除宝宝")
                    .help("删除宝宝")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .frame(maxWidth: contentWidth(for: availableWidth))
    }

    private var newBaby: Baby {
        let names = Set(collection.babies.map(\.displayName))
        var name = "宝宝"
        var number = 2
        while names.contains(name) { name = "宝宝 \(number)"; number += 1 }
        return Baby(name: name, birth: BirthDate(date: .now))
    }

    private func commit(_ state: BabyCollection) {
        if preview != nil { preview = state } else { BabyProfile.save(state) }
        today = .now
        WidgetCenter.shared.reloadAllTimelines()
    }
    private func applyIcon() {
        guard preview == nil else { return }
        IconAppearance.apply(collection.iconZodiac) { error in iconError = error }
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
    private func expandedGallery(_ age: BabyAge) -> some View {
        HStack(alignment: .top, spacing: spacing) {
            VStack(alignment: .leading, spacing: spacing) {
                PreviewItem(age: age, size: .small, scale: 1)
                PreviewItem(age: age, size: .medium, scale: 1)
            }
            PreviewItem(age: age, size: .large, scale: 1)
        }
    }
    private func narrowGallery(_ age: BabyAge, availableWidth: CGFloat) -> some View {
        let scale = min(1, max(availableWidth, 1) / WidgetSize.medium.previewDimensions.width)
        return VStack(alignment: .leading, spacing: spacing) {
            PreviewItem(age: age, size: .small, scale: scale)
            PreviewItem(age: age, size: .medium, scale: scale)
            PreviewItem(age: age, size: .large, scale: scale)
        }
    }
}

/// 按真实比例显示的小组件预览
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
        }
    }
}

private struct WidgetHelpView: View {
    @Environment(\.dismiss) private var dismiss
    private var steps: [String] {
        #if os(macOS)
        ["右键点按桌面, 选择「编辑小组件」", "搜索「宝宝多大」并添加", "右键编辑小组件, 选择宝宝"]
        #else
        ["长按主屏幕, 点按「编辑」", "添加「宝宝多大」小组件", "长按小组件, 点「编辑小组件」选择宝宝"]
        #endif
    }
    var body: some View {
        NavigationStack {
            List(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary)
                    Text(step)
                }.padding(.vertical, 8)
            }
            .navigationTitle("添加小组件")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .presentationDetents([.medium])
        #if os(macOS)
        .frame(width: 440, height: 340)
        #endif
    }
}

#if os(macOS) && !APP_STORE
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
                Twinkle().fill(palette.sparkleAlt).frame(width: 16, height: 16).position(x: w - 90, y: 220)
            }
        }
    }
}

#Preview {
    GalleryView()
}
