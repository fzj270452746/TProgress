import SwiftUI
import UIKit

// MARK: - Avatar
//
// Identities are generated, not downloaded. A seed picks the accent pair and one
// of five sigils; the monogram sits on top. Circular with a gradient ring, which
// is the shape every contact in the reference boards wears. Swapping in real
// photography later means changing this one view.

struct TPAvatar: View {

    var seed: Int64
    var name: String
    var size: CGFloat
    var showsRing: Bool = false
    var ringColor: Color?
    /// A stored photo replaces the generated sigil when one exists.
    var imagePath: String? = nil
    /// The green presence dot the reference puts on every contact row.
    var showsPresence: Bool = false

    private var accentA: Color { .tpAccent(seed: seed) }
    private var accentB: Color { .tpAccent(Int(truncatingIfNeeded: seed) &+ 2) }

    private var monogram: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.first.map { String($0).uppercased() } ?? "?"
    }

    private var photo: UIImage? {
        TPIconResolver.image(pathOrName: imagePath)
    }

    private var ringWidth: CGFloat { max(2, size * 0.045) }

    /// The ring is the identity: a warm-to-cool sweep that reads as a lit rim
    /// rather than a border, matching the reference's per-contact ring colours.
    private var ringStyle: AnyShapeStyle {
        if let ringColor { return AnyShapeStyle(ringColor) }
        return AnyShapeStyle(
            LinearGradient(
                colors: [.tpSun, .tpEmber, .tpBloom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [accentA, accentB],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                TPSigil(seed: seed)
                    .fill(Color.white.opacity(0.26))

                Text(monogram)
                    .font(.system(size: size * 0.44, weight: .heavy))
                    .foregroundColor(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
        )
        .overlay {
            if showsRing {
                Circle()
                    .strokeBorder(ringStyle, lineWidth: ringWidth)
                    .padding(-(ringWidth * 1.9))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if showsPresence {
                Circle()
                    .fill(Color.tpMint)
                    .overlay(
                        Circle().strokeBorder(Color(hex: 0x1B0B3A), lineWidth: max(2, size * 0.05))
                    )
                    .frame(width: size * 0.28, height: size * 0.28)
            }
        }
        .shadow(color: accentA.opacity(0.40), radius: size * 0.20, y: size * 0.07)
    }
}

/// Five deterministic sigils, chosen by seed.
struct TPSigil: Shape {

    var seed: Int64

    func path(in rect: CGRect) -> Path {
        var generator = SeededGenerator(seed: seed)
        let variant = Int(seed % 5 + 5) % 5
        var path = Path()

        switch variant {
        case 0:
            // Concentric arcs rising from the lower left.
            for index in 0..<4 {
                let radius = rect.width * (0.22 + 0.16 * CGFloat(index))
                path.addArc(
                    center: CGPoint(x: rect.minX, y: rect.maxY),
                    radius: radius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(0),
                    clockwise: false
                )
            }
        case 1:
            // Diagonal hatch.
            let step = rect.width / 5
            for index in -3...6 {
                let offset = step * CGFloat(index)
                path.move(to: CGPoint(x: rect.minX + offset, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.minX + offset + rect.height, y: rect.minY))
            }
        case 2:
            // Dot grid with a diagonal bias.
            let columns = 5
            let cell = rect.width / CGFloat(columns)
            for row in 0..<columns {
                for column in 0..<columns {
                    guard (row + column) % 2 == 0 else { continue }
                    let jitter = CGFloat.random(in: -0.12...0.12, using: &generator) * cell
                    let center = CGPoint(
                        x: rect.minX + cell * (CGFloat(column) + 0.5) + jitter,
                        y: rect.minY + cell * (CGFloat(row) + 0.5) + jitter
                    )
                    let radius = cell * 0.17
                    path.addEllipse(in: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))
                }
            }
        case 3:
            // Nested rotated squares.
            for index in 0..<3 {
                let inset = rect.width * (0.10 + 0.16 * CGFloat(index))
                let frame = rect.insetBy(dx: inset, dy: inset)
                let corner = frame.width * 0.28
                path.addPath(
                    Path(roundedRect: frame, cornerRadius: corner, style: .continuous)
                )
            }
        default:
            // Overlapping discs.
            for index in 0..<3 {
                let radius = rect.width * 0.30
                let center = CGPoint(
                    x: rect.midX + CGFloat(index - 1) * rect.width * 0.24,
                    y: rect.midY + CGFloat(index % 2 == 0 ? -1 : 1) * rect.height * 0.12
                )
                path.addEllipse(in: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                ))
            }
        }

        return path
    }
}

// MARK: - Procedural media
//
// Stand-in artwork for post media. Reads as abstract editorial art rather than a
// grey box, so the feed looks finished before a single asset is dropped in.

struct TPArt: View {

    var seed: Int64
    var cornerRadius: CGFloat = 0
    var showsGrain: Bool = true

    private var accentA: Color { .tpAccent(seed: seed) }
    private var accentB: Color { .tpAccent(Int(truncatingIfNeeded: seed) &+ 3) }
    private var accentC: Color { .tpAccent(Int(truncatingIfNeeded: seed) &+ 1) }
    private var accentD: Color { .tpAccent(Int(truncatingIfNeeded: seed) &+ 4) }

    /// Stable horizontal drift so repeated art does not stack identically.
    private var drift: CGFloat {
        var generator = SeededGenerator(seed: seed &+ 17)
        return CGFloat.random(in: -0.10...0.10, using: &generator)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                // Two accent hues anchored to a deep violet. The art has to sit
                // *on* a gradient backdrop, so it always ends in a colour the
                // backdrops never use — otherwise a post's image dissolves into
                // the page and the card stops reading as an object.
                LinearGradient(
                    colors: [
                        accentA,
                        accentB,
                        Color(hex: 0x2A0F55)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                TPWaveBands(seed: seed)
                    .fill(Color.white.opacity(0.20))

                // Outlined geometry rather than filled shapes: crisp lines read
                // as deliberate graphic art, where a filled wash reads as blur.
                TPSigil(seed: seed &* 13 &+ 5)
                    .fill(Color.black.opacity(0.16))
                    .scaleEffect(1.15)
                    .offset(x: -size.width * drift * 0.7)

                TPSigil(seed: seed &* 7 &+ 3)
                    .stroke(
                        Color.white.opacity(0.42),
                        style: StrokeStyle(lineWidth: 1.8, lineJoin: .round)
                    )
                    .scaleEffect(1.45)
                    .rotationEffect(.degrees(Double(Int(seed % 41)) - 20))
                    .offset(x: size.width * drift, y: size.height * 0.04)

                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.34)],
                    center: .center,
                    startRadius: size.width * 0.24,
                    endRadius: size.width * 0.78
                )

                if showsGrain {
                    TPGrain(opacity: 0.06)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Smooth horizontal bands whose crests drift with the seed.
struct TPWaveBands: Shape {

    var seed: Int64
    var bandCount: Int = 4

    func path(in rect: CGRect) -> Path {
        var generator = SeededGenerator(seed: seed &+ 991)
        var path = Path()

        for index in 0..<bandCount {
            let baseY = rect.maxY * (0.42 + 0.16 * CGFloat(index))
            let amplitude = rect.height * CGFloat.random(in: 0.05...0.13, using: &generator)
            let phase = CGFloat.random(in: 0...1, using: &generator)

            path.move(to: CGPoint(x: rect.minX, y: baseY))
            path.addCurve(
                to: CGPoint(x: rect.maxX, y: baseY + amplitude * 0.4),
                control1: CGPoint(x: rect.width * (0.25 + phase * 0.3), y: baseY - amplitude),
                control2: CGPoint(x: rect.width * (0.62 + phase * 0.2), y: baseY + amplitude * 1.6)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }

        return path
    }
}

// MARK: - Media frame
//
// The single substitution point for real assets: hand `TPMediaFrame` an asset
// name and it renders the file; without one it falls back to generated art.

struct TPMediaFrame: View {

    var assetName: String?
    var seed: Int64
    var cornerRadius: CGFloat = 0
    var contentMode: ContentMode = .fill

    var body: some View {
        Group {
            if let assetName, !assetName.isEmpty, UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if let assetName, !assetName.isEmpty, FileManager.default.fileExists(atPath: assetName) {
                if let image = UIImage(contentsOfFile: assetName) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                } else {
                    TPArt(seed: seed, cornerRadius: cornerRadius)
                }
            } else {
                TPArt(seed: seed, cornerRadius: cornerRadius)
            }
        }
    }
}
