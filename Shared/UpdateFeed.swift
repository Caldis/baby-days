import Foundation

/// 读取 Sparkle 更新清单, 判断是否有更高的构建号; 仅 macOS 小组件使用
enum UpdateFeed {
    static var feedURL: URL? {
        (Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String).flatMap(URL.init(string:))
    }

    /// 当前进程加载时的构建号
    static var runningBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    /// 磁盘上 App 的构建号, 每次从 Info.plist 重新读取
    static var installedBuild: String {
        let app = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = app.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let build = plist["CFBundleVersion"] as? String
        else { return runningBuild }
        return build
    }

    /// 更新安装后系统可能继续复用旧版本的扩展进程, 此时磁盘上的构建号与进程加载的构建号不一致
    static var isStaleProcess: Bool {
        installedBuild != runningBuild
    }

    static func isUpdateAvailable() async -> Bool {
        guard let latest = await latestBuild() else { return false }
        return latest.compare(installedBuild, options: .numeric) == .orderedDescending
    }

    /// 清单中所有 sparkle:version 的最大值
    static func latestBuild() async -> String? {
        guard let url = feedURL else { return nil }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let xml = String(data: data, encoding: .utf8),
              let regex = try? NSRegularExpression(pattern: "<sparkle:version>\\s*([^<\\s]+)\\s*</sparkle:version>")
        else { return nil }
        let range = NSRange(xml.startIndex..., in: xml)
        return regex.matches(in: xml, range: range)
            .compactMap { Range($0.range(at: 1), in: xml).map { String(xml[$0]) } }
            .max { $0.compare($1, options: .numeric) == .orderedAscending }
    }
}
