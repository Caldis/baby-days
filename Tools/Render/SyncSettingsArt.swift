import AppKit
import SwiftUI

/// Capture the shipping settings section with native controls and an isolated in-memory transport.
@MainActor
enum SyncSettingsArt {
    private final class PreviewStore: NSObject, BabyCloudStore {
        var available = true
        var values: [String: Any] = [:]
        var notificationObject: AnyObject { self }
        func set(_ data: Data, forKey key: String) { values[key] = data }
        func synchronize() -> Bool { available }
    }

    static func render(to output: URL) throws {
        _ = NSApplication.shared
        for scheme in [ColorScheme.light, .dark] {
            for state in ["off", "on", "unavailable", "account-changed"] {
                let suite = "com.caldis.babydays.render.sync.\(UUID().uuidString)"
                let defaults = UserDefaults(suiteName: suite)!
                defer { defaults.removePersistentDomain(forName: suite) }
                let store = PreviewStore()
                store.available = state != "unavailable"
                let sync = BabyCloudSync(defaults: defaults, initialDelay: 0, makeStore: { store }, onImport: {})
                if state != "off" { sync.setEnabled(true) }
                if state == "account-changed" {
                    NotificationCenter.default.post(name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                                    object: store, userInfo: [NSUbiquitousKeyValueStoreChangeReasonKey: NSUbiquitousKeyValueStoreAccountChange])
                }
                let content = VStack(alignment: .leading, spacing: 0) {
                    Text("设置").font(.headline).padding(.horizontal, 20).padding(.top, 20)
                    Form { CloudSyncSettings(sync: sync) }.formStyle(.grouped)
                }
                .frame(width: 460, height: 320)
                .background(scheme == .dark ? Color.black : Color.white)
                .environment(\.colorScheme, scheme)
                let host = NSHostingView(rootView: content)
                host.frame = NSRect(x: 0, y: 0, width: 460, height: 320)
                let window = NSWindow(contentRect: host.frame, styleMask: .borderless, backing: .buffered, defer: false)
                window.contentView = host
                window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                host.layoutSubtreeIfNeeded()
                guard let image = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
                host.cacheDisplay(in: host.bounds, to: image)
                guard let data = image.representation(using: .png, properties: [:]) else { continue }
                try data.write(to: output.appendingPathComponent("sync-\(state)-\(scheme == .dark ? "dark" : "light").png"))
                window.orderOut(nil)
            }
        }
    }
}
