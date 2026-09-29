import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// 彩色铅笔风格的布偶小蛇, 用于 App 图标; 画布 1024 × 1024, 坐标原点在左上角
enum PencilSnake {
    static let size = 1024

    /// 小蛇图层, 透明背景
    static func snakeLayer() -> CGImage {
        draw { ctx, rng in
            drawGroundShadow(ctx, &rng)
            drawBody(ctx, &rng)
            drawFace(ctx, &rng)
        }
    }

    /// 纸张纹理图层, 叠加在底色之上
    static func paperLayer() -> CGImage {
        draw { ctx, rng in
            for _ in 0..<26000 {
                let p = CGPoint(x: rng.next() * 1024, y: rng.next() * 1024)
                let gray = 0.35 + rng.next() * 0.3
                ctx.setFillColor(CGColor(srgbRed: gray, green: gray * 0.97, blue: gray * 0.85, alpha: 0.05 + rng.next() * 0.05))
                let r = 0.6 + rng.next() * 1.2
                ctx.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
            }
            for _ in 0..<420 {
                let start = CGPoint(x: rng.next() * 1024, y: rng.next() * 1024)
                let angle = rng.next() * .pi
                let length = 10 + rng.next() * 26
                let end = CGPoint(x: start.x + cos(angle) * length, y: start.y + sin(angle) * length)
                ctx.setStrokeColor(CGColor(srgbRed: 0.55, green: 0.5, blue: 0.4, alpha: 0.05))
                ctx.setLineWidth(0.8)
                ctx.move(to: start)
                ctx.addQuadCurve(to: end, control: CGPoint(x: (start.x + end.x) / 2 + rng.signed() * 5, y: (start.y + end.y) / 2 + rng.signed() * 5))
                ctx.strokePath()
            }
        }
    }

    static func write(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw Render.RenderError.writeFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw Render.RenderError.writeFailed }
        print("wrote \(url.path)")
    }

    // MARK: - 配色

    private static let greenLight = Color(0.76, 0.84, 0.45)
    private static let greenMid = Color(0.58, 0.71, 0.29)
    private static let greenDark = Color(0.40, 0.53, 0.19)
    private static let cream = Color(0.97, 0.95, 0.84)
    private static let creamShade = Color(0.84, 0.80, 0.64)
    private static let outline = Color(0.26, 0.31, 0.15)
    private static let graphite = Color(0.17, 0.15, 0.14)
    private static let blush = Color(0.96, 0.62, 0.62)

    // MARK: - 形状

    /// 身体与颈部合成的绿色轮廓: 颈部背面顺势弯向左侧的尾巴
    private static var greenBodyPath: CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 446, y: 430))
        path.addCurve(to: CGPoint(x: 400, y: 630), control1: CGPoint(x: 416, y: 500), control2: CGPoint(x: 400, y: 570))
        path.addCurve(to: CGPoint(x: 236, y: 704), control1: CGPoint(x: 384, y: 672), control2: CGPoint(x: 310, y: 684))
        path.addCurve(to: CGPoint(x: 118, y: 768), control1: CGPoint(x: 170, y: 720), control2: CGPoint(x: 126, y: 740))
        path.addCurve(to: CGPoint(x: 170, y: 814), control1: CGPoint(x: 108, y: 800), control2: CGPoint(x: 136, y: 812))
        path.addCurve(to: CGPoint(x: 716, y: 842), control1: CGPoint(x: 320, y: 834), control2: CGPoint(x: 560, y: 852))
        path.addCurve(to: CGPoint(x: 796, y: 750), control1: CGPoint(x: 776, y: 836), control2: CGPoint(x: 804, y: 800))
        path.addCurve(to: CGPoint(x: 736, y: 430), control1: CGPoint(x: 812, y: 630), control2: CGPoint(x: 780, y: 520))
        path.closeSubpath()
        return path
    }

    /// 奶白色的下巴与胸口, 上沿压住头部下方形成下巴
    private static var chestPath: CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 470, y: 440))
        path.addCurve(to: CGPoint(x: 690, y: 432), control1: CGPoint(x: 540, y: 470), control2: CGPoint(x: 620, y: 468))
        path.addCurve(to: CGPoint(x: 712, y: 720), control1: CGPoint(x: 740, y: 520), control2: CGPoint(x: 750, y: 650))
        path.addCurve(to: CGPoint(x: 498, y: 738), control1: CGPoint(x: 660, y: 790), control2: CGPoint(x: 550, y: 800))
        path.addCurve(to: CGPoint(x: 470, y: 440), control1: CGPoint(x: 450, y: 660), control2: CGPoint(x: 440, y: 530))
        path.closeSubpath()
        return path
    }

    private static var headPath: CGPath {
        let rect = CGRect(x: 296, y: 176, width: 530, height: 320)
        var transform = CGAffineTransform(translationX: rect.midX, y: rect.midY).rotated(by: -0.05).translatedBy(x: -rect.midX, y: -rect.midY)
        return CGPath(roundedRect: rect, cornerWidth: 250, cornerHeight: 158, transform: &transform)
    }

    /// 身后的淡色圆形衬底
    private static var backdropPath: CGPath {
        CGPath(ellipseIn: CGRect(x: 170, y: 120, width: 720, height: 720), transform: nil)
    }

    // MARK: - 绘制

    private static func drawGroundShadow(_ ctx: CGContext, _ rng: inout RNG) {
        let shadow = CGPath(ellipseIn: CGRect(x: 120, y: 800, width: 740, height: 90), transform: nil)
        hatch(ctx, shadow, &rng, color: Color(0.55, 0.58, 0.45), angle: -0.5, spacing: 7, width: 2, alpha: 0.18)
    }

    private static func drawBody(_ ctx: CGContext, _ rng: inout RNG) {
        // 衬底
        hatch(ctx, backdropPath, &rng, color: Color(0.95, 0.90, 0.66), angle: -0.7, spacing: 5, width: 2.6, alpha: 0.36)
        sketchOutline(ctx, backdropPath, &rng, color: Color(0.86, 0.78, 0.48), alpha: 0.35, passes: 2, jitter: 3)

        // 身体与颈部
        let green = greenBodyPath
        tint(ctx, green, greenLight, 0.6)
        hatch(ctx, green, &rng, color: greenMid, angle: -0.7, spacing: 6, width: 2.6, alpha: 0.42)
        shade(ctx, green, &rng, offset: CGSize(width: -30, height: -36), color: greenDark, alpha: 0.38)
        fur(ctx, green, &rng, color: greenDark, count: 420, alpha: 0.22)
        fuzzyEdge(ctx, green, &rng, color: greenMid)
        sketchOutline(ctx, green, &rng)

        // 头部
        tint(ctx, headPath, greenLight, 0.7)
        hatch(ctx, headPath, &rng, color: greenMid, angle: -0.7, spacing: 5.5, width: 2.8, alpha: 0.42)
        hatch(ctx, headPath, &rng, color: greenLight, angle: 0.5, spacing: 9, width: 2.2, alpha: 0.32)
        shade(ctx, headPath, &rng, offset: CGSize(width: -26, height: -44), color: greenDark, alpha: 0.4)
        fur(ctx, headPath, &rng, color: greenDark, count: 440, alpha: 0.22)
        highlight(ctx, CGPath(ellipseIn: CGRect(x: 420, y: 206, width: 190, height: 66), transform: nil), &rng)
        fuzzyEdge(ctx, headPath, &rng, color: greenMid)
        sketchOutline(ctx, headPath, &rng)

        // 下巴与胸口
        tint(ctx, chestPath, cream, 0.96)
        hatch(ctx, chestPath, &rng, color: creamShade, angle: -0.9, spacing: 7, width: 2.4, alpha: 0.26)
        shade(ctx, chestPath, &rng, offset: CGSize(width: -24, height: -20), color: creamShade, alpha: 0.42)
        fur(ctx, chestPath, &rng, color: creamShade, count: 260, alpha: 0.3)
        fuzzyEdge(ctx, chestPath, &rng, color: creamShade)
        sketchOutline(ctx, chestPath, &rng, color: Color(0.55, 0.52, 0.36), alpha: 0.5)
    }

    private static func drawFace(_ ctx: CGContext, _ rng: inout RNG) {
        // 腮红
        for center in [CGPoint(x: 408, y: 388), CGPoint(x: 718, y: 374)] {
            let cheek = CGPath(ellipseIn: CGRect(x: center.x - 44, y: center.y - 22, width: 88, height: 44), transform: nil)
            hatch(ctx, cheek, &rng, color: blush, angle: -0.8, spacing: 4.5, width: 2.4, alpha: 0.55)
        }
        // 眼睛
        for center in [CGPoint(x: 478, y: 318), CGPoint(x: 648, y: 308)] {
            let eye = CGPath(ellipseIn: CGRect(x: center.x - 25, y: center.y - 28, width: 50, height: 56), transform: nil)
            tint(ctx, eye, graphite, 0.9)
            hatch(ctx, eye, &rng, color: graphite, angle: -0.7, spacing: 3, width: 2.4, alpha: 0.8)
            sketchOutline(ctx, eye, &rng, color: graphite, alpha: 0.9, passes: 2, jitter: 1.2)
            ctx.setFillColor(CGColor(srgbRed: 1, green: 0.99, blue: 0.95, alpha: 0.95))
            ctx.fillEllipse(in: CGRect(x: center.x - 12, y: center.y - 17, width: 13, height: 13))
        }
        // 鼻孔
        for center in [CGPoint(x: 546, y: 370), CGPoint(x: 590, y: 366)] {
            ctx.setFillColor(graphite.cg(0.65))
            ctx.fillEllipse(in: CGRect(x: center.x - 5, y: center.y - 4, width: 10, height: 8))
        }
        // 波浪形的笑嘴
        let mouth = CGMutablePath()
        mouth.move(to: CGPoint(x: 500, y: 404))
        mouth.addCurve(to: CGPoint(x: 568, y: 410), control1: CGPoint(x: 520, y: 432), control2: CGPoint(x: 552, y: 432))
        mouth.addCurve(to: CGPoint(x: 638, y: 398), control1: CGPoint(x: 588, y: 430), control2: CGPoint(x: 624, y: 426))
        for _ in 0..<3 {
            strokeSketch(ctx, flatten(mouth), &rng, color: graphite, width: 3.2, alpha: 0.75, jitter: 1.4)
        }
    }

    // MARK: - 铅笔笔触

    /// 平铺一层淡色打底, 让颜色在小尺寸下仍然可辨
    private static func tint(_ ctx: CGContext, _ path: CGPath, _ color: Color, _ alpha: CGFloat) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setFillColor(color.cg(alpha))
        ctx.fillPath()
        ctx.restoreGState()
    }

    /// 平行排线, 每条线分成长短不一的笔画并带轻微抖动
    private static func hatch(
        _ ctx: CGContext, _ path: CGPath, _ rng: inout RNG,
        color: Color, angle: CGFloat, spacing: CGFloat, width: CGFloat, alpha: CGFloat
    ) {
        let box = path.boundingBoxOfPath.insetBy(dx: -20, dy: -20)
        let center = CGPoint(x: box.midX, y: box.midY)
        let radius = hypot(box.width, box.height) / 2
        let direction = CGPoint(x: cos(angle), y: sin(angle))
        let normal = CGPoint(x: -direction.y, y: direction.x)
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.setLineCap(.round)
        var offset = -radius
        while offset < radius {
            var t = -radius + rng.next() * 30
            while t < radius {
                let length = 50 + rng.next() * 150
                let a = CGPoint(x: center.x + normal.x * offset + direction.x * t, y: center.y + normal.y * offset + direction.y * t)
                let b = CGPoint(x: a.x + direction.x * length, y: a.y + direction.y * length)
                let bend = rng.signed() * 3
                ctx.move(to: a)
                ctx.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2 + normal.x * bend, y: (a.y + b.y) / 2 + normal.y * bend))
                ctx.setStrokeColor(color.varied(&rng).cg(alpha * (0.6 + rng.next() * 0.5)))
                ctx.setLineWidth(width * (0.7 + rng.next() * 0.6))
                ctx.strokePath()
                t += length + rng.next() * 16
            }
            offset += spacing * (0.8 + rng.next() * 0.4)
        }
        ctx.restoreGState()
    }

    /// 背光一侧的交叉排线: 形状减去向光源方向平移后的自身
    private static func shade(_ ctx: CGContext, _ path: CGPath, _ rng: inout RNG, offset: CGSize, color: Color, alpha: CGFloat) {
        let shifted = path.copy(using: [CGAffineTransform(translationX: offset.width, y: offset.height)])!
        let region = path.subtracting(shifted)
        hatch(ctx, region, &rng, color: color, angle: -0.7, spacing: 5, width: 2.4, alpha: alpha)
        hatch(ctx, region, &rng, color: color, angle: 0.6, spacing: 7, width: 2, alpha: alpha * 0.7)
    }

    /// 布偶毛圈: 形状内随机分布的小线圈
    private static func fur(_ ctx: CGContext, _ path: CGPath, _ rng: inout RNG, color: Color, count: Int, alpha: CGFloat) {
        let box = path.boundingBoxOfPath
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.setLineCap(.round)
        var placed = 0
        var attempts = 0
        while placed < count && attempts < count * 20 {
            attempts += 1
            let center = CGPoint(x: box.minX + rng.next() * box.width, y: box.minY + rng.next() * box.height)
            guard path.contains(center) else { continue }
            placed += 1
            let radius = 4 + rng.next() * 5
            let turns = 1.3 + rng.next() * 1.4
            let drift = CGPoint(x: rng.signed() * 2.2, y: rng.signed() * 2.2)
            let start = rng.next() * 2 * .pi
            let steps = 18
            for i in 0...steps {
                let t = CGFloat(i) / CGFloat(steps) * turns * 2 * .pi
                let p = CGPoint(
                    x: center.x + cos(start + t) * radius + drift.x * t,
                    y: center.y + sin(start + t) * radius * 0.8 + drift.y * t
                )
                if i == 0 { ctx.move(to: p) } else { ctx.addLine(to: p) }
            }
            ctx.setStrokeColor(color.varied(&rng).cg(alpha * (0.5 + rng.next() * 0.6)))
            ctx.setLineWidth(1.4 + rng.next() * 1.2)
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    /// 毛绒边缘: 沿轮廓向外的短毛
    private static func fuzzyEdge(_ ctx: CGContext, _ path: CGPath, _ rng: inout RNG, color: Color) {
        let points = flatten(path)
        guard points.count > 2 else { return }
        ctx.saveGState()
        ctx.setLineCap(.round)
        var index = 0
        while index < points.count - 1 {
            let p = points[index]
            let q = points[min(index + 1, points.count - 1)]
            let tangent = CGPoint(x: q.x - p.x, y: q.y - p.y)
            let length = max(hypot(tangent.x, tangent.y), 0.001)
            var normal = CGPoint(x: -tangent.y / length, y: tangent.x / length)
            // 法线朝外: 外侧一点不在形状内
            if path.contains(CGPoint(x: p.x + normal.x * 6, y: p.y + normal.y * 6)) {
                normal = CGPoint(x: -normal.x, y: -normal.y)
            }
            let hair = 5 + rng.next() * 9
            let lean = rng.signed() * 0.6
            let end = CGPoint(
                x: p.x + (normal.x + tangent.x / length * lean) * hair,
                y: p.y + (normal.y + tangent.y / length * lean) * hair
            )
            let start = CGPoint(x: p.x - normal.x * 3, y: p.y - normal.y * 3)
            ctx.move(to: start)
            ctx.addLine(to: end)
            ctx.setStrokeColor(color.varied(&rng).cg(0.35 + rng.next() * 0.3))
            ctx.setLineWidth(1.4 + rng.next() * 1.2)
            ctx.strokePath()
            index += 1 + Int(rng.next() * 2)
        }
        ctx.restoreGState()
    }

    /// 高光处用纸色轻轻擦出
    private static func highlight(_ ctx: CGContext, _ path: CGPath, _ rng: inout RNG) {
        hatch(ctx, path, &rng, color: Color(0.98, 0.97, 0.88), angle: -0.7, spacing: 7, width: 2.6, alpha: 0.35)
    }

    /// 轮廓: 多遍抖动描线
    private static func sketchOutline(
        _ ctx: CGContext, _ path: CGPath, _ rng: inout RNG,
        color: Color = outline, alpha: CGFloat = 0.75, passes: Int = 3, jitter: CGFloat = 2.4
    ) {
        let points = flatten(path)
        for pass in 0..<passes {
            strokeSketch(ctx, points, &rng, color: color, width: pass == 0 ? 3.4 : 2.2, alpha: alpha * (pass == 0 ? 1 : 0.55), jitter: jitter)
        }
    }

    /// 沿折线描一遍, 用低频噪声模拟手绘偏移, 并随机断开成几段
    private static func strokeSketch(
        _ ctx: CGContext, _ points: [CGPoint], _ rng: inout RNG,
        color: Color, width: CGFloat, alpha: CGFloat, jitter: CGFloat
    ) {
        guard points.count > 1 else { return }
        ctx.saveGState()
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let phaseX = rng.next() * 10
        let phaseY = rng.next() * 10
        var drawing = false
        for (index, point) in points.enumerated() {
            let t = CGFloat(index) * 0.08
            let p = CGPoint(
                x: point.x + (sin(t + phaseX) + 0.5 * sin(2.3 * t + phaseY)) * jitter,
                y: point.y + (cos(t * 1.1 + phaseY) + 0.5 * sin(1.7 * t + phaseX)) * jitter
            )
            if !drawing {
                ctx.move(to: p)
                drawing = true
            } else {
                ctx.addLine(to: p)
            }
            if rng.next() < 0.012 {
                ctx.setStrokeColor(color.cg(alpha * (0.7 + rng.next() * 0.3)))
                ctx.setLineWidth(width * (0.8 + rng.next() * 0.4))
                ctx.strokePath()
                drawing = false
            }
        }
        if drawing {
            ctx.setStrokeColor(color.cg(alpha))
            ctx.setLineWidth(width)
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    /// 把路径展开为间距约 4 像素的折线
    private static func flatten(_ path: CGPath) -> [CGPoint] {
        var result: [CGPoint] = []
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero
        path.applyWithBlock { element in
            let e = element.pointee
            switch e.type {
            case .moveToPoint:
                current = e.points[0]
                subpathStart = current
                result.append(current)
            case .addLineToPoint:
                result += line(from: current, to: e.points[0])
                current = e.points[0]
            case .addQuadCurveToPoint:
                result += quad(from: current, control: e.points[0], to: e.points[1])
                current = e.points[1]
            case .addCurveToPoint:
                result += cubic(from: current, e.points[0], e.points[1], to: e.points[2])
                current = e.points[2]
            case .closeSubpath:
                result += line(from: current, to: subpathStart)
                current = subpathStart
            @unknown default:
                break
            }
        }
        return result
    }

    private static func line(from start: CGPoint, to end: CGPoint) -> [CGPoint] {
        let count = max(1, Int(hypot(end.x - start.x, end.y - start.y) / 4))
        return (1...count).map { i in
            let t = CGFloat(i) / CGFloat(count)
            return CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t)
        }
    }

    private static func quad(from start: CGPoint, control: CGPoint, to end: CGPoint) -> [CGPoint] {
        (1...40).map { i in
            let t = CGFloat(i) / 40
            let u = 1 - t
            let x: CGFloat = u * u * start.x + 2 * u * t * control.x + t * t * end.x
            let y: CGFloat = u * u * start.y + 2 * u * t * control.y + t * t * end.y
            return CGPoint(x: x, y: y)
        }
    }

    private static func cubic(from start: CGPoint, _ c1: CGPoint, _ c2: CGPoint, to end: CGPoint) -> [CGPoint] {
        (1...60).map { i in
            let t = CGFloat(i) / 60
            let u = 1 - t
            let a: CGFloat = u * u * u
            let b: CGFloat = 3 * u * u * t
            let c: CGFloat = 3 * u * t * t
            let d: CGFloat = t * t * t
            let x: CGFloat = a * start.x + b * c1.x + c * c2.x + d * end.x
            let y: CGFloat = a * start.y + b * c1.y + c * c2.y + d * end.y
            return CGPoint(x: x, y: y)
        }
    }

    // MARK: - 画布

    private static func draw(_ body: (CGContext, inout RNG) -> Void) -> CGImage {
        let ctx = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        ctx.translateBy(x: 0, y: CGFloat(size))
        ctx.scaleBy(x: 1, y: -1)
        var rng = RNG(seed: 88172645)
        body(ctx, &rng)
        return ctx.makeImage()!
    }

    struct Color {
        let r: CGFloat, g: CGFloat, b: CGFloat

        init(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) {
            self.r = r
            self.g = g
            self.b = b
        }

        func cg(_ alpha: CGFloat) -> CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: alpha) }

        /// 每一笔的颜色略有深浅, 模拟彩铅的不均匀
        func varied(_ rng: inout RNG) -> Color {
            let k = 0.9 + rng.next() * 0.2
            return Color(min(r * k, 1), min(g * k, 1), min(b * k, 1))
        }
    }

    /// 固定种子的随机数, 每次渲染结果一致
    struct RNG {
        private var state: UInt64

        init(seed: UInt64) { state = seed }

        mutating func next() -> CGFloat {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return CGFloat(state % 1_000_000) / 1_000_000
        }

        mutating func signed() -> CGFloat { next() * 2 - 1 }
    }
}
