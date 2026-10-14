import SwiftUI
import UIKit

// MARK: - Palette
//
// "Prism" — a vivid gradient-and-glass system. Every screen sits on a
// saturated multi-stop gradient, and everything laid on top of it is frosted
// glass: a blur, a thin wash of white, and a light-catching border. Text is
// pure white so it stays legible against every stop of every backdrop.
//
// The one rule that keeps this coherent: colour lives in the *backdrop* and in
// *action*. Surfaces are never painted a flat opaque colour — they are either
// the gradient showing through, or glass sitting on top of it.

extension Color {

    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    // Grounds
    //
    // `tpInk` is no longer a page colour — pages are gradients now. It is the
    // deep violet-black reserved for scrims, media letterboxing and call
    // backgrounds: places that must swallow light rather than carry the brand.
    static let tpInk       = Color(hex: 0x14082B)
    static let tpInkScrim  = Color(hex: 0x1B0E3A)

    // Glass surfaces
    //
    // Translucent whites, layered over `.ultraThinMaterial` by `TPGlassSurface`.
    // The ramp is wide enough that ground → card → well stays legible without
    // any of them looking like a flat grey slab.
    static let tpGlass      = Color.white.opacity(0.14)
    static let tpGlassHigh  = Color.white.opacity(0.22)
    static let tpGlassWell  = Color.white.opacity(0.10)
    static let tpGlassDeep  = Color.white.opacity(0.06)

    /// Retained names from the previous system so surfaces keep compiling.
    /// They now resolve to the glass ramp rather than opaque browns.
    static let tpInkRaised = Color.white.opacity(0.13)
    static let tpInkCard   = Color.white.opacity(0.17)
    static let tpInkWell   = Color.white.opacity(0.10)

    static let tpLine     = Color.white.opacity(0.22)
    static let tpLineSoft = Color.white.opacity(0.12)

    // Text
    //
    // Pure white on the vivid backdrops. Pure — an off-white picks up the
    // gradient underneath and reads as dirty rather than as light.
    static let tpCream      = Color.white
    static let tpCreamDim   = Color.white.opacity(0.80)
    static let tpCreamFaint = Color.white.opacity(0.58)

    /// Text and glyphs that sit *on* a bright accent fill.
    static let tpOnAccent = Color.white

    /// Destructive *text*. Lighter than `tpBloom`, which stays the fill colour
    /// for hearts and likes: a mid-tone pink label disappears the moment it
    /// lands on the warm half of a backdrop.
    static let tpDanger = Color(hex: 0xFF9A9A)

    // Accents — sampled from the reference boards: hot pink primary, with an
    // orange→pink→magenta action gradient, and a saturated supporting ramp.
    static let tpEmber   = Color(hex: 0xFF2E63)
    static let tpEmberHi = Color(hex: 0xFF6B9D)
    static let tpSun     = Color(hex: 0xFFB020)
    static let tpBloom   = Color(hex: 0xE0399E)
    static let tpMint    = Color(hex: 0x22E3A4)
    static let tpLilac   = Color(hex: 0x9B6BFF)
    static let tpSky     = Color(hex: 0x2BB3FF)

    /// The rotating accent ramp used to give habits, avatars and cards
    /// their own identity while staying inside one system.
    static let tpRamp: [Color] = [tpEmber, tpSun, tpMint, tpBloom, tpLilac, tpSky]

    static func tpAccent(_ index: Int) -> Color {
        let count = tpRamp.count
        let safe = ((index % count) + count) % count
        return tpRamp[safe]
    }

    static func tpAccent(seed: Int64) -> Color {
        tpAccent(Int(truncatingIfNeeded: seed))
    }
}

// MARK: - Gradients

enum TPGradient {

    /// The action gradient. Orange → red → hot pink: the "New Chat" button and
    /// the raised Post sphere in the reference boards. Kept deliberately warm,
    /// because every backdrop is cool — the temperature split is what makes an
    /// action read as an action instead of as one more patch of gradient.
    static let ember = LinearGradient(
        colors: [Color(hex: 0xFFA22B), Color(hex: 0xFF5A2E), Color(hex: 0xFF2E63)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let emberSoft = LinearGradient(
        colors: [Color.tpEmber.opacity(0.95), Color.tpBloom.opacity(0.85)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// A glossier take on `ember` for the raised centre button: the reference
    /// sphere reads as a lit object, not a flat pill.
    static let sphere = LinearGradient(
        colors: [Color(hex: 0xFF6FA8), Color(hex: 0xF42A6E), Color(hex: 0xC01578)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Deep gradient used behind scrims and full-bleed media.
    static let ink = LinearGradient(
        colors: [Color.tpInkScrim, Color.tpInk],
        startPoint: .top,
        endPoint: .bottom
    )

    /// The standard surface treatment. Kept as a gradient so existing call
    /// sites keep working. Thicker than a bare glass wash because several of
    /// those sites paint it without a material behind it — at 0.10 the card
    /// disappeared wherever the backdrop happened to be bright.
    static let card = LinearGradient(
        colors: [Color.white.opacity(0.28), Color.white.opacity(0.15)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func accent(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [color, color.opacity(0.62)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// The border recipe used by glass: brightest at the top-left where light
    /// would strike, fading to nearly nothing at the bottom-right.
    static let glassEdge = LinearGradient(
        colors: [Color.white.opacity(0.50), Color.white.opacity(0.14), Color.white.opacity(0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// The neon rail from the reference: a stroke that runs warm → cool around
    /// the container, drawn over a blurred copy of itself for the bloom.
    static let neonRail = LinearGradient(
        colors: [
            Color(hex: 0xFF9A3D),
            Color(hex: 0xFF2E63),
            Color(hex: 0xE0399E),
            Color(hex: 0x8B5CFF),
            Color(hex: 0x2BB3FF),
            Color(hex: 0x22E3A4)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Backdrop

/// One vivid gradient per destination. Each carries its own pair of coloured
/// blooms so the flat linear ramp picks up the soft, lit-from-within quality
/// the reference boards have.
enum TPBackdrop {

    case today
    case circles
    case chats
    case me
    case auth
    /// Deepened variant for form-heavy and pushed pages, where a full-strength
    /// gradient behind text fields would fight the content.
    case deep

    var stops: [Color] {
        switch self {
        case .today:
            return [Color(hex: 0x0A4FD8), Color(hex: 0x5B21C9), Color(hex: 0x8E1FA8), Color(hex: 0x241057)]
        case .circles:
            return [Color(hex: 0x0B7FC4), Color(hex: 0x1D4FE0), Color(hex: 0x6B21C9), Color(hex: 0x1D0F55)]
        case .chats:
            return [Color(hex: 0x6B1F9E), Color(hex: 0x8B1FA0), Color(hex: 0x4A1B8E), Color(hex: 0x190E45)]
        case .me:
            return [Color(hex: 0xC4186B), Color(hex: 0xD4381F), Color(hex: 0x8B1FA8), Color(hex: 0x241055)]
        case .auth:
            return [Color(hex: 0x4A1B9E), Color(hex: 0x7B1FB0), Color(hex: 0x9E1F8E), Color(hex: 0x1B0F4A)]
        case .deep:
            return [Color(hex: 0x3A1580), Color(hex: 0x27105C), Color(hex: 0x1A0A40), Color(hex: 0x12082E)]
        }
    }

    /// Blooms laid over the ramp. `tpSky`/`tpBloom` style accent lights that
    /// keep the large flat areas from reading as a flat CSS gradient.
    var blooms: [(Color, Double, Double, Double)] {
        // (colour, x fraction, y fraction, diameter as a multiple of width)
        switch self {
        case .today:
            return [(Color(hex: 0x2BB3FF), 0.10, 0.06, 1.7),
                    (Color(hex: 0x8B2FE0), 0.96, 0.36, 1.6),
                    (Color(hex: 0x2A1170), 0.30, 1.02, 1.8)]
        case .circles:
            return [(Color(hex: 0x2BB3FF), 0.08, 0.10, 1.6),
                    (Color(hex: 0x6B21C9), 0.95, 0.42, 1.7),
                    (Color(hex: 0x2A1170), 0.40, 1.00, 1.7)]
        case .chats:
            return [(Color(hex: 0xC42DA4), 0.12, 0.10, 1.7),
                    (Color(hex: 0x8B5CFF), 0.95, 0.40, 1.7),
                    (Color(hex: 0x170C40), 0.45, 1.00, 1.7)]
        case .me:
            return [(Color(hex: 0xFF6B2E), 0.10, 0.08, 1.6),
                    (Color(hex: 0xD4187B), 0.95, 0.38, 1.6),
                    (Color(hex: 0x2A1170), 0.35, 1.00, 1.8)]
        case .auth:
            return [(Color(hex: 0xC42DA4), 0.10, 0.10, 1.8),
                    (Color(hex: 0x5B21B6), 0.95, 0.44, 1.8),
                    (Color(hex: 0x1B0F4A), 0.30, 1.00, 1.7)]
        case .deep:
            return [(Color(hex: 0x9B6BFF), 0.10, 0.06, 1.5),
                    (Color(hex: 0x6B1F9E), 0.95, 0.58, 1.4)]
        }
    }

    /// Destination tint, used for the nav bar wash and for content that needs
    /// to know which screen it is on.
    var tint: Color {
        switch self {
        case .today:   return Color(hex: 0x7B2FF7)
        case .circles: return Color(hex: 0x1D6BF5)
        case .chats:   return Color(hex: 0x8A2FB0)
        case .me:      return Color(hex: 0xFF7A2F)
        case .auth:    return Color(hex: 0x8B2FD0)
        case .deep:    return Color(hex: 0x4A1F8E)
        }
    }

    /// Which backdrop a destination wears, so the shell can cross-fade between
    /// them as tabs change instead of snapping.
    static func forTab(_ tab: AppTab) -> TPBackdrop {
        switch tab {
        case .today:   return .today
        case .circles: return .circles
        case .chats:   return .chats
        case .me:      return .me
        case .create:  return .today
        }
    }
}

/// The full-bleed gradient ground every screen sits on.
struct TPBackdropView: View {

    var style: TPBackdrop
    var grain: Double = 0.05

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                LinearGradient(
                    colors: style.stops,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // A second ramp crossing the first, so the ground shifts hue in
                // two directions the way a mesh gradient does.
                LinearGradient(
                    colors: [style.stops[1].opacity(0.55), .clear, style.stops[2].opacity(0.45)],
                    startPoint: .topTrailing,
                    endPoint: .bottomLeading
                )

                ForEach(Array(style.blooms.enumerated()), id: \.offset) { _, bloom in
                    let (color, fx, fy, scale) = bloom
                    let d = w * scale
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [color.opacity(0.55), color.opacity(0.0)],
                                center: .center,
                                startRadius: 0,
                                endRadius: d * 0.5
                            )
                        )
                        .frame(width: d, height: d)
                        .position(x: w * fx, y: h * fy)
                        .blur(radius: d * 0.06)
                }

                TPGrain(opacity: grain)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Halo
//
// The coloured bloom that sits behind hero content. Built as a circle whose
// radial gradient reaches zero alpha exactly at its own edge, so it never
// leaves the rectangular seam that a bare gradient inside a frame would.

/// A decoration must never decide how wide the screen is. Anything drawn at a
/// fixed size larger than the device stretches its parent, which silently
/// collapses every horizontal inset inside it. So the bloom measures its
/// container instead of asserting a size of its own.
struct TPHalo: View {

    var color: Color
    var strength: Double = 0.30

    /// Set only for small decorative blooms that can never exceed the screen.
    var diameter: CGFloat?
    var spread: Double = 1.25

    var body: some View {
        Group {
            if let diameter {
                // A fixed bloom is already smaller than any screen, so it can
                // be laid out normally and stays inside its parent's ZStack.
                bloom(diameter)
            } else {
                GeometryReader { proxy in
                    // Measured against width, not height: on a tall screen a
                    // height-derived bloom turns the whole page into a flat
                    // wash instead of a glow with a centre.
                    let d = proxy.size.width * spread
                    bloom(d)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func bloom(_ d: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(strength), color.opacity(0.0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: d * 0.5
                )
            )
            .frame(width: d, height: d)
            .blur(radius: d * 0.07)
    }
}

/// The concentric arc backdrop, sized from its container for the same reason.
struct TPArcBackdrop: View {

    var color: Color
    var rings: Int = 6
    var sweep: Double = 0.66
    var verticalAnchor: CGFloat = 0.34
    var scale: Double = 1.12

    var body: some View {
        GeometryReader { proxy in
            let d = max(proxy.size.width, proxy.size.height) * scale

            TPArcField(rings: rings, sweep: sweep)
                .stroke(color, lineWidth: 1)
                .frame(width: d, height: d)
                .position(x: proxy.size.width / 2, y: proxy.size.height * verticalAnchor)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Typography
//
// One voice: SF Pro at display weights for headings, SF Pro for chrome, and
// SF Rounded for figures. The reference boards are entirely geometric sans —
// the serif that used to carry the headlines is gone.

enum TPFont {

    static func display(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func figure(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Text {

    /// Small caps label used for section heads and metadata.
    /// Built on AttributedString so it stays iOS 15 safe (`.tracking` is 16+).
    static func tpLabel(
        _ string: String,
        size: CGFloat = 11,
        weight: Font.Weight = .bold,
        tracking: CGFloat = 1.6,
        color: Color = .tpCreamFaint
    ) -> Text {
        var attributed = AttributedString(string.uppercased())
        attributed.kern = tracking
        attributed.font = .system(size: size, weight: weight)
        attributed.foregroundColor = color
        return Text(attributed)
    }

    static func tpFigure(
        _ value: String,
        size: CGFloat = 28,
        weight: Font.Weight = .heavy,
        color: Color = .tpCream
    ) -> Text {
        Text(value)
            .font(.system(size: size, weight: weight, design: .rounded))
            .foregroundColor(color)
    }
}

// MARK: - Metrics

enum TPMetric {

    static let gutter: CGFloat = 20
    static let cardRadius: CGFloat = 26
    static let tileRadius: CGFloat = 20
    static let chipRadius: CGFloat = 14
    static let hairline: CGFloat = 1

    /// Height reserved for the floating dock so scroll content never hides under it.
    static let dockClearance: CGFloat = 140
}

// MARK: - Motion

enum TPMotion {

    static let spring      = Animation.spring(response: 0.42, dampingFraction: 0.78)
    static let snappy      = Animation.spring(response: 0.28, dampingFraction: 0.86)
    static let gentle      = Animation.spring(response: 0.55, dampingFraction: 0.92)
    static let press       = Animation.spring(response: 0.22, dampingFraction: 0.7)
    static let breathe     = Animation.easeInOut(duration: 1.6)
    static let staggered   = Animation.spring(response: 0.5, dampingFraction: 0.82)
}

// MARK: - Haptics

enum TPHaptic {

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func thump() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func celebrate() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }
}

// MARK: - Shadows
//
// On a bright ground a neutral black shadow reads as dirt. These are tinted
// with the backdrop's own violet and kept soft and wide, which is how the
// reference boards get depth without a hard drop shadow anywhere.

extension View {

    func tpShadow(_ radius: CGFloat = 22, y: CGFloat = 12, opacity: Double = 0.28) -> some View {
        shadow(color: Color(hex: 0x1B0B3A).opacity(opacity), radius: radius, x: 0, y: y)
    }

    func tpEmberGlow(_ color: Color = .tpEmber, strength: Double = 0.55) -> some View {
        shadow(color: color.opacity(strength), radius: 24, x: 0, y: 10)
    }

    /// Paints the screen's gradient ground. Applied once per screen, underneath
    /// the scroll content, replacing the old flat `Color.tpInk` background.
    func tpBackdrop(_ style: TPBackdrop) -> some View {
        background(TPBackdropView(style: style))
    }
}

// MARK: - Surfaces

/// The frosted-glass recipe: a real blur, a thin white wash over it, a border
/// that catches light at the top-left, and a soft tinted shadow. Every surface
/// in the app is built from this so they read as one material.
struct TPGlassSurface: ViewModifier {

    var radius: CGFloat
    var strength: Double
    var bordered: Bool
    var shadowed: Bool

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(Color.white.opacity(strength))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        bordered ? AnyShapeStyle(TPGradient.glassEdge) : AnyShapeStyle(Color.clear),
                        lineWidth: TPMetric.hairline
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(
                color: Color(hex: 0x1B0B3A).opacity(shadowed ? 0.26 : 0),
                radius: shadowed ? 20 : 0,
                x: 0,
                y: shadowed ? 10 : 0
            )
    }
}

extension View {

    func tpGlass(
        radius: CGFloat = TPMetric.cardRadius,
        strength: Double = 0.18,
        bordered: Bool = true,
        shadowed: Bool = true
    ) -> some View {
        modifier(TPGlassSurface(radius: radius, strength: strength, bordered: bordered, shadowed: shadowed))
    }
}

struct TPCard<Content: View>: View {

    var radius: CGFloat = TPMetric.cardRadius
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .tpGlass(radius: radius, strength: 0.20)
    }
}

/// The neon-railed container from the reference: a rounded box whose border is
/// a warm→cool gradient, with a blurred copy of that same border behind it
/// providing the bloom. Used to lift one hero region off the page.
struct TPNeonRail<Content: View>: View {

    var radius: CGFloat = 30
    var padding: CGFloat = 16
    var glow: Double = 0.85
    /// Off when the content already carries its own glass — nesting two
    /// materials turns the interior muddy instead of layered.
    var filled: Bool = true
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background {
                if filled {
                    ZStack {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(.ultraThinMaterial)
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                    }
                }
            }
            .overlay(
                ZStack {
                    // The bloom: the rail, blurred and widened.
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(TPGradient.neonRail, lineWidth: 3)
                        .blur(radius: 7)
                        .opacity(glow)
                    // The rail itself.
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(TPGradient.neonRail, lineWidth: 1.6)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .compositingGroup()
            .shadow(color: Color.tpBloom.opacity(0.35), radius: 22, y: 8)
    }
}

/// Frosted fill for a bar pinned to a page edge — a header or a composer.
/// Opaque paint here would drop a dead band across the gradient, so the bar is
/// a blur instead and the colour keeps moving underneath it. The hairline sits
/// on whichever side faces the content.
struct TPBarFill: View {

    var edge: VerticalEdge = .bottom
    var tint: Double = 0.05

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(Color.white.opacity(tint))

            VStack(spacing: 0) {
                if edge == .bottom {
                    TPFadeRule(color: Color.white.opacity(0.20))
                    Spacer(minLength: 0)
                } else {
                    Spacer(minLength: 0)
                    TPFadeRule(color: Color.white.opacity(0.20))
                }
            }
        }
    }
}

/// A hairline that fades at both ends — used instead of a hard rule.
struct TPFadeRule: View {

    var color: Color = .tpLine

    var body: some View {
        LinearGradient(
            colors: [color.opacity(0), color, color.opacity(0)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: TPMetric.hairline)
    }
}

/// Fine grain overlay. Keeps large flat areas from looking like flat CSS.
///
/// Drawn with plain white speckle rather than a blend mode: a non-normal blend
/// forces the whole backdrop into an offscreen pass, which both crushes the
/// gradient and costs real time on the denser screens.
struct TPGrain: View {

    var opacity: Double = 0.05
    var density: Int = 200

    var body: some View {
        Canvas { context, size in
            var generator = SeededGenerator(seed: 0xA17C_0FFE)
            for _ in 0..<density {
                let x = Double.random(in: 0...size.width, using: &generator)
                let y = Double.random(in: 0...size.height, using: &generator)
                let r = Double.random(in: 0.3...1.1, using: &generator)
                let a = Double.random(in: 0.15...0.7, using: &generator)
                let rect = CGRect(x: x, y: y, width: r, height: r)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(a)))
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
    }
}

/// Deterministic RNG so procedural art is stable across launches.
struct SeededGenerator: RandomNumberGenerator {

    private var state: UInt64

    init(seed: Int64) {
        state = UInt64(bitPattern: seed &* 6364136223846793005 &+ 1442695040888963407)
        if state == 0 { state = 0x9E37_79B9_7F4A_7C15 }
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
