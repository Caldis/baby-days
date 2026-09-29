import SwiftUI

/// Apple TV 素材: 分层 App 图标, 顶部栏静态图, 以及 App 与顶部栏横幅使用的小蛇图片
enum TVArtwork {
    @MainActor
    static func render(to resources: URL) throws {
        let brand = resources.appendingPathComponent("TVIcon.xcassets/App Icon & Top Shelf Image.brandassets")
        try writeCatalogRoot(resources.appendingPathComponent("TVIcon.xcassets"))
        try writeJSON(brandContents, to: brand.appendingPathComponent("Contents.json"))
        try writeStack(at: brand.appendingPathComponent("App Icon - App Store.imagestack"), size: CGSize(width: 1280, height: 768), scales: [1])
        try writeStack(at: brand.appendingPathComponent("App Icon.imagestack"), size: CGSize(width: 400, height: 240), scales: [1, 2])
        try writeShelf(at: brand.appendingPathComponent("Top Shelf Image.imageset"), size: CGSize(width: 1920, height: 720))
        try writeShelf(at: brand.appendingPathComponent("Top Shelf Image Wide.imageset"), size: CGSize(width: 2320, height: 720))

        let shared = resources.appendingPathComponent("TVShared.xcassets")
        try writeCatalogRoot(shared)
        let snake = shared.appendingPathComponent("Snake.imageset")
        try FileManager.default.createDirectory(at: snake, withIntermediateDirectories: true)
        let full = CGRect(x: 0, y: 0, width: 512, height: 512)
        for scale in [1, 2] {
            let image = PencilSnake.image(size: full.size, scale: CGFloat(scale), parts: [.snake], snakeRect: full)
            try PencilSnake.write(image, to: snake.appendingPathComponent("snake@\(scale)x.png"))
        }
        try writeJSON(imageSetContents(["snake@1x.png", "snake@2x.png"]), to: snake.appendingPathComponent("Contents.json"))
    }

    /// 顶部栏静态图与 App 内共用的构图: 左侧小蛇, 右侧文字
    struct ShelfArt: View {
        let size: CGSize

        var body: some View {
            let side = size.height * 0.96
            ZStack(alignment: .leading) {
                Image(
                    decorative: PencilSnake.image(
                        size: size, scale: 2, parts: [.paper, .backdrop, .snake],
                        snakeRect: CGRect(x: size.width * 0.12, y: (size.height - side) / 2, width: side, height: side)
                    ),
                    scale: 2
                )
                VStack(alignment: .leading, spacing: 18) {
                    Text("宝宝多大")
                        .font(.cute(128))
                        .foregroundStyle(Color(hex: 0x3A4722))
                    Text("看看宝宝今天多大啦")
                        .font(.cute(48))
                        .foregroundStyle(Color(hex: 0x3A4722).opacity(0.6))
                }
                .padding(.leading, size.width * 0.12 + side + 40)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    // MARK: - 写入

    @MainActor
    private static func writeStack(at directory: URL, size: CGSize, scales: [Int]) throws {
        let side = size.height * 0.98
        let rect = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side)
        let layers: [(String, PencilSnake.Parts)] = [("Front", [.snake]), ("Back", [.paper, .backdrop])]
        for (name, parts) in layers {
            let layer = directory.appendingPathComponent("\(name).imagestacklayer")
            let content = layer.appendingPathComponent("Content.imageset")
            try FileManager.default.createDirectory(at: content, withIntermediateDirectories: true)
            var files: [String] = []
            for scale in scales {
                let file = "\(name.lowercased())@\(scale)x.png"
                try PencilSnake.write(
                    PencilSnake.image(size: size, scale: CGFloat(scale), parts: parts, snakeRect: rect),
                    to: content.appendingPathComponent(file)
                )
                files.append(file)
            }
            try writeJSON(infoOnly, to: layer.appendingPathComponent("Contents.json"))
            try writeJSON(imageSetContents(files), to: content.appendingPathComponent("Contents.json"))
        }
        try writeJSON(
            ["info": info, "layers": layers.map { ["filename": "\($0.0).imagestacklayer"] }],
            to: directory.appendingPathComponent("Contents.json")
        )
    }

    @MainActor
    private static func writeShelf(at directory: URL, size: CGSize) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var files: [String] = []
        for scale in [1, 2] {
            let file = "shelf@\(scale)x.png"
            try Render.write(ShelfArt(size: size), scale: CGFloat(scale), to: directory.appendingPathComponent(file))
            files.append(file)
        }
        try writeJSON(imageSetContents(files), to: directory.appendingPathComponent("Contents.json"))
    }

    private static func writeCatalogRoot(_ catalog: URL) throws {
        try FileManager.default.createDirectory(at: catalog, withIntermediateDirectories: true)
        try writeJSON(infoOnly, to: catalog.appendingPathComponent("Contents.json"))
    }

    private static let info: [String: Any] = ["author": "xcode", "version": 1]
    private static var infoOnly: [String: Any] { ["info": info] }

    private static func imageSetContents(_ files: [String]) -> [String: Any] {
        [
            "images": files.enumerated().map { index, file in
                ["filename": file, "idiom": "tv", "scale": "\(index + 1)x"]
            },
            "info": info,
        ]
    }

    private static var brandContents: [String: Any] {
        [
            "assets": [
                ["filename": "App Icon - App Store.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "1280x768"],
                ["filename": "App Icon.imagestack", "idiom": "tv", "role": "primary-app-icon", "size": "400x240"],
                ["filename": "Top Shelf Image Wide.imageset", "idiom": "tv", "role": "top-shelf-image-wide", "size": "2320x720"],
                ["filename": "Top Shelf Image.imageset", "idiom": "tv", "role": "top-shelf-image", "size": "1920x720"],
            ],
            "info": info,
        ]
    }

    private static func writeJSON(_ object: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url)
    }
}
