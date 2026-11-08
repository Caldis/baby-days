import SwiftUI
import TVServices

@main
struct TVApp: App {
    var body: some Scene {
        WindowGroup {
            TVRootView()
        }
    }
}

/// Apple TV 使用同一份多宝宝列表, 顶部栏显示当前选择的宝宝
struct TVRootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(BabyProfile.recordsKey, store: BabyProfile.defaults) private var records = Data()
    @State private var today = Date.now
    @State private var editing = false
    @State private var adding = false
    @State private var iconSettings = false
    @State private var iconError: String?
    @State private var deleting = false
    @FocusState private var focusedAction: TVAction?
    private enum TVAction { case edit, add, icon, delete }
    private var collection: BabyCollection { BabyProfile.decode(records) ?? BabyProfile.load() }

    var body: some View {
        let baby = collection.selected
        let palette = Palette.for(colorScheme, zodiac: baby?.zodiac ?? .snake)
        Group {
            if let baby, !editing {
                ZStack(alignment: .bottom) {
                    TVAgeBoard(age: BabyAge(birth: baby.birth, on: today), snake: Image(baby.zodiac.assetName))
                        .environment(\.babyName, baby.displayName)
                    HStack(spacing: 24) {
                        Picker("宝宝", selection: Binding(get: { baby.id }, set: { id in
                            var state = collection; state.selectedID = id; save(state)
                        })) {
                            ForEach(collection.babies) { Text($0.displayName).tag($0.id) }
                        }.frame(width: 340)
                        action(.edit, title: "编辑", symbol: "pencil", palette: palette) { adding = false; editing = true }
                        action(.add, title: "添加", symbol: "plus", palette: palette) { adding = true; editing = true }
                        action(.icon, title: "图标", symbol: "app.badge", palette: palette) { iconSettings = true }
                        action(.delete, title: "删除", symbol: "trash", palette: palette) { deleting = true }
                    }.font(.system(size: 24, weight: .medium)).padding(40)
                }
            } else {
                TVSetupView(initial: adding ? nil : baby?.birth, initialName: adding ? "" : baby?.displayName ?? "", canCancel: !collection.babies.isEmpty) { birth, name in
                    var state = collection
                    var value = adding ? Baby(name: name, birth: birth) : (baby ?? Baby(name: name, birth: birth))
                    value.birth = birth; value.name = String(name.prefix(20))
                    state.upsert(value); state.selectedID = value.id
                    save(state); editing = false; adding = false
                } onCancel: { editing = false; adding = false }
            }
        }
        .environment(\.palette, palette).tint(palette.heroBottom).ignoresSafeArea()
        .sheet(isPresented: $iconSettings) {
            TVIconSettings(collection: collection, onChange: save)
        }
        .alert("删除\(baby?.displayName ?? "宝宝")?", isPresented: $deleting) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) {
                if let baby {
                    var state = collection
                    state.remove(id: baby.id)
                    save(state)
                }
            }
        }
        .alert("图标暂未更换", isPresented: Binding(get: { iconError != nil }, set: { if !$0 { iconError = nil } })) {
            Button("好", role: .cancel) { iconError = nil }
        } message: { Text(iconError ?? "") }
        .onAppear { _ = BabyProfile.load(); applyIcon() }
        .onChange(of: collection.iconZodiac) { _, _ in applyIcon() }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            today = .now
            applyIcon()
            TVTopShelfContentProvider.topShelfContentDidChange()
        }
    }
    private func action(_ kind: TVAction, title: String, symbol: String, palette: Palette,
                        perform: @escaping () -> Void) -> some View {
        let focused = focusedAction == kind
        return Button(action: perform) {
            Label(title, systemImage: symbol)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(focused ? Color.black : kind == .delete ? Color.red : palette.ink)
                .padding(.horizontal, 24)
                .frame(height: 64)
                .background(Capsule().fill(focused ? Color.white : palette.chip))
        }
        .buttonStyle(.plain)
        .focused($focusedAction, equals: kind)
        .scaleEffect(focused ? 1.06 : 1)
        .accessibilityLabel(kind == .icon ? "应用图标" : "\(title)宝宝")
    }
    private func applyIcon() { IconAppearance.apply(collection.iconZodiac) { iconError = $0 } }
    private func save(_ state: BabyCollection) {
        BabyProfile.save(state)
        TVTopShelfContentProvider.topShelfContentDidChange()
    }
}

/// 遥控器友好的生日设置: 年, 月, 日三个选择列表
struct TVSetupView: View {
    let onSave: (BirthDate, String) -> Void
    let onCancel: () -> Void
    private let canCancel: Bool
    @State private var name: String
    @State private var year: Int
    @State private var month: Int
    @State private var day: Int
    @Environment(\.palette) private var palette

    init(initial: BirthDate?, initialName: String, canCancel: Bool, onSave: @escaping (BirthDate, String) -> Void, onCancel: @escaping () -> Void) {
        let start = initial ?? BirthDate(date: .now)
        _name = State(initialValue: initialName)
        self.canCancel = canCancel
        _year = State(initialValue: start.year)
        _month = State(initialValue: start.month)
        _day = State(initialValue: start.day)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var today: BirthDate { BirthDate(date: .now) }
    private var lastMonth: Int { year == today.year ? today.month : 12 }
    private var lastDay: Int {
        year == today.year && month == today.month ? min(daysInMonth, today.day) : daysInMonth
    }

    private var daysInMonth: Int {
        let calendar = BabyAge.calendar
        let date = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 31
    }

    /// 年月日组合不晚于今天
    private var selection: BirthDate {
        BirthDate(year: year, month: month, day: day)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("称呼", text: $name)
                        .onChange(of: name) { _, value in name = String(value.prefix(20)) }
                }
                Section("生日") {
                    Picker("年", selection: $year) {
                        ForEach(1900...today.year, id: \.self) { Text(verbatim: "\($0) 年").tag($0) }
                    }
                    Picker("月", selection: $month) {
                        ForEach(1...lastMonth, id: \.self) { Text("\($0) 月").tag($0) }
                    }
                    Picker("日", selection: $day) {
                        ForEach(1...lastDay, id: \.self) { Text("\($0) 日").tag($0) }
                    }
                }
                Section {
                    Button("完成") { onSave(selection, name.trimmingCharacters(in: .whitespacesAndNewlines)) }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if canCancel {
                        Button("取消", action: onCancel)
                    }
                }
            }
            .navigationTitle("宝宝资料")
            .onChange(of: year) { _, _ in
                month = min(month, lastMonth)
                day = min(day, lastDay)
            }
            .onChange(of: month) { _, _ in day = min(day, lastDay) }
        }
        .background(TVBackground())
    }
}
