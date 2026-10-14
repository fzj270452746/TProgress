import Foundation
import SwiftUI
import Combine
import CoreData

/// Drives the video call screen. The connection is established through the
/// service rather than the view, so the phase survives a re-render and the
/// thread records the attempt either way.
final class CallService: ObservableObject {

    static let shared = CallService()

    enum Phase: Equatable {
        case connecting
        case declined

        var caption: String {
            switch self {
            case .connecting: return "Connecting"
            case .declined:   return "Call declined"
            }
        }
    }

    @Published private(set) var isActive = false
    @Published private(set) var phase: Phase = .connecting
    @Published private(set) var peer: CDUser?

    /// How long the connection is held before the other side declines.
    private let ringDuration: Double = 5.0
    /// How long the decline is shown before the screen closes itself.
    private let declineLinger: Double = 1.6

    private var thread: CDConversation?
    private var task: Task<Void, Never>?

    private init() {}

    // MARK: Control

    func start(with peer: CDUser, in thread: CDConversation?) {
        guard !isActive else { return }

        self.peer = peer
        self.thread = thread
        phase = .connecting
        isActive = true
        TPHaptic.thump()

        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }

            try? await Task.sleep(nanoseconds: UInt64(ringDuration * 1_000_000_000))
            guard !Task.isCancelled, self.isActive else { return }

            withAnimation(TPMotion.gentle) { self.phase = .declined }
            TPHaptic.warning()

            try? await Task.sleep(nanoseconds: UInt64(declineLinger * 1_000_000_000))
            guard !Task.isCancelled, self.isActive else { return }

            if let thread = self.thread { CommunityService.logMissedCall(in: thread) }
            self.close()
        }
    }

    func hangUp() {
        task?.cancel()
        if let thread { CommunityService.logMissedCall(in: thread) }
        close()
    }

    private func close() {
        withAnimation(TPMotion.gentle) {
            isActive = false
        }
        peer = nil
        thread = nil
        phase = .connecting
    }
}

// MARK: - Screen

/// Full-bleed call surface. No self preview — the local camera window is
/// deliberately absent, so the peer fills the frame while it rings.
struct TPCallScreen: View {

    let peer: CDUser
    let phase: CallService.Phase
    let onHangUp: () -> Void

    @State private var pulse = false
    @State private var elapsed = 0
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.tpInk.ignoresSafeArea()

            TPArt(seed: peer.avatarSeed &* 3 &+ 11, cornerRadius: 0)
                .ignoresSafeArea()
                .blur(radius: 46)
                .opacity(0.55)

            Color.tpInk.opacity(0.55).ignoresSafeArea()
            TPGrain(opacity: 0.06).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                rings

                VStack(spacing: 8) {
                    Text(peer.name)
                        .font(TPFont.display(29, .heavy))
                        .foregroundColor(.tpCream)

                    Text(statusText)
                        .font(TPFont.ui(14, .medium))
                        .foregroundColor(phase == .declined ? .tpBloom : .tpCreamDim)
                        .animation(.easeInOut(duration: 0.2), value: phase)
                }
                .padding(.top, 34)

                Spacer()

                hangUpButton
                    .padding(.bottom, 54)
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
        .onReceive(ticker) { _ in
            guard phase == .connecting else { return }
            elapsed += 1
        }
    }

    private var statusText: String {
        switch phase {
        case .connecting:
            let seconds = String(format: "%02d", elapsed)
            return "\(phase.caption) · 00:\(seconds)"
        case .declined:
            return phase.caption
        }
    }

    private var rings: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .strokeBorder(Color.tpCream.opacity(0.16), lineWidth: 1)
                    .frame(width: 168 + CGFloat(index) * 46,
                           height: 168 + CGFloat(index) * 46)
                    .scaleEffect(pulse ? 1.05 : 0.94)
                    .opacity(pulse ? 0.7 : 0.25)
                    .animation(
                        .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.18),
                        value: pulse
                    )
            }

            TPAvatar(seed: peer.avatarSeed, name: peer.name, size: 148, showsRing: true, ringColor: .tpCream.opacity(0.35))
                .overlay(
                    Circle()
                        .strokeBorder(phase == .declined ? Color.tpBloom : Color.tpMint, lineWidth: 2)
                        .frame(width: 154, height: 154)
                        .opacity(0.8)
                )
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.5), radius: 30, y: 14)
        }
    }

    private var hangUpButton: some View {
        VStack(spacing: 10) {
            Button(action: onHangUp) {
                ZStack {
                    Circle()
                        .fill(Color.tpBloom)
                        .frame(width: 70, height: 70)
                        .tpEmberGlow(.tpBloom, strength: 0.45)

                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)

            Text.tpLabel("End call", size: 10, tracking: 1.8, color: .tpCreamFaint)
        }
    }
}
