import SwiftUI

/// App 图标图层, 画布为 1024 × 1024, 与 AppIcon.icon/icon.json 中的图层一一对应
enum IconArtwork {
    static let canvas: CGFloat = 1024
    /// 纸张底色, 与 icon.json 的 fill 保持一致
    static let paper = Color(hex: 0xFBF7EA)

    @MainActor
    static func render(to iconDirectory: URL) throws {
        let assets = iconDirectory.appendingPathComponent("Assets")
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        try PencilSnake.write(PencilSnake.snakeLayer(), to: assets.appendingPathComponent("snake.png"))
        try PencilSnake.write(PencilSnake.paperLayer(), to: assets.appendingPathComponent("paper.png"))
    }

    /// 平面合成预览, 用于文档与离线检查
    struct Composite: View {
        var body: some View {
            ZStack {
                IconArtwork.paper
                Image(decorative: PencilSnake.paperLayer(), scale: 1)
                Image(decorative: PencilSnake.snakeLayer(), scale: 1)
            }
            .frame(width: canvas, height: canvas)
            .clipShape(RoundedRectangle(cornerRadius: canvas * 0.225, style: .continuous))
        }
    }
}
