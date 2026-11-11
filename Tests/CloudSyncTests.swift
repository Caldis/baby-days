import Foundation

// Foundation documents UserDefaults as thread-safe, but its Objective-C type lacks Sendable.
private struct DefaultsReference: @unchecked Sendable { let value: UserDefaults }

@MainActor
final class TestCloudStore: NSObject, BabyCloudStore {
    var values: [String: Any] = [:]
    var available = true
    var writes = 0
    var synchronizations = 0
    var notificationObject: AnyObject { self }
    func set(_ data: Data, forKey key: String) { values[key] = data; writes += 1 }
    func synchronize() -> Bool { synchronizations += 1; return available }
    func receive(_ record: BabySyncRecord) throws { values[record.key] = try JSONEncoder().encode(record) }
    func signal(_ reason: Int) {
        NotificationCenter.default.post(name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                        object: self, userInfo: [NSUbiquitousKeyValueStoreChangeReasonKey: reason])
    }
}

@main
struct CloudSyncTests {
    @MainActor
    static func main() async throws {
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            if !condition() { fatalError(message) }
        }
        var suites: [String] = []
        func device() -> UserDefaults {
            let name = "com.caldis.babydays.tests.cloud.\(UUID().uuidString)"
            suites.append(name)
            return UserDefaults(suiteName: name)!
        }
        defer { for suite in suites { UserDefaults.standard.removePersistentDomain(forName: suite) } }
        let birth = BirthDate(year: 2025, month: 1, day: 1)
        let baby = Baby(id: "local", name: "示例宝宝", birth: birth)
        let remoteBaby = Baby(id: "remote", name: "示例宝宝", birth: birth)
        let remoteRecord = BabySyncRecord(baby: remoteBaby, stamp: BabySyncStamp(tick: 100, writer: "remote"))

        // This suite and its transport are synthetic; no real App Group or iCloud account is accessed.
        let local = device()
        var value = BabyCollection(babies: [baby], selectedID: baby.id, iconMode: "pig", iconBabyID: baby.id)
        value = BabyProfile.save(value, to: local)
        let transport = TestCloudStore()
        try transport.receive(remoteRecord)
        var factories = 0
        var imports = 0
        let sync = BabyCloudSync(defaults: local, initialDelay: 0, makeStore: {
            factories += 1
            return transport
        }, onImport: { imports += 1 })
        check(!sync.isEnabled && sync.status == .disabled, "Sync defaults to off")
        sync.refresh()
        check(factories == 0 && transport.synchronizations == 0 && transport.writes == 0,
              "Disabled sync must not create, read, or write an iCloud client")
        check(BabyProfile.load(from: local).babies.count == 1, "Disabled device ignores remote data")
        sync.setEnabled(true)
        var merged = BabyProfile.load(from: local)
        check(merged.babies.count == 2, "Opting in merges local and remote babies without deduplicating twins")
        check(merged.selectedID == baby.id && merged.iconMode == "pig" && merged.iconBabyID == baby.id,
              "Selection and icon preferences stay local")
        check(imports == 1 && transport.writes == 1, "Import refreshes surfaces and uploads only the missing local record")
        let stableData = local.data(forKey: BabyProfile.recordsKey)
        sync.refresh()
        check(imports == 1 && transport.writes == 1 && local.data(forKey: BabyProfile.recordsKey) == stableData,
              "Repeated sync converges without notifications or upload loops")
        merged.babies[0].name = "修改后的称呼"
        merged = BabyProfile.save(merged, to: local)
        let renamed = BabySyncRecord.decode(transport.values["baby.v1.local"] as! Data, key: "baby.v1.local")!
        check(renamed.name.value == "修改后的称呼", "Local edits publish while enabled")
        merged.remove(id: remoteBaby.id)
        merged = BabyProfile.save(merged, to: local)
        let deleted = BabySyncRecord.decode(transport.values[remoteRecord.key] as! Data, key: remoteRecord.key)!
        check(deleted.deleted, "Removal publishes a tombstone rather than erasing the key")
        let beforeDisable = transport.writes
        sync.setEnabled(false)
        merged.babies[0].name = "仅本机编辑"
        _ = BabyProfile.save(merged, to: local)
        sync.refresh()
        check(transport.writes == beforeDisable && factories == 1, "Disabled edits never touch iCloud")
        check(local.data(forKey: BabyProfile.recordsKey) != nil && transport.values[deleted.key] != nil,
              "Disabling preserves both local data and existing cloud copies")
        sync.setEnabled(true)
        check(BabySyncRecord.decode(transport.values["baby.v1.local"] as! Data, key: "baby.v1.local")?.name.value == "仅本机编辑",
              "Opting back in publishes queued local edits")
        var backgroundEdit = BabyProfile.load(from: local)
        backgroundEdit.babies[0].name = "后台修改"
        let backgroundSnapshot = backgroundEdit
        let beforeBackgroundWrite = transport.writes
        let backgroundDefaults = DefaultsReference(value: local)
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                _ = BabyProfile.save(backgroundSnapshot, to: backgroundDefaults.value)
                continuation.resume()
            }
        }
        check(transport.writes == beforeBackgroundWrite + 1, "Background saves notify main-actor sync only after releasing the storage lock")

        // The app and widget have independent clients but share this device's opt-in preference.
        let sharedDevice = device()
        let sharedCloud = TestCloudStore()
        _ = BabyProfile.save(BabyCollection(babies: [baby]), to: sharedDevice)
        let appClient = BabyCloudSync(defaults: sharedDevice, initialDelay: 0, makeStore: { sharedCloud }, onImport: {})
        let widgetClient = BabyCloudSync(defaults: sharedDevice, initialDelay: 0, makeStore: { sharedCloud }, onImport: {})
        appClient.setEnabled(true)
        widgetClient.refresh()
        check(widgetClient.isEnabled, "Extensions follow this device's persisted opt-in")
        appClient.setEnabled(false)
        let requestsBeforeWidgetRefresh = sharedCloud.synchronizations
        widgetClient.refresh()
        check(!widgetClient.isEnabled && sharedCloud.synchronizations == requestsBeforeWidgetRefresh,
              "A widget refresh observes the app's opt-out before contacting iCloud")

        // Two offline devices edit different fields of one stable ID.
        var base = BabySyncState(babies: [baby])
        base.writer = "device-base"
        var first = base
        first.writer = "device-a"
        var named = baby
        named.name = "另一个称呼"
        first.edit(from: base, to: [named], now: Date(timeIntervalSince1970: 10))
        var second = base
        second.writer = "device-b"
        var dated = baby
        dated.birth = BirthDate(year: 2025, month: 1, day: 2) // Synthetic mutation fixture, never a real birthday.
        second.edit(from: base, to: [dated], now: Date(timeIntervalSince1970: 11))
        var left = first
        var right = second
        left.merge(Array(second.records.values))
        right.merge(Array(first.records.values))
        check(left.records == right.records, "Concurrent merges commute")
        check(left.records[baby.id]?.baby.name == named.name && left.records[baby.id]?.baby.birth == dated.birth,
              "Concurrent edits to separate fields are preserved")
        var removal = base
        removal.edit(from: base, to: [], now: Date(timeIntervalSince1970: 9))
        left.merge(Array(removal.records.values))
        left.merge(Array(second.records.values))
        check(left.records[baby.id]?.deleted == true, "Deletion wins over later offline edits and cannot resurrect")
        let deletionData = try JSONEncoder().encode(left.records[baby.id]!)
        let deletionJSON = try JSONSerialization.jsonObject(with: deletionData) as! [String: Any]
        check(deletionJSON["name"] == nil && deletionJSON["birth"] == nil,
              "Tombstones retain identity only, never a deleted baby's name or birthday")
        let decodedDeletion = try JSONDecoder().decode(BabySyncRecord.self, from: deletionData)
        check(decodedDeletion == left.records[baby.id],
              "Redacted tombstones round trip without upload loops")
        let repeated = left.records
        left.merge(Array(left.records.values))
        check(left.records == repeated, "Merge is idempotent")
        var conflictingInitial = BabySyncState(babies: [named])
        var initial = base
        conflictingInitial.merge(Array(base.records.values))
        initial.merge(Array(BabySyncState(babies: [named]).records.values))
        check(conflictingInitial.records == initial.records, "Pre-sync backups with equal initial stamps converge deterministically")

        // A stale editor must not delete newly arrived babies or overwrite unrelated fields.
        let staleStore = device()
        let snapshot = BabyProfile.save(BabyCollection(babies: [baby]), to: staleStore)
        _ = BabyProfile.merge([remoteRecord], from: staleStore)
        var stale = snapshot
        stale.babies[0].name = "编辑中的称呼"
        let saved = BabyProfile.save(stale, to: staleStore)
        check(saved.babies.count == 2 && saved.babies.contains { $0.id == remoteBaby.id },
              "Saving an old sheet preserves concurrent arrivals")
        var remoteChange = snapshot.syncState!.records[baby.id]!
        remoteChange.birth = BabySyncField(value: dated.birth, stamp: BabySyncStamp(tick: Int64.max / 2, writer: "future"))
        _ = BabyProfile.merge([remoteChange], from: staleStore)
        stale.babies[0].name = "继续编辑称呼"
        let updated = BabyProfile.save(stale, to: staleStore, now: Date(timeIntervalSince1970: 1))
        check(updated.babies.first { $0.id == baby.id }?.birth == dated.birth, "Stale saves preserve remote birthday edits")
        check(updated.syncState!.records[baby.id]!.name.stamp.tick > remoteChange.birth.stamp.tick,
              "Logical clocks remain monotonic if the device clock goes backwards")

        // Cloud unavailability never prevents local work or drops pending changes.
        let offlineStore = device()
        var offline = BabyProfile.save(BabyCollection(babies: [baby]), to: offlineStore)
        let offlineCloud = TestCloudStore()
        offlineCloud.available = false
        let offlineSync = BabyCloudSync(defaults: offlineStore, initialDelay: 0, makeStore: { offlineCloud }, onImport: {})
        offlineSync.setEnabled(true)
        offline.babies[0].name = "离线称呼"
        _ = BabyProfile.save(offline, to: offlineStore)
        check(offlineSync.status == .unavailable && offlineCloud.writes == 0, "Unavailable cloud does not consume the local journal")
        offlineCloud.available = true
        offlineSync.refresh()
        check(BabySyncRecord.decode(offlineCloud.values["baby.v1.local"] as! Data, key: "baby.v1.local")?.name.value == "离线称呼",
              "Local edits upload when availability returns")
        let beforeAccountChange = BabyProfile.load(from: offlineStore)
        offlineCloud.signal(NSUbiquitousKeyValueStoreAccountChange)
        check(!offlineSync.isEnabled && offlineSync.status == .accountChanged, "Changing Apple accounts requires a fresh opt-in")
        check(BabyProfile.load(from: offlineStore) == beforeAccountChange, "Account changes retain the local copy")
        check(!offlineStore.bool(forKey: BabyCloudSync.enabledKey), "Account-change opt-out persists")

        let invalidStore = device()
        let invalidCloud = TestCloudStore()
        invalidCloud.values["baby.v1.future"] = Data("unknown future format".utf8)
        let invalidSync = BabyCloudSync(defaults: invalidStore, initialDelay: 0, makeStore: { invalidCloud }, onImport: {})
        invalidSync.setEnabled(true)
        check(invalidSync.status == .unreadableData && invalidCloud.writes == 0, "Invalid or future cloud data is never overwritten")
        let quotaStore = device()
        let quotaCloud = TestCloudStore()
        for index in 0...1000 { quotaCloud.values["reserved.\(index)"] = "reserved" }
        let quotaSync = BabyCloudSync(defaults: quotaStore, initialDelay: 0, makeStore: { quotaCloud }, onImport: {})
        quotaSync.setEnabled(true)
        check(quotaSync.status == .quotaExceeded && quotaCloud.writes == 0, "Quota checks include unowned keys and prevent partial uploads")

        // Legacy widget IDs remain valid, while different devices' singleton IDs cannot collide.
        let legacyA = device()
        let legacyB = device()
        legacyA.set(birth.storageValue, forKey: BabyProfile.birthDateKey)
        legacyB.set(birth.storageValue, forKey: BabyProfile.birthDateKey)
        _ = BabyProfile.load(from: legacyA)
        _ = BabyProfile.load(from: legacyB)
        BabyProfile.prepareForSync(in: legacyA)
        BabyProfile.prepareForSync(in: legacyB)
        let idA = BabyProfile.load(from: legacyA).selected!.id
        let idB = BabyProfile.load(from: legacyB).selected!.id
        check(idA != idB && idA != "legacy-baby" && idB != "legacy-baby", "Pre-sync singleton IDs become unique once per device")
        check(BabyProfile.baby(id: "legacy-baby", from: legacyA)?.id == idA, "Old widget assignments resolve through the device-local alias")
        BabyProfile.prepareForSync(in: legacyA)
        check(BabyProfile.load(from: legacyA).selected?.id == idA, "Legacy normalization never changes the ID twice")
        _ = BabyProfile.merge(Array(BabyProfile.load(from: legacyB).syncState!.records.values), from: legacyA)
        check(BabyProfile.load(from: legacyA).babies.count == 2 && BabyProfile.baby(id: "legacy-baby", from: legacyA)?.id == idA,
              "Merging another legacy device preserves both babies and the local widget's association")

        let delayedStore = device()
        _ = BabyProfile.save(BabyCollection(babies: [baby]), to: delayedStore)
        let delayedCloud = TestCloudStore()
        let delayedSync = BabyCloudSync(defaults: delayedStore, initialDelay: 0.03, makeStore: { delayedCloud }, onImport: {})
        delayedSync.setEnabled(true)
        check(delayedCloud.writes == 0, "First upload waits for the initial cloud download")
        delayedSync.setEnabled(false)
        try await Task.sleep(for: .milliseconds(60))
        check(delayedCloud.writes == 0, "Disabling cancels deferred uploads")
        print("Passed: default-off isolation, opt-in merge, independent preferences, convergence, field conflicts, tombstones, stale editors, offline retry, account changes, malformed data, quotas, legacy widget IDs, cancellation")
    }
}
