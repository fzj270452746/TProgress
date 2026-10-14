import SwiftUI

// MARK: - Gift tray
//
// Seven tokens on a ladder from a single spark to a supernova. Real StoreKit
// consumables; the tray renders from the catalogue so it is never empty, and
// falls back to catalogue pricing before the store answers.

struct GiftTray: View {

    let post: CDPost
    let onSent: (TPGift) -> Void

    @ObservedObject private var store = StoreKitService.shared

    @State private var selection: TPGift?
    @State private var isSending = false
    @State private var celebration: TPGift?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(spacing: 18) {
            header

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(TPGiftCatalog.all) { gift in
                    giftCell(gift)
                }
            }
            .padding(.horizontal, TPMetric.gutter - 4)

            detail
            sendButton
            disclaimer
        }
        .padding(.top, 10)
        .padding(.bottom, 30)
        .overlay(celebrationOverlay)
        .task {
            if !store.didAttemptLoad {
                await store.loadProducts()
            }
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(spacing: 5) {
            Text("Send a gift")
                .font(TPFont.display(25, .bold))
                .foregroundColor(.tpCream)

            Text("to \(post.author?.name ?? "this post")")
                .font(TPFont.ui(13.5))
                .foregroundColor(.tpCreamDim)
        }
    }

    private func giftCell(_ gift: TPGift) -> some View {
        let isSelected = selection?.key == gift.key

        return Button(action: {
            TPHaptic.tap()
            withAnimation(TPMotion.spring) {
                selection = isSelected ? nil : gift
            }
        }) {
            TPGiftToken(
                gift: gift,
                size: isSelected ? 60 : 54,
                showsPrice: true
            )
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? gift.accent.opacity(0.30) : Color.white.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        isSelected ? gift.accent.opacity(0.7) : Color.tpLine,
                        lineWidth: isSelected ? 1.6 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detail: some View {
        if let selection {
            VStack(spacing: 6) {
                Text(selection.blurb)
                    .font(TPFont.display(16))
                    .foregroundColor(.tpCream)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 30)

                Text(store.priceLabel(for: selection))
                    .font(TPFont.figure(14, .bold))
                    .foregroundColor(selection.accent)
            }
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
            Text("Pick a token. Every one of them lands in their thread too.")
                .font(TPFont.ui(13))
                .foregroundColor(.tpCreamFaint)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
    }

    private var sendButton: some View {
        TPPrimaryButton(
            title: selection.map { "Send · \(store.priceLabel(for: $0))" } ?? "Choose a gift",
            symbol: "gift.fill",
            isLoading: isSending,
            isEnabled: selection != nil
        ) {
            send()
        }
        .padding(.horizontal, TPMetric.gutter)
    }

    private var disclaimer: some View {
        Text("Gifts are consumable purchases processed by the App Store. They cannot be refunded once sent.")
            .font(TPFont.ui(11))
            .foregroundColor(.tpCreamFaint)
            .multilineTextAlignment(.center)
            .lineSpacing(2.5)
            .padding(.horizontal, 34)
    }

    // MARK: Celebration

    @ViewBuilder
    private var celebrationOverlay: some View {
        if let celebration {
            ZStack {
                Color.tpInk.opacity(0.92)
                    .ignoresSafeArea()

                GiftCelebration(gift: celebration, recipient: post.author?.name ?? "them")
            }
            .transition(.opacity)
            .zIndex(10)
        }
    }

    // MARK: Send

    private func send() {
        guard let gift = selection, !isSending else { return }
        isSending = true

        Task {
            let result = await store.purchase(gift)
            isSending = false

            switch result {
            case .success:
                CommunityService.sendGift(gift, to: post, amountCents: gift.priceCents)
                TPHaptic.celebrate()
                withAnimation(TPMotion.spring) { celebration = gift }

                try? await Task.sleep(nanoseconds: 1_400_000_000)
                withAnimation(TPMotion.gentle) { celebration = nil }
                onSent(gift)

            case .cancelled:
                break

            case .pending:
                tpToast("Your purchase is pending approval.", tone: .warning, symbol: "clock")

            case .unavailable:
                tpToast("Gifts are unavailable right now. Try again shortly.", tone: .warning, symbol: "wifi.exclamationmark")

            case .failed(let message):
                tpToast(message, tone: .failure, symbol: "xmark")
            }
        }
    }
}

// MARK: - Celebration

struct GiftCelebration: View {

    let gift: TPGift
    let recipient: String

    @State private var pop = false
    @State private var rays = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                ForEach(0..<10, id: \.self) { index in
                    Capsule()
                        .fill(gift.accent.opacity(0.7))
                        .frame(width: 2.5, height: rays ? 54 : 8)
                        .offset(y: rays ? -70 : -34)
                        .rotationEffect(.degrees(Double(index) / 10 * 360))
                        .opacity(rays ? 0 : 0.9)
                        .animation(
                            .easeOut(duration: 0.8).delay(Double(index) * 0.02),
                            value: rays
                        )
                }

                Circle()
                    .fill(TPGradient.accent(gift.accent))
                    .frame(width: 108, height: 108)
                    .scaleEffect(pop ? 1 : 0.4)
                    .tpEmberGlow(gift.accent, strength: 0.6)

                Image(systemName: gift.symbol)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.tpInk.opacity(0.85))
                    .scaleEffect(pop ? 1 : 0.5)
            }

            VStack(spacing: 6) {
                Text(gift.name)
                    .font(TPFont.display(26, .heavy))
                    .foregroundColor(.tpCream)

                Text("Sent to \(recipient) · \(gift.priceLabel)")
                    .font(TPFont.ui(13.5))
                    .foregroundColor(.tpCreamDim)
            }
            .opacity(pop ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { pop = true }
            withAnimation(.easeOut(duration: 0.9)) { rays = true }
        }
    }
}
