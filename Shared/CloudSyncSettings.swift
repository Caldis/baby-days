import SwiftUI

struct CloudSyncSettings: View {
    @ObservedObject var sync: BabyCloudSync

    var body: some View {
        Section {
            Toggle("iCloud 同步", isOn: Binding(get: { sync.isEnabled }, set: { sync.setEnabled($0) }))
                .accessibilityIdentifier("icloud-sync")
            if let problem {
                Label(problem, systemImage: "exclamationmark.icloud")
                    .foregroundStyle(detailColor)
                    .accessibilityIdentifier("icloud-sync-status")
                if sync.isEnabled {
                    Button("重试") { sync.refresh() }
                        .accessibilityIdentifier("icloud-sync-retry")
                }
            }
        } header: {
            Text("宝宝资料")
        } footer: {
            Text("在同一 Apple 账户的设备间同步称呼与生日, 每台设备需分别开启. 关闭后保留本机资料和 iCloud 副本")
                .foregroundStyle(detailColor)
        }
        .onAppear { sync.refresh() }
    }

    private var detailColor: Color {
        #if os(tvOS)
        .white.opacity(0.85)
        #else
        .secondary
        #endif
    }

    private var problem: String? {
        switch sync.status {
        case .disabled, .enabled: nil
        case .unavailable: "iCloud 暂时不可用, 本机资料已保留"
        case .quotaExceeded: "资料超出 iCloud 同步限额, 本机仍可使用"
        case .unreadableData: "部分云端资料无法读取, 请确认各设备均已更新"
        case .accountChanged: "Apple 账户已更换, 重新开启后继续同步"
        }
    }
}
