import SwiftUI
import Combine

// MARK: - Variants
//
// Six hand-built animations. One is drawn at random for every account
// transition, so signing in never looks like the same spinner twice.

enum TPLoaderVariant: CaseIterable {

    case spark
    case arcs
    case ticks
    case mark
    case bloom
    case orbit

    static func random() -> TPLoaderVariant {
        allCases.randomElement() ?? .spark
    }

    var caption: String {
        switch self {
        case .spark: return "Warming up"
        case .arcs:  return "Gathering"
        case .ticks: return "Counting"
        case .mark:  return "Drawing"
        case .bloom: return "Opening"
        case .orbit: return "Circling back"
        }
    }
}

// MARK: - Canvas view

struct TPLoaderView: View {

    let variant: TPLoaderVariant
    var size: CGFloat = 96
    var showsCaption: Bool = true

    @State private var animated = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                TPHalo(color: .tpEmber, diameter: size * 2.0)

                switch variant {
                case .spark: spark
                case .arcs:  arcs
                case .ticks: ticks
                case .mark:  mark
                case .bloom: bloom
                case .orbit: orbit
                }
            }
            .frame(width: size, height: size)

            if showsCaption {
                Text.tpLabel(variant.caption, size: 10.5, tracking: 2.4, color: .tpCreamFaint)
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                withAnimation { animated = true }
            }
        }
    }

    // MARK: Variant bodies

    private var spark: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                GlyphSpark()
                    .stroke(Color.tpAccent(index * 2), lineWidth: 2)
                    .frame(width: size * (0.42 + CGFloat(index) * 0.22),
                           height: size * (0.42 + CGFloat(index) * 0.22))
                    .rotationEffect(.degrees(animated ? Double(index) * 90 + 180 : Double(index) * 90))
                    .opacity(animated ? 0.25 : 1)
                    .animation(
                        .easeInOut(duration: 0.9)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.13),
                        value: animated
                    )
            }
            GlyphSpark()
                .fill(TPGradient.ember)
                .frame(width: size * 0.34, height: size * 0.34)
                .scaleEffect(animated ? 1.18 : 0.82)
                .animation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true), value: animated)
        }
    }

    private var arcs: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .trim(from: 0.04, to: CGFloat(0.24 + Double(index) * 0.14))
                    .stroke(
                        Color.tpAccent(index),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: size * (0.46 + CGFloat(index) * 0.27),
                           height: size * (0.46 + CGFloat(index) * 0.27))
                    .rotationEffect(.degrees(animated ? 360 : 0))
                    .animation(
                        .linear(duration: 1.1 + Double(index) * 0.42)
                            .repeatForever(autoreverses: false),
                        value: animated
                    )
            }
        }
    }

    private var ticks: some View {
        VStack(spacing: 9) {
            ForEach(0..<3, id: \.self) { row in
                TPTickStrip(total: 7, filled: animated ? 7 : 0)
                    .fill(TPGradient.accent(.tpAccent(row + 1)))
                    .frame(width: size * 0.82, height: 5)
                    .animation(
                        .easeInOut(duration: 0.62)
                            .repeatForever(autoreverses: true)
                            .delay(Double(row) * 0.16),
                        value: animated
                    )
            }
        }
    }

    private var mark: some View {
        ZStack {
            TPMark(showsBaseline: true)
                .stroke(Color.tpLine, style: StrokeStyle(lineWidth: 2, lineCap: .round))

            TPMark(showsBaseline: true)
                .trim(from: 0, to: animated ? 1 : 0)
                .stroke(
                    TPGradient.ember,
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round)
                )
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false), value: animated)
        }
        .frame(width: size * 0.86, height: size * 0.86)
    }

    private var bloom: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .strokeBorder(Color.tpAccent(index + 1), lineWidth: 1.6)
                    .frame(width: size * 0.9, height: size * 0.9)
                    .scaleEffect(animated ? 1.0 : 0.34)
                    .opacity(animated ? 0.0 : 0.9)
                    .animation(
                        .easeOut(duration: 1.25)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.28),
                        value: animated
                    )
            }
            Circle()
                .fill(TPGradient.ember)
                .frame(width: size * 0.18, height: size * 0.18)
        }
    }

    private var orbit: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .strokeBorder(Color.tpLine, lineWidth: 1)
                    .frame(width: size * (0.42 + CGFloat(index) * 0.29),
                           height: size * (0.42 + CGFloat(index) * 0.29))

                Circle()
                    .fill(Color.tpAccent(index))
                    .frame(width: 8 - CGFloat(index), height: 8 - CGFloat(index))
                    .offset(y: -size * (0.21 + CGFloat(index) * 0.145))
                    .rotationEffect(.degrees(animated ? 360 : 0))
                    .animation(
                        .linear(duration: 1.0 + Double(index) * 0.35)
                            .repeatForever(autoreverses: false),
                        value: animated
                    )
            }
        }
    }
}

// MARK: - Overlay
//
// The single account-transition curtain. Held for at least `minimumDuration`
// so the animation is always seen in full rather than flashing past.

struct TPLoadingOverlay: View {

    let variant: TPLoaderVariant
    var message: String?

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.tpInk.opacity(0.55)
                .ignoresSafeArea()

            TPGrain(opacity: 0.05)
                .ignoresSafeArea()

            VStack(spacing: 22) {
                TPLoaderView(variant: variant, size: 104)

                if let message {
                    Text(message)
                        .font(TPFont.display(19, .bold))
                        .foregroundColor(.tpCream)
                }
            }
            .scaleEffect(appeared ? 1 : 0.94)
            .opacity(appeared ? 1 : 0)
            .animation(TPMotion.gentle, value: appeared)
        }
        .transition(.opacity)
        .onAppear {
            DispatchQueue.main.async { appeared = true }
        }
    }
}

// MARK: - Presenter

private struct LoadingModifier: ViewModifier {

    @Binding var isPresented: Bool
    let variant: TPLoaderVariant
    let message: String?

    func body(content: Content) -> some View {
        ZStack {
            content
            if isPresented {
                TPLoadingOverlay(variant: variant, message: message)
                    .zIndex(999)
            }
        }
        .animation(TPMotion.gentle, value: isPresented)
    }
}

extension View {

    func tpLoading(_ isPresented: Binding<Bool>, variant: TPLoaderVariant, message: String? = nil) -> some View {
        modifier(LoadingModifier(isPresented: isPresented, variant: variant, message: message))
    }
}

// MARK: - Runner

enum TPLoadingRun {

    /// Shows a randomly chosen animation for roughly a second while `work` runs,
    /// then tears it down. Used by sign in, sign up, sign out and account deletion.
    @MainActor
    static func run(
        minimumDuration: Double = 1.0,
        message: String? = nil,
        perform work: @escaping () async -> Void
    ) async {
        let variant = TPLoaderVariant.random()
        LoadingGate.shared.begin(variant: variant, message: message)

        async let minimum: Void = sleep(seconds: minimumDuration)
        async let task: Void = work()
        _ = await (minimum, task)

        LoadingGate.shared.end()
    }

    private static func sleep(seconds: Double) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

/// Carries the active variant for `TPLoadingRun` to the root overlay.
final class LoadingGate: ObservableObject {

    static let shared = LoadingGate()

    @Published private(set) var isActive = false
    @Published private(set) var variant: TPLoaderVariant = .spark
    @Published private(set) var message: String?

    private init() {}

    func begin(variant: TPLoaderVariant, message: String?) {
        self.variant = variant
        self.message = message
        isActive = true
    }

    func end() {
        isActive = false
    }
}

/// Root-level curtain bound to `LoadingGate`.
struct TPLoadingGateHost: ViewModifier {

    @StateObject private var gate = LoadingGate.shared

    func body(content: Content) -> some View {
        ZStack {
            content
            if gate.isActive {
                TPLoadingOverlay(variant: gate.variant, message: gate.message)
                    .zIndex(1000)
            }
        }
        .animation(TPMotion.gentle, value: gate.isActive)
    }
}

extension View {

    func tpLoadingGate() -> some View {
        modifier(TPLoadingGateHost())
    }
}
