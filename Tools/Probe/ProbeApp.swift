import SwiftUI

/// Separate bundle ID: installing this test app never replaces BabyDays on the user's devices.
@main
struct BabyDaysSyncProbeApp: App {
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let configuration = CloudSyncProbe.configuration {
                CloudSyncProbeView(configuration: configuration)
                    .onChange(of: phase) { _, value in
                        print("BABYDAYS_PROBE_SCENE \(configuration.device) \(value)")
                    }
            } else {
                Text("仅用于隔离的 iCloud 同步联调").padding(40)
            }
            #else
            Text("此测试工具仅支持 Debug 构建").padding(40)
            #endif
        }
    }
}
