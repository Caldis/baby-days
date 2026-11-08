import Foundation

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
        if let data = store.data(forKey: recordsKey), let value = decode(data) { return value }
        var value = BabyCollection()
        if store.data(forKey: recordsKey) == nil,
           let old = store.string(forKey: birthDateKey).flatMap(BirthDate.init(storageValue:)) {
            value.upsert(Baby(id: "legacy-baby", name: "宝宝", birth: old))
            save(value, to: store)
        }
        return value
    }
    static func save(_ value: BabyCollection, to store: UserDefaults = defaults) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        store.set(data, forKey: recordsKey)
        // Keep older installed app/extension versions reading the default baby's latest date
        store.set(value.selected?.birth.storageValue, forKey: birthDateKey)
    }
    static func baby(id: String?, from store: UserDefaults = defaults) -> Baby? {
        let value = load(from: store)
        guard let id else { return value.selected }
        return value.babies.first { $0.id == id }
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
