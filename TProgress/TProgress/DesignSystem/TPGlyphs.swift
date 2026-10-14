import SwiftUI

// MARK: - Glyph canvas
//
// Every glyph is authored in a unit square and scaled to fit, so a glyph keeps
// its proportions in a 22pt dock slot and in a 40pt empty state alike.

struct GlyphCanvas {

    let originX: CGFloat
    let originY: CGFloat
    let side: CGFloat

    init(_ rect: CGRect) {
        let s = min(rect.width, rect.height)
        side = s
        originX = rect.minX + (rect.width - s) / 2
        originY = rect.minY + (rect.height - s) / 2
    }

    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: originX + x * side, y: originY + y * side)
    }

    func v(_ value: CGFloat) -> CGFloat { value * side }
}

// MARK: - Dock glyphs

/// Today — a sun breaking over the line you drew yesterday. No rays: at dock
/// size a single clean arc reads faster than spokes.
struct GlyphToday: Shape {

    func path(in rect: CGRect) -> Path {
        let c = GlyphCanvas(rect)
        var path = Path()

        path.move(to: c.p(0.10, 0.74))
        path.addLine(to: c.p(0.90, 0.74))

        path.addArc(
            center: c.p(0.50, 0.74),
            radius: c.v(0.27),
            startAngle: .degrees(180),
            endAngle: .degrees(360),
            clockwise: false
        )

        return path
    }
}

/// Circles — three interlocking rings; a habit only holds when it overlaps life.
struct GlyphCircles: Shape {

    func path(in rect: CGRect) -> Path {
        let c = GlyphCanvas(rect)
        var path = Path()

        for center in [CGPoint(x: 0.36, y: 0.40), CGPoint(x: 0.64, y: 0.40), CGPoint(x: 0.50, y: 0.68)] {
            path.addEllipse(in: CGRect(
                x: c.p(center.x, center.y).x - c.v(0.21),
                y: c.p(center.x, center.y).y - c.v(0.21),
                width: c.v(0.42),
                height: c.v(0.42)
            ))
        }

        return path
    }
}

/// Create — an ember spark, four points drawn with concave shoulders.
struct GlyphSpark: Shape {

    func path(in rect: CGRect) -> Path {
        let c = GlyphCanvas(rect)
        var path = Path()

        let top = c.p(0.50, 0.06)
        let right = c.p(0.94, 0.50)
        let bottom = c.p(0.50, 0.94)
        let left = c.p(0.06, 0.50)

        path.move(to: top)
        path.addQuadCurve(to: right, control: c.p(0.575, 0.425))
        path.addQuadCurve(to: bottom, control: c.p(0.575, 0.575))
        path.addQuadCurve(to: left, control: c.p(0.425, 0.575))
        path.addQuadCurve(to: top, control: c.p(0.425, 0.425))
        path.closeSubpath()

        return path
    }
}

/// Chats — a speech bubble whose tail is cut on the left, not the usual right.
struct GlyphChats: Shape {

    func path(in rect: CGRect) -> Path {
        let c = GlyphCanvas(rect)
        var path = Path()

        path.move(to: c.p(0.28, 0.12))
        path.addLine(to: c.p(0.72, 0.12))
        path.addQuadCurve(to: c.p(0.92, 0.32), control: c.p(0.92, 0.12))
        path.addLine(to: c.p(0.92, 0.50))
        path.addQuadCurve(to: c.p(0.72, 0.70), control: c.p(0.92, 0.70))
        path.addLine(to: c.p(0.54, 0.70))
        path.addLine(to: c.p(0.34, 0.90))
        path.addLine(to: c.p(0.31, 0.70))
        path.addLine(to: c.p(0.28, 0.70))
        path.addQuadCurve(to: c.p(0.08, 0.50), control: c.p(0.08, 0.70))
        path.addLine(to: c.p(0.08, 0.32))
        path.addQuadCurve(to: c.p(0.28, 0.12), control: c.p(0.08, 0.12))
        path.closeSubpath()

        return path
    }
}

/// Me — a figure reduced to a head and an arch.
struct GlyphMe: Shape {

    func path(in rect: CGRect) -> Path {
        let c = GlyphCanvas(rect)
        var path = Path()

        path.addEllipse(in: CGRect(
            x: c.p(0.50, 0.30).x - c.v(0.165),
            y: c.p(0.50, 0.30).y - c.v(0.165),
            width: c.v(0.33),
            height: c.v(0.33)
        ))

        path.move(to: c.p(0.13, 0.88))
        path.addQuadCurve(to: c.p(0.87, 0.88), control: c.p(0.50, 0.40))

        return path
    }
}

// MARK: - Brand mark

/// The app mark: a rising line ending in a spark, over a baseline.
struct TPMark: Shape {

    var showsBaseline: Bool = true

    func path(in rect: CGRect) -> Path {
        let c = GlyphCanvas(rect)
        var path = Path()

        if showsBaseline {
            path.move(to: c.p(0.08, 0.88))
            path.addLine(to: c.p(0.92, 0.88))
        }

        path.move(to: c.p(0.16, 0.78))
        path.addQuadCurve(to: c.p(0.60, 0.36), control: c.p(0.42, 0.70))

        // Spark at the crest of the rise.
        let cx: CGFloat = 0.74, cy: CGFloat = 0.24, r: CGFloat = 0.15
        path.move(to: c.p(cx, cy - r))
        path.addQuadCurve(to: c.p(cx + r, cy), control: c.p(cx + r * 0.22, cy - r * 0.22))
        path.addQuadCurve(to: c.p(cx, cy + r), control: c.p(cx + r * 0.22, cy + r * 0.22))
        path.addQuadCurve(to: c.p(cx - r, cy), control: c.p(cx - r * 0.22, cy + r * 0.22))
        path.addQuadCurve(to: c.p(cx, cy - r), control: c.p(cx - r * 0.22, cy - r * 0.22))

        return path
    }
}

// MARK: - Decorative shapes

/// Concentric arcs used as a backdrop behind hero content.
struct TPArcField: Shape {

    var rings: Int = 5
    var sweep: Double = 0.62

    func path(in rect: CGRect) -> Path {
        let c = GlyphCanvas(rect)
        var path = Path()

        for index in 0..<rings {
            let radius = c.v(0.16 + 0.16 * CGFloat(index))
            path.addArc(
                center: c.p(0.5, 0.86),
                radius: radius,
                startAngle: .degrees(180),
                endAngle: .degrees(180 + 180 * sweep),
                clockwise: false
            )
        }

        return path
    }
}

/// A strip of ticks. Filled ticks are days you showed up.
struct TPTickStrip: Shape {

    var total: Int
    var filled: Int
    var tickWidth: CGFloat = 0.45

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard total > 0 else { return path }

        let slot = rect.width / CGFloat(total)
        let width = slot * tickWidth
        let filledCount = min(max(filled, 0), total)

        for index in 0..<filledCount {
            let x = rect.minX + slot * CGFloat(index) + (slot - width) / 2
            path.addRoundedRect(
                in: CGRect(x: x, y: rect.minY, width: width, height: rect.height),
                cornerSize: CGSize(width: width / 2, height: width / 2)
            )
        }

        return path
    }
}

/// A four point burst used for the like burst and gift celebration.
struct TPBurst: Shape {

    var points: Int = 8
    var innerRatio: CGFloat = 0.42

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        let step = Double.pi * 2 / Double(points * 2)

        for index in 0..<(points * 2) {
            let radius = index.isMultiple(of: 2) ? outer : inner
            let angle = step * Double(index) - Double.pi / 2
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Convenience views

/// Stroked glyph at a given size — the dock and inline affordances use this.
struct TPGlyph<S: Shape>: View {

    let shape: S
    var size: CGFloat = 22
    var lineWidth: CGFloat = 1.7
    var color: Color = .tpCream

    var body: some View {
        shape
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
    }
}
