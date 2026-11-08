import AppKit
import SwiftUI

/// 加载独立生成的生肖双版本, 导出时统一尺寸与安全边距
@MainActor
enum IconArtwork {
    static let canvas: CGFloat = 1024
    static let paper = Color(hex: 0xF3F6E4)
    private static var icon: NSImage!
    private static var mascots: [Zodiac: NSImage] = [:]
    private static var calendars: [Zodiac: NSImage] = [:]
    private static var source: URL!

    static func load(from root: URL) throws {
        source = root.appendingPathComponent("Resources/Artwork/app-icon.png")
        icon = NSImage(contentsOf: source)
        for zodiac in Zodiac.allCases {
            for variant in ["mascots", "calendar"] {
                let url = root.appendingPathComponent("Resources/Artwork/Zodiac/\(variant)/\(zodiac.rawValue).png")
                let image = try normalizedImage(at: url)
                if variant == "mascots" { mascots[zodiac] = image } else { calendars[zodiac] = image }
            }
        }
    }

    static var snakeImage: Image { mascotImage(.snake) }
    static func mascotImage(_ zodiac: Zodiac) -> Image { Image(nsImage: mascots[zodiac]!) }
    static func calendarImage(_ zodiac: Zodiac) -> Image { Image(nsImage: calendars[zodiac]!) }

    /// 只裁去透明外边距, 画稿及透明边缘不变, 以完整轮廓统一导出比例
    private static func normalizedImage(at url: URL) throws -> NSImage {
        guard let image = NSImage(contentsOf: url),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw Render.RenderError.emptyImage
        }
        let width = cg.width, height = cg.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        guard let context = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw Render.RenderError.emptyImage
        }
        context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        var minX = width, minY = height, maxX = 0, maxY = 0
        for y in 0..<height {
            for x in 0..<width where pixels[(y * width + x) * 4 + 3] >= 200 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard minX < maxX, minY < maxY else { throw Render.RenderError.emptyImage }
        let padding = 4
        let rect = CGRect(x: max(0, minX - padding), y: max(0, minY - padding),
                          width: min(width, maxX + padding + 1) - max(0, minX - padding),
                          height: min(height, maxY + padding + 1) - max(0, minY - padding))
        guard let cropped = cg.cropping(to: rect) else { throw Render.RenderError.emptyImage }
        return NSImage(cgImage: cropped, size: rect.size)
    }

    static func render(to iconDirectory: URL) throws {
        let assets = iconDirectory.appendingPathComponent("Assets")
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        try Data(contentsOf: source).write(to: assets.appendingPathComponent("artwork.png"))
    }

    struct Icon: View {
        let zodiac: Zodiac
        var body: some View {
            ZStack {
                Palette.for(.light, zodiac: zodiac).skyTop
                calendarImage(zodiac).resizable().scaledToFit()
                    .frame(width: canvas * 0.84, height: canvas * 0.84)
            }
            .frame(width: canvas, height: canvas)
        }
    }

    /// 文档预览使用系统圆角, 正式素材保留方形画布
    struct Composite: View {
        var body: some View {
            Image(nsImage: IconArtwork.icon)
                .resizable()
                .frame(width: canvas, height: canvas)
                .clipShape(RoundedRectangle(cornerRadius: canvas * 0.225, style: .continuous))
        }
    }
}
