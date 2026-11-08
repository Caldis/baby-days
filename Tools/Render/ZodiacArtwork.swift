import AppKit
import SwiftUI

/// 日历版生成系统图标, 无日历版生成 App 与小组件图片
@MainActor
enum ZodiacArtwork {
    static func render(root: URL) throws {
        let resources = root.appendingPathComponent("Resources")
        let catalog = resources.appendingPathComponent("Zodiac.xcassets")
        let widgetCatalog = resources.appendingPathComponent("ZodiacWidgets.xcassets")
        for url in [catalog, widgetCatalog] { try writeJSON(["info": info], to: url.appendingPathComponent("Contents.json")) }
        for zodiac in Zodiac.allCases {
            let mascot = catalog.appendingPathComponent("\(zodiac.assetName).imageset")
            try writeImageSet(IconArtwork.mascotImage(zodiac).resizable().scaledToFit().padding(16)
                .frame(width: 512, height: 512), directory: mascot, filename: "mascot.png")
            let thumbnail = widgetCatalog.appendingPathComponent("\(zodiac.widgetAssetName).imageset")
            try writeImageSet(IconArtwork.mascotImage(zodiac).resizable().scaledToFit().padding(4)
                .frame(width: 192, height: 192), directory: thumbnail, filename: "mascot.png")

            let preview = catalog.appendingPathComponent("IconPreview-\(zodiac.rawValue).imageset")
            try writeImageSet(IconArtwork.Icon(zodiac: zodiac), directory: preview, filename: "icon.png", opaque: true)
            let artwork = preview.appendingPathComponent("icon.png")
            if zodiac == .snake {
                try Data(contentsOf: artwork).write(to: resources.appendingPathComponent("Artwork/app-icon.png"))
            } else {
                let icon = resources.appendingPathComponent("AlternateIcons/\(zodiac.iconName).icon")
                let assets = icon.appendingPathComponent("Assets")
                try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
                try Data(contentsOf: artwork).write(to: assets.appendingPathComponent("artwork.png"))
                let configuration: [String: Any] = [
                    "fill-specializations": [["value": ["solid": "srgb:1,1,1,1"]]],
                    "groups": [["name": "Artwork", "layers": [["glass": false, "image-name": "artwork.png", "name": "Artwork"]],
                                "shadow": ["kind": "none", "opacity": 0.0], "translucency": ["enabled": false, "value": 0.0]]],
                    "supported-platforms": ["squares": "shared"]
                ]
                try writeJSON(configuration, to: icon.appendingPathComponent("icon.json"))
            }
        }
        try Render.write(CollectionPreview(), scale: 1, to: root.appendingPathComponent("docs/images/zodiac-collection.png"))
        try Render.write(IconSizesPreview(), scale: 1, to: root.appendingPathComponent(".build/zodiac-icon-sizes.png"))
    }

    struct CollectionPreview: View {
        var body: some View {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(340), spacing: 16), count: 3), spacing: 16) {
                ForEach(Zodiac.allCases) { zodiac in
                    let palette = Palette.for(.light, zodiac: zodiac)
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            IconArtwork.mascotImage(zodiac).resizable().scaledToFit().frame(width: 144, height: 164)
                            IconArtwork.Icon(zodiac: zodiac).scaleEffect(144 / 1024)
                                .frame(width: 144, height: 144)
                                .clipShape(RoundedRectangle(cornerRadius: 32))
                        }
                        Text("\(zodiac.name) · \(zodiac.themeName)").font(.cute(20)).foregroundStyle(palette.ink)
                    }
                    .frame(width: 340, height: 234).background(palette.skyTop)
                }
            }.padding(20).background(Color(hex: 0xFFFDF4))
        }
    }

    struct IconSizesPreview: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Zodiac.allCases) { zodiac in
                    HStack(spacing: 24) {
                        Text(zodiac.name).font(.system(size: 18)).frame(width: 30)
                        ForEach([32, 60, 180], id: \.self) { side in
                            IconArtwork.Icon(zodiac: zodiac).scaleEffect(CGFloat(side) / 1024)
                                .frame(width: CGFloat(side), height: CGFloat(side))
                                .clipShape(RoundedRectangle(cornerRadius: CGFloat(side) * 0.225))
                        }
                    }
                }
            }.padding(24).background(Color(hex: 0xF3F2F6))
        }
    }

    private static let info: [String: Any] = ["author": "xcode", "version": 1]
    private static func writeImageSet<V: View>(_ view: V, directory: URL, filename: String, opaque: Bool = false) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Render.write(view, scale: 1, to: directory.appendingPathComponent(filename), opaque: opaque)
        try writeJSON(["images": [["filename": filename, "idiom": "universal"]], "info": info], to: directory.appendingPathComponent("Contents.json"))
    }
    private static func writeJSON(_ value: [String: Any], to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: url)
    }
}
