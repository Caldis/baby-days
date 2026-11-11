import SwiftUI

struct IconSettings: View {
    let collection: BabyCollection
    let onChange: (BabyCollection) -> Void
    @ObservedObject var sync: BabyCloudSync = .shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    private var mode: String {
        ["default", "automatic"].contains(collection.iconMode) ? collection.iconMode : "manual"
    }
    var body: some View {
        NavigationStack {
            Form {
                CloudSyncSettings(sync: sync)
                Section("应用图标") {
                    Picker("图标", selection: Binding(get: { mode }, set: { value in
                        var state = collection
                        state.iconMode = value == "manual" ? collection.iconZodiac.rawValue : value
                        onChange(state)
                    })) {
                        Text("默认").tag("default")
                        Text("跟随宝宝").tag("automatic")
                        Text("自选").tag("manual")
                    }
                    .pickerStyle(.segmented).labelsHidden()
                    .accessibilityIdentifier("icon-mode")
                    if mode == "automatic" {
                        if collection.babies.isEmpty {
                            Text("先添加宝宝").foregroundStyle(.secondary)
                        } else {
                            Picker("宝宝", selection: Binding(get: { collection.iconBabyID ?? "" }, set: { value in
                                var state = collection
                                state.iconBabyID = value.isEmpty ? nil : value
                                onChange(state)
                            })) {
                                Text("当前宝宝").tag("")
                                ForEach(collection.babies) { Text($0.displayName).tag($0.id) }
                            }
                        }
                    }
                    if mode != "manual" {
                        HStack {
                            Spacer()
                            Image("IconPreview-\(collection.iconZodiac.rawValue)")
                                .resizable().scaledToFit().frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 22))
                                .accessibilityLabel("\(collection.iconZodiac.name)图标")
                            Spacer()
                        }.padding(.vertical, 12)
                    }
                }
                if mode == "manual" {
                    Section {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84))], spacing: 16) {
                            ForEach(Zodiac.allCases) { zodiac in
                                let active = collection.iconZodiac == zodiac
                                Button {
                                    var state = collection
                                    state.iconMode = zodiac.rawValue
                                    onChange(state)
                                } label: {
                                    VStack(spacing: 7) {
                                        Image("IconPreview-\(zodiac.rawValue)")
                                            .resizable().scaledToFit().frame(width: 64, height: 64)
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                            .padding(5)
                                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(active ? palette.heroBottom : .clear, lineWidth: 2))
                                        Text(zodiac.name).font(.system(size: 13))
                                    }
                                    .foregroundStyle(palette.ink)
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(zodiac.name)图标")
                                .accessibilityAddTraits(active ? [.isSelected] : [])
                                .accessibilityIdentifier("icon-\(zodiac.rawValue)")
                            }
                        }.padding(.vertical, 8)
                    }
                }
                #if os(macOS)
                Section {
                    Text("程序坞图标随设置切换, Finder 保持默认图标")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                #endif
            }
            .formStyle(.grouped)
            .navigationTitle("设置")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
        .tint(palette.heroBottom)
        #if os(macOS)
        .frame(width: 460, height: 600)
        #endif
    }
}
