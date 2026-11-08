import Foundation

/// 农历生肖以春节换年, 用出生当天的中国历年份计算, 与设备当前时区无关
// Chinese calendar year 1 is 甲子 (鼠), years repeat every 60 years
// Use noon in China to preserve the stored civil birthday at calendar boundaries
// BirthDate remains a Gregorian date

enum Zodiac: String, CaseIterable, Codable, Identifiable, Sendable {
    case rat, ox, tiger, rabbit, dragon, snake, horse, goat, monkey, rooster, dog, pig
    var id: String { rawValue }
    var name: String {
        ["鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪"][Self.allCases.firstIndex(of: self)!]
    }
    var assetName: String { "Zodiac-\(rawValue)" }
    var widgetAssetName: String { "WidgetZodiac-\(rawValue)" }
    var iconName: String { "ZodiacIcon-\(rawValue)" }
    var themeName: String {
        ["雾紫", "麦田", "杏橙", "蔷薇", "青玉", "嫩绿", "陶土", "鼠尾草", "琥珀", "莓红", "晴蓝", "蜜桃"][Self.allCases.firstIndex(of: self)!]
    }
    var colorHex: UInt32 {
        [0x8173C9, 0xB98B48, 0xD97732, 0xC46C8C, 0x2E948F, 0xA3C752,
         0xB3654F, 0x7C9470, 0xB58A25, 0xBC5362, 0x4F83B4, 0xC78678][Self.allCases.firstIndex(of: self)!]
    }
    init(birth: BirthDate) {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = gregorian.timeZone
        let date = gregorian.date(from: DateComponents(year: birth.year, month: birth.month, day: birth.day, hour: 12))!
        let year = chinese.component(.year, from: date)
        self = Self.allCases[(year - 1) % 12]
    }
}
