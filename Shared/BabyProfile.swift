import Foundation
import Darwin

/// 宝宝的出生日期, 只保存公历年月日, 与时区无关
struct BirthDate: Equatable, Codable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar = BabyAge.calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// 解析 "2025-01-01" 形式的存储值
    init?(storageValue: String) {
        let tokens = storageValue.split(separator: "-", omittingEmptySubsequences: false)
        let parts = tokens.compactMap { Int($0) }
        guard tokens.count == 3, parts.count == 3 else { return nil }
        let y = parts[0], m = parts[1], d = parts[2]
        guard (1900...9999).contains(y), (1...12).contains(m), (1...31).contains(d),
              let date = BabyAge.calendar.date(from: DateComponents(year: y, month: m, day: d)) else { return nil }
        let check = BabyAge.calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == y, check.month == m, check.day == d else { return nil }
        self.init(year: y, month: m, day: d)
    }

    var storageValue: String { String(format: "%04d-%02d-%02d", year, month, day) }

    /// 界面显示用, 例如 "2025.01.01"
    var displayText: String { String(format: "%04d.%02d.%02d", year, month, day) }

    func date(calendar: Calendar = BabyAge.calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// 未设置生日时用于小组件库预览的示例: 出生 312 天
    static func sample(today: Date = .now, calendar: Calendar = BabyAge.calendar) -> BirthDate {
        BirthDate(date: calendar.date(byAdding: .day, value: -312, to: calendar.startOfDay(for: today))!, calendar: calendar)
    }
}

struct Baby: Identifiable, Codable, Equatable, Sendable {
    var id: String = UUID().uuidString
    var name: String
    var birth: BirthDate
    var revision: String?
    var zodiac: Zodiac { Zodiac(birth: birth) }
    var displayName: String { name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "宝宝" : name }
}

struct BabyCollection: Codable, Equatable, Sendable {
    var babies: [Baby] = []
    var selectedID: String?
    var iconMode: String = "default"
    var iconBabyID: String?
    var syncState: BabySyncState?
    // Device-local alias for widgets created before iCloud gave the old singleton a unique ID.
    var legacySyncID: String?
    var selected: Baby? { babies.first { $0.id == selectedID } ?? babies.first }
    var iconZodiac: Zodiac {
        if iconMode == "automatic" {
            return (babies.first { $0.id == iconBabyID } ?? selected)?.zodiac ?? .snake
        }
        return Zodiac(rawValue: iconMode) ?? .snake
    }
    mutating func upsert(_ baby: Baby) {
        var baby = baby
        baby.revision = UUID().uuidString
        if let index = babies.firstIndex(where: { $0.id == baby.id }) { babies[index] = baby }
        else { babies.append(baby) }
        if selectedID == nil { selectedID = baby.id }
    }
    mutating func remove(id: String) {
        babies.removeAll { $0.id == id }
        if selectedID == id { selectedID = babies.first?.id }
        if iconBabyID == id { iconBabyID = nil }
    }
}

/// App Group 中原子保存整份列表, 稳定 ID 让每个小组件独立关联宝宝
// Legacy key is read once for migration; never log user birthdays

enum BabyProfile {
    static let birthDateKey = "birthDate"
    static let recordsKey = "babyCollection.v1"
    static let didChange = Notification.Name("BabyDaysProfileDidChange")
    static var appGroup: String? { Bundle.main.object(forInfoDictionaryKey: "BabyDaysAppGroup") as? String }
    // AppStorage 必须观察保存时使用的同一个实例, 否则同进程的修改不会触发界面刷新
    static let defaults: UserDefaults = appGroup.flatMap(UserDefaults.init(suiteName:)) ?? .standard

    static func decode(_ data: Data) -> BabyCollection? {
        guard let value = try? JSONDecoder().decode(BabyCollection.self, from: data),
              Set(value.babies.map(\.id)).count == value.babies.count,
              value.babies.allSatisfy({ BirthDate(storageValue: $0.birth.storageValue) != nil }) else { return nil }
        return value
    }
    static func load(from store: UserDefaults = defaults) -> BabyCollection {
        ProfileTransaction.withStore(store) {
            if let data = store.data(forKey: recordsKey), var value = decode(data) {
                if value.syncState == nil {
                    value.syncState = BabySyncState(babies: value.babies)
                    persist(value, to: store)
                }
                return value
            }
            var value = BabyCollection()
            if store.data(forKey: recordsKey) == nil,
               let old = store.string(forKey: birthDateKey).flatMap(BirthDate.init(storageValue:)) {
                value.upsert(Baby(id: "legacy-baby", name: "宝宝", birth: old))
                value = save(value, to: store)
            }
            return value
        }
    }
    @discardableResult
    static func save(_ value: BabyCollection, to store: UserDefaults = defaults, now: Date = .now) -> BabyCollection {
        ProfileTransaction.withStore(store) {
            let previous = store.data(forKey: recordsKey).flatMap(decode)
            let base = value.syncState ?? BabySyncState(babies: previous?.babies ?? [])
            var state = previous?.syncState ?? BabySyncState(babies: previous?.babies ?? [])
            state.edit(from: base, to: value.babies, now: now)
            var result = value
            result.syncState = state
            result.babies = state.babies(keeping: value.babies)
            repairSelection(&result)
            persist(result, to: store)
            return result
        }
    }

    /// Incoming cloud data never replaces local selection, icon preferences, or widget assignments.
    @discardableResult
    static func merge(_ records: [BabySyncRecord], from store: UserDefaults = defaults) -> BabyCollection {
        ProfileTransaction.withStore(store) {
            var result = load(from: store)
            var state = result.syncState ?? BabySyncState(babies: result.babies)
            state.merge(records)
            result.syncState = state
            result.babies = state.babies(keeping: result.babies)
            repairSelection(&result)
            persist(result, to: store)
            return result
        }
    }

    /// legacy-baby was intentionally device-local. Give each device's old profile its own cloud ID.
    static func prepareForSync(in store: UserDefaults = defaults) {
        ProfileTransaction.withStore(store) {
            var value = load(from: store)
            guard var state = value.syncState, var old = state.records.removeValue(forKey: "legacy-baby") else { return }
            let id = value.legacySyncID ?? UUID().uuidString
            old.id = id
            state.records[id] = old
            value.syncState = state
            value.legacySyncID = id
            for index in value.babies.indices where value.babies[index].id == "legacy-baby" { value.babies[index].id = id }
            if value.selectedID == "legacy-baby" { value.selectedID = id }
            if value.iconBabyID == "legacy-baby" { value.iconBabyID = id }
            persist(value, to: store)
        }
    }

    private static func repairSelection(_ value: inout BabyCollection) {
        if !value.babies.contains(where: { $0.id == value.selectedID }) { value.selectedID = value.babies.first?.id }
        if !value.babies.contains(where: { $0.id == value.iconBabyID }) { value.iconBabyID = nil }
    }

    private static func persist(_ value: BabyCollection, to store: UserDefaults) {
        if let data = store.data(forKey: recordsKey), decode(data) == value { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(value) else { return }
        store.set(data, forKey: recordsKey)
        // Keep older installed app/extension versions reading the default baby's latest date
        store.set(value.selected?.birth.storageValue, forKey: birthDateKey)
        ProfileTransaction.changed(store)
    }
    static func baby(id: String?, from store: UserDefaults = defaults) -> Baby? {
        let value = load(from: store)
        guard let id else { return value.selected }
        let resolved = id == "legacy-baby" ? value.legacySyncID ?? id : id
        return value.babies.first { $0.id == resolved }
    }
    static var birthDate: BirthDate? {
        get { load().selected?.birth }
        set {
            var value = load()
            if let newValue {
                var baby = value.selected ?? Baby(name: "宝宝", birth: newValue)
                baby.birth = newValue
                value.upsert(baby)
            } else if let id = value.selected?.id { value.remove(id: id) }
            save(value)
        }
    }
}

/// The App and its extensions are separate writers. Serialize their read/merge/write transactions.
private enum ProfileTransaction {
    private static let mutex = NSRecursiveLock()
    private static var depth = 0
    private static var pending = Set<UserDefaults>()
    private static let lockURL: URL? = BabyProfile.appGroup.flatMap {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
    }?.appendingPathComponent(".baby-profile.lock")

    static func withStore<T>(_ store: UserDefaults, _ operation: () -> T) -> T {
        mutex.lock()
        let outermost = depth == 0
        depth += 1
        var descriptor: Int32 = -1
        if outermost {
            if store === BabyProfile.defaults, let lockURL {
                descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
                if descriptor >= 0, flock(descriptor, LOCK_EX) != 0 {
                    close(descriptor)
                    descriptor = -1
                }
            }
            // Refresh another process's committed preferences before rebasing this transaction.
            store.synchronize()
        }
        defer {
            var notifications: Set<UserDefaults> = []
            if outermost {
                store.synchronize()
                if descriptor >= 0 { flock(descriptor, LOCK_UN); close(descriptor) }
                notifications = pending
                pending.removeAll()
            }
            depth -= 1
            mutex.unlock()
            // Main-queue observers may start another transaction. Never notify while holding the lock.
            for item in notifications { NotificationCenter.default.post(name: BabyProfile.didChange, object: item) }
        }
        return operation()
    }

    static func changed(_ store: UserDefaults) { pending.insert(store) }
}
