import SwiftUI

// MARK: - Tab glyph
//
// One switch so the dock, the empty states and the headers all draw the same
// shapes at the same weight.

struct TabGlyph: View {

    let tab: AppTab
    var color: Color
    var size: CGFloat = 22
    var lineWidth: CGFloat = 1.7

    /// Overrides `color` when set. The dock's active destination passes the
    /// action gradient here so the glyph reads as a lit object rather than a
    /// tinted outline.
    var style: AnyShapeStyle?

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
    }

    private var paint: AnyShapeStyle { style ?? AnyShapeStyle(color) }

    var body: some View {
        Group {
            switch tab {
            case .today:
                GlyphToday().stroke(paint, style: strokeStyle)
            case .circles:
                GlyphCircles().stroke(paint, style: strokeStyle)
            case .chats:
                GlyphChats().stroke(paint, style: strokeStyle)
            case .me:
                GlyphMe().stroke(paint, style: strokeStyle)
            case .create:
                GlyphSpark().fill(paint)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Bar shape
//
// The reference bar is a rounded slab with a scoop cut out of its top edge for
// the raised centre button. Built from two quad curves rather than an arc so
// the direction of the sweep can't flip with the coordinate space.

struct TPDockBarShape: Shape {

    var radius: CGFloat = 30
    var notch: CGFloat = 38

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(radius, rect.height / 2)
        let n = min(notch, rect.width / 4)
        let cx = rect.midX
        let depth = n * 0.66

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + r, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )

        // Left shoulder → the scoop → right shoulder.
        path.addLine(to: CGPoint(x: cx - n, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: cx, y: rect.minY + depth),
            control: CGPoint(x: cx - n * 0.58, y: rect.minY)
        )
        path.addQuadCurve(
            to: CGPoint(x: cx + n, y: rect.minY),
            control: CGPoint(x: cx + n * 0.58, y: rect.minY)
        )

        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + r),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Dock
//
// The bar from the reference boards: four labelled destinations riding on frosted
// glass, with the create action as a lit sphere nested into the notch. The
// destination glyph takes the action gradient when it is active, and the label
// goes to full white — the bar itself never changes shape.

struct TPDock: View {

    @Binding var selection: AppTab
    let onCreate: () -> Void

    private var destinations: [AppTab] { AppTab.destinations }

    private let barHeight: CGFloat = 62
    private let sphereSize: CGFloat = 64
    private let notchRadius: CGFloat = 38

    var body: some View {
        ZStack(alignment: .top) {
            bar
                .frame(height: barHeight)

            // The centre column is reserved for the Post sphere. The
            // destinations are otherwise spread evenly across the whole bar,
            // which parks Circles and Chats on the sphere's shoulders — 0.6pt
            // of air at 393pt wide. Reserving the notch's own width keeps them
            // clear of it and matches the scoop cut out of the bar behind.
            HStack(spacing: 0) {
                ForEach(Array(destinations.enumerated()), id: \.element) { index, tab in
                    if index == destinations.count / 2 {
                        Color.clear.frame(width: notchRadius * 2)
                    }
                    slot(tab)
                }
            }
            .frame(height: barHeight)
            .padding(.horizontal, 8)

            createButton
                .offset(y: -(sphereSize / 2) + 12)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 2)
    }

    // MARK: Bar

    private var bar: some View {
        let shape = TPDockBarShape(radius: 30, notch: notchRadius)

        return ZStack {
            shape.fill(.ultraThinMaterial)
            shape.fill(Color.white.opacity(0.12))
            shape.stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.42), Color.white.opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
        .compositingGroup()
        .shadow(color: Color(hex: 0x1B0B3A).opacity(0.42), radius: 26, x: 0, y: 12)
    }

    // MARK: Slots

    private func slot(_ tab: AppTab) -> some View {
        let isActive = selection == tab

        return Button(action: {
            // The router decides what a tap means; re-tapping the active
            // destination returns that tab to its root.
            selection = tab
        }) {
            VStack(spacing: 3) {
                TabGlyph(
                    tab: tab,
                    color: isActive ? .tpCream : .tpCreamFaint,
                    size: 23,
                    lineWidth: isActive ? 2.1 : 1.6,
                    style: isActive ? AnyShapeStyle(TPGradient.ember) : nil
                )
                .shadow(
                    color: isActive ? Color.tpEmber.opacity(0.55) : .clear,
                    radius: 9
                )

                Text(tab.label)
                    .font(.system(size: 10, weight: isActive ? .bold : .semibold))
                    .foregroundColor(isActive ? .tpCream : .tpCreamFaint)
            }
            .frame(maxWidth: .infinity)
            .frame(height: barHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Create

    private var createButton: some View {
        Button(action: {
            TPHaptic.thump()
            onCreate()
        }) {
            ZStack {
                Circle()
                    .fill(TPGradient.sphere)
                    .frame(width: sphereSize, height: sphereSize)
                    .tpEmberGlow(.tpEmber, strength: 0.6)

                // Gloss: a soft highlight across the top-left, so the sphere
                // reads as a lit ball the way the reference's does.
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55), Color.white.opacity(0.0)],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .frame(width: sphereSize * 0.72, height: sphereSize * 0.72)
                    .offset(x: -sphereSize * 0.10, y: -sphereSize * 0.14)
                    .blur(radius: 3)

                Circle()
                    .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
                    .frame(width: sphereSize, height: sphereSize)

                VStack(spacing: -1) {
                    Image(systemName: "plus")
                        .font(.system(size: 19, weight: .heavy))
                    Text("Post")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.tpOnAccent)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New post")
    }
}
