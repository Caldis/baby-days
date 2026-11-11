import Foundation
import Combine
#if canImport(WidgetKit)
import WidgetKit
#endif
#if os(tvOS)
import TVServices
#endif

@MainActor
protocol BabyCloudStore: AnyObject {
    var values: [String: Any] { get }
    var notificationObject: AnyObject { get }
    func set(_ data: Data, forKey key: String)
    func synchronize() -> Bool
}

/// Created only after this device opts in. The singleton never touches iCloud while disabled.
@MainActor
private final class UbiquitousBabyStore: BabyCloudStore {
    private let store = NSUbiquitousKeyValueStore.default
    var values: [String: Any] { store.dictionaryRepresentation }
    var notificationObject: AnyObject { store }
    func set(_ data: Data, forKey key: String) { store.set(data, forKey: key) }
    func synchronize() -> Bool { store.synchronize() }
}

@MainActor
final class BabyCloudSync: ObservableObject {
    enum Status: Equatable {
        case disabled, enabled, unavailable, quotaExceeded, unreadableData, accountChanged
    }

    static let enabledKey = "iCloudSync.enabled.v1"
    private static let noticeKey = "iCloudSync.notice.v1"
    static let shared = BabyCloudSync()

    @Published private(set) var isEnabled: Bool
    @Published private(set) var status: Status
    private let defaults: UserDefaults
    private let makeStore: @MainActor () -> BabyCloudStore
    private let onImport: @MainActor () -> Void
    private let initialDelay: TimeInterval
    private var cloud: BabyCloudStore?
    private var cloudObserver: NSObjectProtocol?
    private var profileObserver: NSObjectProtocol?
    private var deferredUpload: Task<Void, Never>?
    private var uploadAfter = Date.distantPast
    private var refreshing = false

    init(defaults: UserDefaults = BabyProfile.defaults,
         initialDelay: TimeInterval = 1.5,
         makeStore: @escaping @MainActor () -> BabyCloudStore = { UbiquitousBabyStore() },
         onImport: @escaping @MainActor () -> Void = { BabyCloudSync.refreshSurfaces() }) {
        self.defaults = defaults
        self.initialDelay = initialDelay
        self.makeStore = makeStore
        self.onImport = onImport
        let enabled = defaults.bool(forKey: Self.enabledKey)
        isEnabled = enabled
        status = enabled ? .enabled : defaults.string(forKey: Self.noticeKey) == "accountChanged" ? .accountChanged : .disabled
    }

    /// Also called by widgets and Top Shelf, so they can import iCloud's cached arrivals without opening the App.
    func refresh() {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        if profileObserver == nil {
            profileObserver = NotificationCenter.default.addObserver(forName: BabyProfile.didChange, object: defaults, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
        // Another App Group process may have just switched sync off.
        defaults.synchronize()
        isEnabled = defaults.bool(forKey: Self.enabledKey)
        guard isEnabled else {
            disconnect()
            status = defaults.string(forKey: Self.noticeKey) == "accountChanged" ? .accountChanged : .disabled
            return
        }
        BabyProfile.prepareForSync(in: defaults)
        if cloud == nil {
            let store = makeStore()
            cloud = store
            cloudObserver = NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store.notificationObject, queue: .main) { [weak self] notification in
                MainActor.assumeIsolated {
                    self?.externalChange(reason: notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int)
                }
            }
            deferUploads()
        }
        guard let cloud else { return }
        let available = cloud.synchronize()
        let values = cloud.values
        var incoming: [BabySyncRecord] = []
        var unreadable = false
        for (key, value) in values where key.hasPrefix(BabySyncRecord.keyPrefix) {
            if let data = value as? Data, let record = BabySyncRecord.decode(data, key: key) { incoming.append(record) }
            else { unreadable = true }
        }
        let before = BabyProfile.load(from: defaults)
        let merged = BabyProfile.merge(incoming, from: defaults)
        if before.babies != merged.babies { onImport() }
        // Preserve unknown/future records instead of overwriting them with an older format.
        guard !unreadable else { status = .unreadableData; return }
        guard available else { status = .unavailable; return }
        status = .enabled
        guard Date.now >= uploadAfter else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        var proposed = values
        var changes: [String: Data] = [:]
        let remote = Dictionary(incoming.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for record in merged.syncState?.records.values ?? Dictionary<String, BabySyncRecord>().values {
            guard remote[record.id] != record, let data = try? encoder.encode(record) else { continue }
            proposed[record.key] = data
            changes[record.key] = data
        }
        // Leave headroom below KVS's 1 MB / 1024-key limits, including keys this version doesn't own.
        guard proposed.count <= 1000,
              let bytes = try? PropertyListSerialization.data(fromPropertyList: proposed, format: .binary, options: 0),
              bytes.count < 900_000 else { status = .quotaExceeded; return }
        for (key, data) in changes { cloud.set(data, forKey: key) }
        if !changes.isEmpty && !cloud.synchronize() { status = .unavailable }
    }

    func setEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Self.enabledKey)
        defaults.removeObject(forKey: Self.noticeKey)
        defaults.synchronize()
        isEnabled = enabled
        if !enabled { disconnect(); status = .disabled }
        else { refresh() }
    }

    private func externalChange(reason: Int?) {
        guard defaults.bool(forKey: Self.enabledKey) else { return }
        if reason == NSUbiquitousKeyValueStoreAccountChange {
            // Keep this device's copy, but require a fresh opt-in before copying it into another account.
            defaults.set(false, forKey: Self.enabledKey)
            defaults.set("accountChanged", forKey: Self.noticeKey)
            defaults.synchronize()
            isEnabled = false
            disconnect()
            status = .accountChanged
        } else if reason == NSUbiquitousKeyValueStoreQuotaViolationChange {
            status = .quotaExceeded
        } else {
            if reason == NSUbiquitousKeyValueStoreInitialSyncChange { deferUploads() }
            refresh()
        }
    }

    private func deferUploads() {
        uploadAfter = Date.now.addingTimeInterval(initialDelay)
        deferredUpload?.cancel()
        guard initialDelay > 0 else { return }
        deferredUpload = Task { [weak self, initialDelay] in
            try? await Task.sleep(for: .seconds(initialDelay))
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    private func disconnect() {
        deferredUpload?.cancel()
        deferredUpload = nil
        if let cloudObserver { NotificationCenter.default.removeObserver(cloudObserver) }
        cloudObserver = nil
        cloud = nil
    }

    private static func refreshSurfaces() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
        #if os(tvOS)
        TVTopShelfContentProvider.topShelfContentDidChange()
        #endif
    }

    deinit {
        deferredUpload?.cancel()
        if let cloudObserver { NotificationCenter.default.removeObserver(cloudObserver) }
        if let profileObserver { NotificationCenter.default.removeObserver(profileObserver) }
    }
}
