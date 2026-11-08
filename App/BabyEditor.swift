import SwiftUI

/// 编辑只有称呼和生日两项, 生肖头像随日期变化, 无需额外设置或解释
struct BabyEditor: View {
    let baby: Baby
    let isExisting: Bool
    let onSave: (Baby) -> Void
    let onCancel: () -> Void
    @State private var name: String
    @State private var date: Date
    @FocusState private var nameFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    init(baby: Baby, isExisting: Bool, onSave: @escaping (Baby) -> Void, onCancel: @escaping () -> Void) {
        self.baby = baby; self.isExisting = isExisting; self.onSave = onSave; self.onCancel = onCancel
        _name = State(initialValue: baby.displayName)
        _date = State(initialValue: baby.birth.date())
    }
    private var zodiac: Zodiac { Zodiac(birth: BirthDate(date: date)) }
    private var palette: Palette { Palette.for(colorScheme, zodiac: zodiac) }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool {
        !trimmedName.isEmpty && (!isExisting || trimmedName != baby.displayName || BirthDate(date: date) != baby.birth)
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Image(zodiac.assetName).resizable().scaledToFit().frame(height: 112)
                    .padding(.top, 16).padding(.bottom, 8)
                    .accessibilityLabel("属\(zodiac.name)")
                Form {
                    HStack {
                        Text("称呼")
                        TextField("名字或昵称", text: $name)
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .focused($nameFocused)
                            .onChange(of: name) { _, value in name = String(value.prefix(20)) }
                            .onSubmit(save)
                            .accessibilityLabel("称呼")
                            .accessibilityIdentifier("baby-name")
                    }
                    DatePicker("生日", selection: $date,
                               in: BirthDate(year: 1900, month: 1, day: 1).date()...Date.now,
                               displayedComponents: .date)
                        .environment(\.calendar, BabyAge.calendar)
                        .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
                        #if os(macOS)
                        .datePickerStyle(.stepperField)
                        #else
                        .datePickerStyle(.compact)
                        #endif
                        .accessibilityIdentifier("baby-birthday")
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
            }
            .background(palette.skyTop)
            .navigationTitle(isExisting ? "宝宝资料" : "添加宝宝")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消", action: onCancel) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isExisting ? "完成" : "添加", action: save).disabled(!canSave)
                }
            }
        }
        .tint(palette.heroBottom)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #if os(macOS)
        .frame(width: 420, height: 360)
        #endif
    }
    private func save() {
        guard canSave else { return }
        var value = baby
        value.name = trimmedName
        value.birth = BirthDate(date: date)
        onSave(value)
    }
}
