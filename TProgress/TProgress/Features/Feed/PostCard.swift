import SwiftUI
import UIKit

// MARK: - Post card
//
// The feed's unit. Reads top to bottom as: who, how much, what they said, what
// it looked like, and what you can do about it.

struct PostCard: View {

    let post: CDPost
    var onOpenGift: (CDPost) -> Void

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared

    @State private var isSharing = false

    private var accent: Color { .tpAccent(seed: post.seed) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if let parts = post.quantityParts {
                TPQuantityPlate(
                    value: parts.value,
                    unit: parts.unit,
                    detail: post.habitName,
                    accent: accent,
                    symbol: post.kind.symbol
                )
            }

            if !post.body.isEmpty {
                Text(post.body)
                    .font(TPFont.ui(15))
                    .foregroundColor(.tpCream)
                    .lineSpacing(4.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }

            if post.hasMedia {
                PostMediaStrip(post: post) { _ in openDetail() }
            }

            if post.giftCount > 0 {
                PostGiftSummary(post: post)
            }

            TPFadeRule()

            PostActionBar(
                post: post,
                onComment: openDetail,
                onGift: {
                    session.withAuth(prompt: "Sign in to send a gift.") {
                        onOpenGift(post)
                    }
                },
                onShare: { isSharing = true }
            )
        }
        .padding(16)
        // A real blur, not just a translucent wash. The feed card has to stay a
        // discrete object even where the backdrop underneath it turns magenta.
        .tpGlass(radius: TPMetric.cardRadius, strength: 0.22)
        .contentShape(Rectangle())
        .onTapGesture(perform: openDetail)
        .sheet(isPresented: $isSharing) {
            TPShareSheet(items: shareItems)
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 11) {
            Button(action: openAuthor) {
                TPAvatar(
                    seed: post.author?.avatarSeed ?? 0,
                    name: post.author?.name ?? "?",
                    size: 42,
                    imagePath: post.author?.avatarAssetName
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(post.author?.name ?? "Someone")
                        .font(TPFont.ui(15, .semibold))
                        .foregroundColor(.tpCream)
                        .lineLimit(1)

                    if post.author?.isFollowedByMe == true {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.tpEmber)
                    }
                }

                HStack(spacing: 5) {
                    Text(post.author?.handle ?? "")
                        .font(TPFont.ui(12))
                        .foregroundColor(.tpCreamFaint)

                    Text("·")
                        .font(TPFont.ui(12))
                        .foregroundColor(.tpCreamFaint)

                    Text(post.relativeTime)
                        .font(TPFont.ui(12))
                        .foregroundColor(.tpCreamFaint)
                }
            }

            Spacer(minLength: 8)

            TPTag(text: post.kind.label, color: accent, filled: post.kind == .summary)

            PostOverflowMenu(post: post)
        }
    }

    // MARK: Actions

    private func openDetail() {
        guard let id = post.id else { return }
        router.push(.post(id))
    }

    private func openAuthor() {
        guard let author = post.author, let id = author.id else { return }
        if author.isCurrentUser {
            router.select(.me)
        } else {
            router.push(.profile(id))
        }
    }

    private var shareItems: [Any] {
        var items: [Any] = []
        let author = post.author?.name ?? "Someone"
        items.append("\(author) on TProgress: \(post.body)")
        return items
    }
}
