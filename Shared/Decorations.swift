import SwiftUI

// MARK: - 装饰图形

/// 一朵云, 设计比例为 2:1
struct Cloud: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> CGRect {
            CGRect(x: rect.minX + x * w - r * h, y: rect.minY + y * h - r * h, width: 2 * r * h, height: 2 * r * h)
        }
        var path = Path()
        path.addRoundedRect(
            in: CGRect(x: rect.minX + 0.06 * w, y: rect.minY + 0.5 * h, width: 0.88 * w, height: 0.5 * h),
            cornerSize: CGSize(width: 0.25 * h, height: 0.25 * h)
        )
        path.addEllipse(in: circle(0.3, 0.58, 0.3))
        path.addEllipse(in: circle(0.56, 0.44, 0.42))
        path.addEllipse(in: circle(0.79, 0.64, 0.28))
        return path
    }
}

/// 四角星闪光
struct Twinkle: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let rx = rect.width / 2
        let ry = rect.height / 2
        let pinch: CGFloat = 0.14
        let top = CGPoint(x: c.x, y: c.y - ry)
        let right = CGPoint(x: c.x + rx, y: c.y)
        let bottom = CGPoint(x: c.x, y: c.y + ry)
        let left = CGPoint(x: c.x - rx, y: c.y)
        var path = Path()
        path.move(to: top)
        path.addQuadCurve(to: right, control: CGPoint(x: c.x + rx * pinch, y: c.y - ry * pinch))
        path.addQuadCurve(to: bottom, control: CGPoint(x: c.x + rx * pinch, y: c.y + ry * pinch))
        path.addQuadCurve(to: left, control: CGPoint(x: c.x - rx * pinch, y: c.y + ry * pinch))
        path.addQuadCurve(to: top, control: CGPoint(x: c.x - rx * pinch, y: c.y - ry * pinch))
        path.closeSubpath()
        return path
    }
}

/// 弯月
struct Crescent: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let disc = CGRect(x: rect.midX - side / 2, y: rect.midY - side / 2, width: side, height: side)
        let bite = disc.offsetBy(dx: side * 0.34, dy: -side * 0.2)
        return Path(ellipseIn: disc).subtracting(Path(ellipseIn: bite))
    }
}
