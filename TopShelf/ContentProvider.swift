import SwiftUI
import TVServices
import UIKit

/// Apple TV 顶部栏: App 位于首行时, 展示一张实时渲染的年龄横幅
final class ContentProvider: TVTopShelfContentProvider {
    override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
        // 未设置生日时交回 nil, 系统显示静态顶部栏图
        guard let birth = BabyProfile.birthDate else {
            completionHandler(nil)
            return
        }
        DispatchQueue.main.async {
            let age = BabyAge(birth: birth)
            let item = TVTopShelfItem(identifier: "age-\(age.totalDays)")
            for (scale, trait) in [(1, TVTopShelfItem.ImageTraits.screenScale1x), (2, .screenScale2x)] {
                if let url = BannerRenderer.render(age: age, scale: CGFloat(scale)) {
                    item.setImageURL(url, for: trait)
                }
            }
            if let url = URL(string: "babydays://open") {
                item.displayAction = TVTopShelfAction(url: url)
            }
            completionHandler(TVTopShelfInsetContent(items: [item]))
        }
    }
}

/// 把 TVAgeBoard 横幅渲染为 PNG, 写入 App Group 容器供系统读取
@MainActor
enum BannerRenderer {
    static let size = CGSize(width: 1940, height: 692)

    static func render(age: BabyAge, scale: CGFloat) -> URL? {
        let dark = UIScreen.main.traitCollection.userInterfaceStyle == .dark
        let banner = TVAgeBoard(age: age, snake: Image("Snake"), style: .banner)
            .frame(width: size.width, height: size.height)
            .environment(\.palette, dark ? .night : .day)
        let renderer = ImageRenderer(content: banner)
        renderer.scale = scale
        guard let data = renderer.uiImage?.pngData(),
              let group = BabyProfile.appGroup,
              let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        else { return nil }
        let folder = container.appendingPathComponent("TopShelf", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // 文件名带上天数与深浅色, 系统按 URL 缓存图片
        let url = folder.appendingPathComponent("banner-\(age.totalDays)-\(dark ? "dark" : "light")@\(Int(scale))x.png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
