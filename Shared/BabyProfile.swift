import Foundation

/// 宝宝的出生日期, 只保存公历年月日, 与时区无关
struct BirthDate: Equatable, Sendable {
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
        let parts = storageValue.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        self.init(year: parts[0], month: parts[1], day: parts[2])
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

/// 出生日期的存储, App 与小组件通过 App Group 共享
enum BabyProfile {
    static let birthDateKey = "birthDate"

    /// App Group 标识, 取自 Info.plist 的 BabyDaysAppGroup
    static var appGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: "BabyDaysAppGroup") as? String
    }

    static var defaults: UserDefaults {
        appGroup.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    static var birthDate: BirthDate? {
        get { defaults.string(forKey: birthDateKey).flatMap(BirthDate.init(storageValue:)) }
        set { defaults.set(newValue?.storageValue, forKey: birthDateKey) }
    }
}
