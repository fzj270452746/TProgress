import SwiftUI
import UIKit

// MARK: - Like
//
// The burst is the only celebratory animation in the feed. It fires on the way
// in, never on the way out — unliking should feel quiet.

struct TPLikeButton: View {

    let isLiked: Bool
    let count: Int
    var accent: Color = .tpBloom
    var size: CGFloat = 16
    let action: () -> Void

    @State private var burstToken = 0
    @State private var burstProgress: CGFloat = 0
    @State private var scale: CGFloat = 1

    var body: some View {
        Button(action: {
            action()
            guard !isLiked else { return }
            burstToken += 1
        }) {
            HStack(spacing: 6) {
                ZStack {
                    TPBurst(points: 7, innerRatio: 0.36)
                        .fill(accent)
                        .frame(width: size * 1.7, height: size * 1.7)
                        .scaleEffect(0.4 + burstProgress * 1.5)
                        .opacity(Double(1 - burstProgress) * 0.95)
                        .allowsHitTesting(false)

                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: size, weight: .semibold))
                        .foregroundColor(isLiked ? accent : .tpCreamDim)
                        .scaleEffect(scale)
                }
                .frame(width: size * 1.2, height: size * 1.2)

                if count > 0 {
                    Text("\(count)")
                        .font(TPFont.figure(13, .semibold))
                        .foregroundColor(isLiked ? accent : .tpCreamDim)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onChange(of: burstToken) { _ in
            burstProgress = 0
            withAnimation(.easeOut(duration: 0.55)) { burstProgress = 1 }
            withAnimation(.spring(response: 0.28, dampingFraction: 0.45)) { scale = 1.34 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                withAnimation(TPMotion.spring) { scale = 1 }
            }
        }
    }
}

// MARK: - Like button
//
// `TPLikeButton` plus the state the caller has to own for itself. Core Data
// does not publish a like back up to the view that raised it, so the button
// keeps its own copy and re-seeds it from the post on every tap.

struct PostLikeButton: View {

    let post: CDPost
    var size: CGFloat = 16
    var accent: Color = .tpBloom

    /// Fires after a like lands, for callers that render the same count twice —
    /// the bar below it and a stat plate, say.
    var onChange: (() -> Void)?

    @ObservedObject private var session = AppSession.shared
    @State private var liked: Bool?
    @State private var count: Int?

    var body: some View {
        TPLikeButton(
            isLiked: liked ?? post.isLikedByMe,
            count: count ?? Int(post.likeCount),
            accent: accent,
            size: size
        ) {
            session.withAuth(prompt: "Sign in to cheer people on.") {
                CommunityService.toggleLike(post)
                liked = post.isLikedByMe
                count = Int(post.likeCount)
                onChange?()
            }
        }
    }
}

// MARK: - Action bar

struct PostActionBar: View {

    let post: CDPost
    var showsLabels: Bool = false
    var onLikeChanged: (() -> Void)?
    var onComment: () -> Void
    var onGift: () -> Void
    var onShare: () -> Void

    var body: some View {
        HStack(spacing: showsLabels ? 20 : 18) {
            PostLikeButton(post: post, onChange: onLikeChanged)

            action(
                symbol: "bubble.left",
                count: post.commentCount,
                tint: .tpSky,
                label: "Reply",
                action: onComment
            )

            action(
                symbol: "gift",
                count: Int(post.giftCount),
                tint: .tpSun,
                label: "Gift",
                action: onGift
            )

            if showsLabels {
                Spacer(minLength: 0)
            }

            action(
                symbol: "square.and.arrow.up",
                count: nil,
                tint: .tpCreamDim,
                label: "Share",
                action: onShare
            )

            if !showsLabels {
                Spacer(minLength: 0)
            }
        }
    }

    private func action(
        symbol: String,
        count: Int?,
        tint: Color,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(tint)

                if let count, count > 0 {
                    Text("\(count)")
                        .font(TPFont.figure(13, .semibold))
                        .foregroundColor(.tpCreamDim)
                } else if showsLabels {
                    Text(label)
                        .font(TPFont.ui(13, .medium))
                        .foregroundColor(.tpCreamDim)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Share

/// `ShareLink` is iOS 16, so the activity controller is wrapped directly.
struct TPShareSheet: UIViewControllerRepresentable {

    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

// MARK: - Gift summary
//
// A compact ledger of what a post has been given, shown above the action bar.

struct PostGiftSummary: View {

    let post: CDPost

    private var topGifts: [(TPGift, Int)] {
        var tally: [String: Int] = [:]
        for event in post.gifts {
            guard let key = event.giftKey else { continue }
            tally[key, default: 0] += 1
        }
        return tally
            .compactMap { key, count -> (TPGift, Int)? in
                guard let gift = TPGiftCatalog.gift(for: key) else { return nil }
                return (gift, count)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        let gifts = topGifts
        if !gifts.isEmpty {
            HStack(spacing: 8) {
                ForEach(gifts, id: \.0.key) { gift, count in
                    HStack(spacing: 5) {
                        Image(systemName: gift.symbol)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(gift.accent)
                        Text("\(count)")
                            .font(TPFont.figure(11.5, .bold))
                            .foregroundColor(.tpCreamDim)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(gift.accent.opacity(0.12))
                    )
                    .overlay(
                        Capsule().strokeBorder(gift.accent.opacity(0.26), lineWidth: 1)
                    )
                }

                Text.tpLabel("received", size: 9, tracking: 1.4)

                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Overflow menu
//
// Copy, delete or report, behind one ellipsis. Shared by every surface that
// shows a post, so the same three actions sit in the same place wherever you
// happen to meet one.

struct PostOverflowMenu: View {

    let post: CDPost
    var size: CGFloat = 28

    var body: some View {
        Menu {
            Button {
                UIPasteboard.general.string = post.body
                tpToast("Copied to clipboard", tone: .success, symbol: "doc.on.doc")
            } label: {
                Label("Copy text", systemImage: "doc.on.doc")
            }

            if post.isMine {
                Button(role: .destructive) {
                    CommunityService.delete(post: post)
                    tpToast("Post removed", tone: .success, symbol: "trash")
                    RefreshSignal.shared.bumpFeed()
                } label: {
                    Label("Delete post", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    ReportPresenter.shared.present(.post(post))
                } label: {
                    Label("Report post", systemImage: "flag")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundColor(.tpCreamFaint)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: size)
    }
}
