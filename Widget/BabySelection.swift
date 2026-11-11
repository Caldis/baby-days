import AppIntents
import WidgetKit

/// 保存原生字符串 ID, 动态选项只负责显示称呼, 避免实体注册失败时配置静默退回默认宝宝
struct BabyOptionsProvider: DynamicOptionsProvider {
    func results() async throws -> IntentItemCollection<String> {
        await BabyCloudSync.shared.refresh()
        let items = BabyProfile.load().babies.map { baby in
            IntentItem(baby.id, title: "\(baby.displayName)", subtitle: "属\(baby.zodiac.name) · \(baby.birth.displayText)")
        }
        return IntentItemCollection(sections: [IntentItemSection(items: items)])
    }
    func defaultResult() async -> String? {
        await BabyCloudSync.shared.refresh()
        return BabyProfile.load().selected?.id
    }
}

struct SelectBabyIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "选择宝宝"
    static var description = IntentDescription("每个小组件可以选择不同的宝宝, 生肖主题会自动匹配生日")
    @Parameter(title: "宝宝", optionsProvider: BabyOptionsProvider()) var babyID: String?
    static var parameterSummary: some ParameterSummary { Summary("显示\(\.$babyID)") }
}
