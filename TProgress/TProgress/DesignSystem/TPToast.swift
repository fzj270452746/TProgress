import SwiftUI
import Combine

// MARK: - Tone

enum TPToastTone {

    case neutral
    case ember
    case success
    case warning
    case failure

    var accent: Color {
        switch self {
        case .neutral: return .tpCreamDim
        case .ember:   return .tpEmber
        case .success: return .tpMint
        case .warning: return .tpSun
        case .failure: return .tpBloom
        }
    }

    var symbol: String {
        switch self {
        case .neutral: return "circle.fill"
        case .ember:   return "sparkle"
        case .success: return "checkmark"
        case .warning: return "exclamationmark"
        case .failure: return "xmark"
        }
    }
}

// MARK: - Item

struct TPToastItem: Identifiable, Equatable {

    let id = UUID()
    var text: String
    var tone: TPToastTone
    var symbol: String?
    var duration: Double

    static func == (lhs: TPToastItem, rhs: TPToastItem) -> Bool { lhs.id == rhs.id }
}

// MARK: - Center
//
// One toast surface for the whole app. Every transient message routes here so
// the app never speaks in two visual languages.

final class ToastCenter: ObservableObject {

    static let shared = ToastCenter()

    @Published private(set) var items: [TPToastItem] = []

    private var timers: [UUID: Timer] = [:]

    private init() {}

    func show(
        _ text: String,
        tone: TPToastTone = .neutral,
        symbol: String? = nil,
        duration: Double = 2.2
    ) {
        let item = TPToastItem(text: text, tone: tone, symbol: symbol, duration: duration)

        withAnimation(TPMotion.snappy) {
            items.append(item)
            if items.count > 3 { items.removeFirst() }
        }

        switch tone {
        case .success: TPHaptic.success()
        case .failure, .warning: TPHaptic.warning()
        default: TPHaptic.tap()
        }

        let timer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.dismiss(item.id)
        }
        timers[item.id] = timer
    }

    func dismiss(_ id: UUID) {
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
        withAnimation(TPMotion.snappy) {
            items.removeAll { $0.id == id }
        }
    }

    func dismissAll() {
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
        withAnimation(TPMotion.snappy) { items.removeAll() }
    }
}

// MARK: - Bubble

struct TPToastBubble: View {

    let item: TPToastItem

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle()
                    .fill(item.tone.accent.opacity(0.16))
                    .frame(width: 26, height: 26)
                Image(systemName: item.symbol ?? item.tone.symbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(item.tone.accent)
            }

            Text(item.text)
                .font(TPFont.ui(14.5, .medium))
                .foregroundColor(.tpCream)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 11)
        .padding(.trailing, 18)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule(style: .continuous)
                        .fill(Color.tpInkRaised.opacity(0.86))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(item.tone.accent.opacity(0.30), lineWidth: 1)
                )
        )
        .tpShadow(20, y: 12, opacity: 0.5)
    }
}

// MARK: - Host

private struct ToastHost: ViewModifier {

    @StateObject private var center = ToastCenter.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                VStack(spacing: 8) {
                    ForEach(center.items) { item in
                        TPToastBubble(item: item)
                            .transition(
                                .asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .opacity.combined(with: .scale(scale: 0.92, anchor: .top))
                                )
                            )
                            .onTapGesture { center.dismiss(item.id) }
                    }
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.top, 6)
                .animation(TPMotion.snappy, value: center.items)
            }
    }
}

extension View {

    /// Attach once, at the root. Every `ToastCenter.shared.show(...)` lands here.
    func tpToastHost() -> some View {
        modifier(ToastHost())
    }
}

// MARK: - Shortcut

func tpToast(
    _ text: String,
    tone: TPToastTone = .neutral,
    symbol: String? = nil,
    duration: Double = 2.2
) {
    ToastCenter.shared.show(text, tone: tone, symbol: symbol, duration: duration)
}
