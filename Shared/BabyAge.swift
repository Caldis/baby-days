import Foundation

/// 宝宝在某一天的年龄快照, 按公历自然日计算
struct BabyAge: Equatable {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        return calendar
    }

    let birth: BirthDate
    /// 展示日 0 点
    let day: Date
    let years: Int
    let months: Int
    let days: Int
    /// 出生至展示日经过的自然日数, 出生当天为 0
    let totalDays: Int
    let daysUntilNextBirthday: Int
    /// 当前这一岁已走过的比例, 取值 0...1
    let yearProgress: Double
    /// 距满月的天数, 仅在出生第一个月内有意义
    let daysUntilFullMonth: Int

    init(birth: BirthDate, on date: Date = .now, calendar: Calendar = BabyAge.calendar) {
        self.birth = birth
        let birth = birth.date(calendar: calendar)
        let today = max(calendar.startOfDay(for: date), birth)
        let parts = calendar.dateComponents([.year, .month, .day], from: birth, to: today)

        day = today
        years = parts.year ?? 0
        months = parts.month ?? 0
        days = parts.day ?? 0
        totalDays = calendar.dateComponents([.day], from: birth, to: today).day ?? 0

        let lastBirthday = calendar.date(byAdding: .year, value: years, to: birth)!
        let nextBirthday = calendar.date(byAdding: .year, value: years + 1, to: birth)!
        let yearLength = calendar.dateComponents([.day], from: lastBirthday, to: nextBirthday).day ?? 365
        daysUntilNextBirthday = calendar.dateComponents([.day], from: today, to: nextBirthday).day ?? 0
        yearProgress = Double(yearLength - daysUntilNextBirthday) / Double(max(yearLength, 1))

        let fullMonth = calendar.date(byAdding: .month, value: 1, to: birth)!
        daysUntilFullMonth = max(calendar.dateComponents([.day], from: today, to: fullMonth).day ?? 0, 0)
    }
}

// MARK: - 文案

extension BabyAge {
    /// 未满周岁
    var isInfant: Bool { years == 0 }

    var isBirthday: Bool { years > 0 && months == 0 && days == 0 }

    var caption: String { isBirthday ? "宝宝今天" : "宝宝已经" }

    /// 主数字与单位: 未满周岁显示天数, 满周岁后显示岁数与月数
    var heroSegments: [(value: String, unit: String)] {
        if isInfant { return [("\(totalDays)", "天")] }
        if months == 0 { return [("\(years)", "岁")] }
        return [("\(years)", "岁"), ("\(months)", "个月")]
    }

    /// 主数字之后的补充说明, 与主数字连读成完整的年龄
    var detail: String {
        if isInfant {
            if totalDays == 0 { return "欢迎来到这个世界" }
            if months == 0 { return "距满月还有 \(daysUntilFullMonth) 天" }
            if days == 0 { return "满 \(months) 个月啦" }
            return "\(months) 个月 \(days) 天"
        }
        if isBirthday { return "生日快乐" }
        if days == 0 { return totalDaysNote }
        return "零 \(days) 天"
    }

    /// 满周岁后的累计天数说明
    var totalDaysNote: String { "来到世界 \(totalDays) 天" }

    var countdown: String {
        if isBirthday { return "今天是 \(years) 岁生日" }
        if daysUntilNextBirthday == 1 { return "明天就 \(years + 1) 岁啦" }
        return "距 \(years + 1) 岁生日还有 \(daysUntilNextBirthday) 天"
    }

    /// 生日倒计时卡片的标题, 数值与单位
    var countdownTitle: String { isBirthday ? "今天是" : "距 \(years + 1) 岁生日" }

    var countdownValue: String { isBirthday ? "\(years)" : "\(daysUntilNextBirthday)" }

    var countdownUnit: String { isBirthday ? "岁生日" : "天" }

    /// 生日进度条比例, 生日当天为满格
    var birthdayProgress: Double { isBirthday ? 1 : yearProgress }

    /// 周龄: 满周数与余下的天数
    var weeks: Int { totalDays / 7 }

    var weekRemainderDays: Int { totalDays % 7 }

    /// 已经度过的小时数, 按整天计
    var hoursText: String { Self.grouped(totalDays * 24) }

    /// 心跳次数估算, 按平均每分钟 120 次计
    var heartbeats: (value: String, unit: String) {
        let beats = Double(totalDays) * 24 * 60 * 120
        if beats >= 100_000_000 { return (String(format: "%.1f", beats / 100_000_000), "亿次") }
        return (Self.grouped(Int(beats / 10_000)), "万次")
    }

    private static func grouped(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic).locale(Locale(identifier: "en_US")))
    }

    var birthDateText: String { birth.displayText }

    var dateText: String {
        let formatter = DateFormatter()
        formatter.calendar = Self.calendar
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: day)
    }

    var weekdayText: String {
        let formatter = DateFormatter()
        formatter.calendar = Self.calendar
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: day)
    }
}
