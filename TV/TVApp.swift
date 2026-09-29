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

/// 未设置生日时引导设置, 设置后全屏展示年龄
struct TVRootView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(BabyProfile.birthDateKey, store: BabyProfile.defaults) private var birthValue = ""
    @State private var today = Date.now
    @State private var editing = false

    var body: some View {
        let palette = Palette.for(colorScheme)
        Group {
            if let birth = BirthDate(storageValue: birthValue), !editing {
                ZStack(alignment: .bottomTrailing) {
                    TVAgeBoard(age: BabyAge(birth: birth, on: today), snake: Image("Snake"))
                    Button("修改生日") { editing = true }
                        .font(.cute(28))
                        .padding(60)
                }
            } else {
                TVSetupView(initial: BirthDate(storageValue: birthValue)) { birth in
                    birthValue = birth.storageValue
                    editing = false
                    TVTopShelfContentProvider.topShelfContentDidChange()
                } onCancel: {
                    editing = false
                }
            }
        }
        .environment(\.palette, palette)
        .ignoresSafeArea()
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            today = .now
            TVTopShelfContentProvider.topShelfContentDidChange()
        }
    }
}

/// 遥控器友好的生日设置: 年, 月, 日三个选择列表
struct TVSetupView: View {
    let onSave: (BirthDate) -> Void
    let onCancel: () -> Void
    private let hasInitial: Bool
    @State private var year: Int
    @State private var month: Int
    @State private var day: Int
    @Environment(\.palette) private var palette

    init(initial: BirthDate?, onSave: @escaping (BirthDate) -> Void, onCancel: @escaping () -> Void) {
        let start = initial ?? BirthDate(date: .now)
        hasInitial = initial != nil
        _year = State(initialValue: start.year)
        _month = State(initialValue: start.month)
        _day = State(initialValue: start.day)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var today: BirthDate { BirthDate(date: .now) }

    private var daysInMonth: Int {
        let calendar = BabyAge.calendar
        let date = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 31
    }

    /// 年月日组合不晚于今天
    private var selection: BirthDate {
        let candidate = BirthDate(year: year, month: month, day: min(day, daysInMonth))
        return candidate.storageValue > today.storageValue ? today : candidate
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("年", selection: $year) {
                        ForEach((today.year - 18)...today.year, id: \.self) { Text(verbatim: "\($0) 年").tag($0) }
                    }
                    Picker("月", selection: $month) {
                        ForEach(1...12, id: \.self) { Text("\($0) 月").tag($0) }
                    }
                    Picker("日", selection: $day) {
                        ForEach(1...daysInMonth, id: \.self) { Text("\($0) 日").tag($0) }
                    }
                } header: {
                    Text("宝宝的生日: \(selection.displayText)")
                }
                Section {
                    Button("保存") { onSave(selection) }
                    if hasInitial {
                        Button("取消", action: onCancel)
                    }
                }
            }
            .navigationTitle("宝宝多大")
        }
        .background(TVBackground())
    }
}
