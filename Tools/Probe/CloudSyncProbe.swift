#if DEBUG
import SwiftUI
import Darwin
#if os(iOS) || os(tvOS)
import UIKit
#endif

/// Launch-only real-iCloud integration probe. Excluded entirely from Release builds.
/// Its transport maps every key into a random namespace; production profiles are never loaded.
@MainActor
enum CloudSyncProbe {
    struct Configuration {
        let session: String
        let device: String
        let action: String
        let expected: String
        let seconds: Int
        var prefix: String { "p.\(session.replacingOccurrences(of: "-", with: "").prefix(12))." }
        var suite: String { "com.caldis.babydays.probe.\(session).\(device)" }
    }

    static var configuration: Configuration? {
        let arguments = ProcessInfo.processInfo.arguments
        func option(_ key: String) -> String? {
            guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }
        guard let session = option("--cloud-probe-session"), UUID(uuidString: session) != nil else { return nil }
        let device = option("--cloud-probe-device") ?? "test"
        guard device.count <= 20, device.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }) else { return nil }
        return Configuration(session: session, device: device, action: option("--cloud-probe-action") ?? "observe",
                             expected: option("--cloud-probe-expect") ?? "created",
                             seconds: min(1200, max(10, Int(option("--cloud-probe-seconds") ?? "300") ?? 300)))
    }

    @MainActor
    private final class Store: BabyCloudStore {
        private let store = NSUbiquitousKeyValueStore.default
        private let prefix: String
        init(prefix: String) { self.prefix = prefix }
        var notificationObject: AnyObject { store }
        var values: [String: Any] {
            Dictionary(uniqueKeysWithValues: store.dictionaryRepresentation.compactMap { key, value in
                key.hasPrefix(prefix) ? (String(key.dropFirst(prefix.count)), value) : nil
            })
        }
        func set(_ data: Data, forKey key: String) { store.set(data, forKey: prefix + key) }
        func synchronize() -> Bool { store.synchronize() }
        func removeProbe() {
            for key in store.dictionaryRepresentation.keys where key.hasPrefix(prefix) { store.removeObject(forKey: key) }
            _ = store.synchronize()
        }
    }

    @MainActor
    final class Runner: ObservableObject {
        @Published var message = "正在验证 iCloud 同步"
        private let configuration: Configuration
        private let defaults: UserDefaults
        private lazy var transport = Store(prefix: configuration.prefix)
        private lazy var sync = BabyCloudSync(defaults: defaults, makeStore: { [unowned self] in transport }, onImport: {})

        init(configuration: Configuration) {
            self.configuration = configuration
            defaults = UserDefaults(suiteName: configuration.suite)!
        }

        func run() async {
            #if os(iOS) || os(tvOS)
            UIApplication.shared.isIdleTimerDisabled = true
            defer { UIApplication.shared.isIdleTimerDisabled = false }
            #endif
            let id = "probe-baby"
            let birth = BirthDate(year: 2025, month: 1, day: 1)
            if configuration.action == "cleanup" {
                sync.setEnabled(false)
                transport.removeProbe()
                defaults.removePersistentDomain(forName: configuration.suite)
                emit("cleanup", phase: "removed")
                try? await Task.sleep(for: .seconds(2))
                exit(0)
            }
            if configuration.action == "seed", BabyProfile.baby(id: id, from: defaults) == nil {
                var collection = BabyProfile.load(from: defaults)
                collection.upsert(Baby(id: id, name: "示例宝宝", birth: birth))
                _ = BabyProfile.save(collection, to: defaults)
            }
            if configuration.action == "disabled" { sync.setEnabled(false) }
            else { sync.setEnabled(true) }
            var applied = false
            var previous = ""
            for step in 0...configuration.seconds / 5 {
                guard !Task.isCancelled else { return }
                sync.refresh()
                var collection = BabyProfile.load(from: defaults)
                if !applied, var baby = collection.babies.first(where: { $0.id == id }) {
                    if configuration.action == "rename" {
                        baby.name = "示例宝宝已改名"
                        collection.upsert(baby)
                        collection = BabyProfile.save(collection, to: defaults)
                        applied = true
                    } else if configuration.action == "delete" {
                        collection.remove(id: id)
                        collection = BabyProfile.save(collection, to: defaults)
                        applied = true
                    }
                }
                let baby = collection.babies.first { $0.id == id }
                let phase: String
                if collection.syncState?.records[id]?.deleted == true && baby == nil { phase = "deleted" }
                else if baby?.birth == birth && baby?.name == "示例宝宝已改名" { phase = "renamed" }
                else if baby?.birth == birth && baby?.name == "示例宝宝" { phase = "created" }
                else { phase = "waiting" }
                let state = "\(phase)-\(sync.status)"
                if state != previous || step % 12 == 0 {
                    emit("state", phase: phase)
                    message = "\(configuration.device): \(phase)"
                    previous = state
                }
                if configuration.action == "observe" && phase == configuration.expected {
                    emit("pass", phase: phase)
                    exit(0)
                }
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
            }
            emit("timeout", phase: previous)
            exit(2)
        }

        private func emit(_ event: String, phase: String) {
            let payload: [String: Any] = ["event": event, "phase": phase, "device": configuration.device,
                                          "enabled": sync.isEnabled, "status": String(describing: sync.status)]
            if let data = try? JSONSerialization.data(withJSONObject: payload, options: .sortedKeys),
               let text = String(data: data, encoding: .utf8) {
                print("BABYDAYS_PROBE \(text)")
                fflush(stdout)
            }
        }
    }
}

@MainActor
struct CloudSyncProbeView: View {
    @StateObject private var runner: CloudSyncProbe.Runner
    init(configuration: CloudSyncProbe.Configuration) {
        _runner = StateObject(wrappedValue: CloudSyncProbe.Runner(configuration: configuration))
    }
    var body: some View {
        VStack(spacing: 20) {
            Text("iCloud 同步联调").font(.title)
            Text("仅使用独立的示例数据, 不修改现有宝宝资料")
            Text(runner.message).monospaced()
        }
        .padding(40)
        .task { await runner.run() }
    }
}
#endif
