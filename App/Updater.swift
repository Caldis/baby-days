#if os(macOS)
import AppKit
#if !APP_STORE
import Sparkle
#endif
import SwiftUI
import WidgetKit

#if !APP_STORE
/// Sparkle 自动更新: 启动时后台检查, 发现新版本后静默下载, 退出 App 时安装; Mac App Store 版本由 App Store 负责更新, 不编译此部分
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    @Published private(set) var canCheckForUpdates = false
    private let controller: SPUStandardUpdaterController

    private init() {
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        controller.updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
    }

    /// 弹出更新窗口, 用于菜单, 按钮与小组件的更新提示
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }

    func checkInBackground() {
        controller.updater.checkForUpdatesInBackground()
    }

    var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "-"
        let build = info?["CFBundleVersion"] as? String ?? "-"
        return "版本 \(version) (\(build))"
    }
}

#endif

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 更新安装后首次启动时刷新小组件, 清掉旧时间线中的 "有新版本" 提示
        WidgetCenter.shared.reloadAllTimelines()
        #if !APP_STORE
        Updater.shared.checkInBackground()
        #endif
    }

    /// 关闭窗口即退出, 已下载的更新在退出时安装
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

#if !APP_STORE
/// 菜单栏中的 "检查更新…"
struct CheckForUpdatesCommand: View {
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        Button("检查更新…") { updater.checkForUpdates() }
            .disabled(!updater.canCheckForUpdates)
    }
}
#endif
#endif
