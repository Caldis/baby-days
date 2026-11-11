import SwiftUI

struct TVIconSettings: View {
    let collection: BabyCollection
    let onChange: (BabyCollection) -> Void
    @ObservedObject var sync: BabyCloudSync = .shared
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                CloudSyncSettings(sync: sync)
                Section("应用图标") {
                    Picker("选择方式", selection: Binding(get: { collection.iconMode }, set: { mode in
                        var state = collection; state.iconMode = mode; onChange(state)
                    })) {
                        Text("默认 · 蛇").tag("default")
                        Text("跟随宝宝生肖").tag("automatic")
                        ForEach(Zodiac.allCases) { Text("\($0.name) · \($0.themeName)").tag($0.rawValue) }
                    }
                    if collection.iconMode == "automatic" {
                        Picker("跟随哪位宝宝", selection: Binding(get: { collection.iconBabyID ?? "" }, set: { id in
                            var state = collection; state.iconBabyID = id.isEmpty ? nil : id; onChange(state)
                        })) {
                            Text("当前选中的宝宝").tag("")
                            ForEach(collection.babies) { Text($0.displayName).tag($0.id) }
                        }
                    }
                    Button("完成") { dismiss() }
                }
            }.navigationTitle("设置")
        }
    }
}
