import SwiftUI
import UIKit

// MARK: - Bento feed
//
// The home page is a composed page, not a timeline. The newest post is promoted
// to a full-width hero, the rest interlock beneath it in pairs, and a lone
// straggler closes the page at full width. Six posts is the whole window, so
// the composition always has a top, a middle and a bottom — which is what a
// column of identical cards never had.
//
// Every tile keeps the same anatomy as the old card, just at three different
// volumes: how much, what was said, who said it. The amount stays the headline,
// because that is what makes this a progress log rather than a social timeline.

struct BentoFeed: View {

    let posts: [CDPost]
    var onOpenGift: (CDPost) -> Void

    var body: some View {
        VStack(spacing: 12) {
            if let hero = posts.first {
                BentoHeroCard(post: hero, onOpenGift: onOpenGift)
            }

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                if row.count == 1 {
                    BentoWideTile(post: row[0], onOpenGift: onOpenGift)
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(row, id: \.objectID) { post in
                            BentoHalfTile(post: post)
                        }
                    }
                }
            }
        }
    }

    /// The tail of the feed, paired up. An odd post left over closes the page
    /// at full width rather than leaving a hole in the grid.
    private var rows: [[CDPost]] {
        let rest = Array(posts.dropFirst())
        var result: [[CDPost]] = []
        var index = 0

        while index < rest.count {
            if rest.count - index == 1 {
                result.append([rest[index]])
                index += 1
            } else {
                result.append([rest[index], rest[index + 1]])
                index += 2
            }
        }

        return result
    }
}

// MARK: - Hero
//
// The one post the page leads with. Read top to bottom: the art, the amount,
// what they said, then the byline — the order a magazine would set it in.

private struct BentoHeroCard: View {

    let post: CDPost
    var onOpenGift: (CDPost) -> Void

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared

    @State private var isSharing = false

    private var accent: Color { .tpAccent(seed: post.seed) }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            if let media = post.sortedMedia.first {
                BentoCover(
                    post: post,
                    media: media,
                    ratio: coverRatio,
                    cornerRadius: 20,
                    showsKindTag: true,
                    accent: accent
                )
                .contentShape(Rectangle())
                .onTapGesture(perform: openDetail)
            } else {
                HStack(spacing: 8) {
                    BentoKindTag(post: post)

                    Spacer(minLength: 0)

                    Text(post.relativeTime)
                        .font(TPFont.ui(12))
                        .foregroundColor(.tpCreamFaint)
                }
            }

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
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }

            byline

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
        .padding(14)
        .tpGlass(radius: TPMetric.cardRadius, strength: 0.22)
        .contentShape(Rectangle())
        .onTapGesture(perform: openDetail)
        .sheet(isPresented: $isSharing) {
            TPShareSheet(items: shareItems)
        }
    }

    private var byline: some View {
        HStack(spacing: 9) {
            TPAvatar(
                seed: post.author?.avatarSeed ?? 0,
                name: post.author?.name ?? "?",
                size: 28,
                imagePath: post.author?.avatarAssetName
            )

            Text(post.author?.name ?? "Someone")
                .font(TPFont.ui(13.5, .semibold))
                .foregroundColor(.tpCream)
                .lineLimit(1)

            if post.author?.isFollowedByMe == true {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.tpEmber)
            }

            Text("·")
                .font(TPFont.ui(12))
                .foregroundColor(.tpCreamFaint)

            Text(post.relativeTime)
                .font(TPFont.ui(12))
                .foregroundColor(.tpCreamFaint)

            Spacer(minLength: 6)

            PostOverflowMenu(post: post, size: 26)
        }
    }

    /// A fixed 3:2 banner. The lead image is the page's masthead, so its shape
    /// is set by the layout rather than by whatever ratio the seed happened to
    /// draw — otherwise half the feed opens on a near-square poster that eats
    /// the entire first screen.
    private var coverRatio: CGFloat { 1.5 }

    private func openDetail() {
        guard let id = post.id else { return }
        router.push(.post(id))
    }

    private var shareItems: [Any] {
        ["\(post.author?.name ?? "Someone") on TProgress: \(post.body)"]
    }
}

// MARK: - Half tile
//
// Two to a row. Carries the art, the amount, two lines of what was said, and
// the byline — the same four things as the hero, at a third of the room.

private struct BentoHalfTile: View {

    let post: CDPost

    @ObservedObject private var router = Router.shared

    private var accent: Color { .tpAccent(seed: post.seed) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let media = post.sortedMedia.first {
                BentoCover(
                    post: post,
                    media: media,
                    ratio: coverRatio,
                    cornerRadius: 15,
                    showsKindTag: false,
                    accent: accent
                )
                .contentShape(Rectangle())
                .onTapGesture(perform: openDetail)

                BentoAmount(post: post, accent: accent, size: 21)
            } else {
                BentoAmountWell(post: post, accent: accent, ratio: coverRatio)
            }

            if !post.body.isEmpty {
                Text(post.body)
                    .font(TPFont.ui(12.5))
                    .foregroundColor(.tpCreamDim)
                    .lineSpacing(3)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 0)

            footer
        }
        .padding(11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .tpGlass(radius: 22, strength: 0.18)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture(perform: openDetail)
    }

    private var footer: some View {
        HStack(spacing: 6) {
            TPAvatar(
                seed: post.author?.avatarSeed ?? 0,
                name: post.author?.name ?? "?",
                size: 18,
                imagePath: post.author?.avatarAssetName
            )

            Text(post.author?.name ?? "Someone")
                .font(TPFont.ui(11, .semibold))
                .foregroundColor(.tpCreamDim)
                .lineLimit(1)

            Spacer(minLength: 4)

            PostLikeButton(post: post, size: 12)
        }
    }

    /// Square, fixed. Letting the seed pick the shape here made the two tiles in
    /// a row start their text at different heights, which reads as a mistake
    /// rather than as a composition — the variety belongs to the page's mix of
    /// hero, pairs and wide card, not to jitter inside a row.
    private var coverRatio: CGFloat { 1.0 }

    private func openDetail() {
        guard let id = post.id else { return }
        router.push(.post(id))
    }
}

// MARK: - Wide tile
//
// The page's closing card. Lays out across instead of down: the art in a square
// well on the left, everything else stacked beside it.

private struct BentoWideTile: View {

    let post: CDPost
    var onOpenGift: (CDPost) -> Void

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared

    private var accent: Color { .tpAccent(seed: post.seed) }

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            if let media = post.sortedMedia.first {
                TPMediaTile(media: media, cornerRadius: 15)
                    .frame(width: 84, height: 84)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: openDetail)
            } else {
                well
            }

            VStack(alignment: .leading, spacing: 7) {
                BentoAmount(post: post, accent: accent, size: 24)

                if !post.body.isEmpty {
                    Text(post.body)
                        .font(TPFont.ui(13))
                        .foregroundColor(.tpCreamDim)
                        .lineSpacing(3)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 0)

                footer
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .tpGlass(radius: 22, strength: 0.18)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture(perform: openDetail)
    }

    /// Stands in for the art on a post that has none, so the card keeps its
    /// left-hand weight instead of collapsing into a bare line of text.
    private var well: some View {
        ZStack {
            BentoWellBackground(accent: accent, cornerRadius: 15, haloDiameter: 110)

            Image(systemName: post.kind.symbol)
                .font(.system(size: 23, weight: .semibold))
                .foregroundColor(accent)
        }
        .frame(width: 84, height: 84)
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
        )
    }

    private var footer: some View {
        HStack(spacing: 14) {
            TPAvatar(
                seed: post.author?.avatarSeed ?? 0,
                name: post.author?.name ?? "?",
                size: 18,
                imagePath: post.author?.avatarAssetName
            )

            Text(post.author?.name ?? "Someone")
                .font(TPFont.ui(11.5, .semibold))
                .foregroundColor(.tpCreamDim)
                .lineLimit(1)

            Spacer(minLength: 4)

            PostLikeButton(post: post, size: 13)

            BentoMiniAction(
                symbol: "bubble.left.fill",
                count: post.commentCount,
                tint: .tpSky,
                action: openDetail
            )

            BentoMiniAction(
                symbol: "gift.fill",
                count: Int(post.giftCount),
                tint: .tpSun,
                action: {
                    session.withAuth(prompt: "Sign in to send a gift.") {
                        onOpenGift(post)
                    }
                }
            )
        }
    }

    private func openDetail() {
        guard let id = post.id else { return }
        router.push(.post(id))
    }
}

// MARK: - Shared pieces

/// The kind tag, worn as a pill. On a cover it sits over the art; on a card
/// with no art it sits inline above the amount.
private struct BentoKindTag: View {

    let post: CDPost

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: post.kind.symbol)
                .font(.system(size: 9.5, weight: .bold))

            Text(post.kind.label)
                .font(.system(size: 10.5, weight: .bold))
        }
        .foregroundColor(.tpCream)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background {
            ZStack {
                Capsule(style: .continuous).fill(.ultraThinMaterial)
                Capsule(style: .continuous).fill(Color.white.opacity(0.14))
            }
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
        }
    }
}

/// The amount in tile form: a lit bar, the figure, the unit. The same anatomy
/// as `TPQuantityPlate`, sized to fit two-up without the plate's padding.
private struct BentoAmount: View {

    let post: CDPost
    let accent: Color
    var size: CGFloat = 22

    @ViewBuilder
    var body: some View {
        if let parts = post.quantityParts {
            HStack(spacing: 7) {
                Capsule()
                    .fill(TPGradient.accent(accent))
                    .frame(width: 3, height: size * 0.86)

                Text(parts.value)
                    .font(.system(size: size, weight: .heavy, design: .rounded))
                    .foregroundColor(.tpCream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Text(parts.unit.uppercased())
                    .font(.system(size: max(8.5, size * 0.40), weight: .bold))
                    .foregroundColor(.tpCreamDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Spacer(minLength: 0)
            }
        }
    }
}

/// Stands in for the art on a half tile that has none. A square block carrying
/// the figure at display size, so the post still reads as a solid object and
/// the row keeps its shape — without it the tile collapses to a line of text
/// and leaves a hole beside its neighbour.
private struct BentoAmountWell: View {

    let post: CDPost
    let accent: Color
    let ratio: CGFloat

    var body: some View {
        ZStack {
            BentoWellBackground(accent: accent, cornerRadius: 15, haloDiameter: 170)

            VStack(spacing: 8) {
                Capsule()
                    .fill(TPGradient.accent(accent))
                    .frame(width: 22, height: 3)

                if let parts = post.quantityParts {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(parts.value)
                            .font(.system(size: 33, weight: .heavy, design: .rounded))
                            .foregroundColor(.tpCream)
                            .lineLimit(1)
                            .minimumScaleFactor(0.45)

                        Text(parts.unit.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.tpCreamDim)
                            .lineLimit(1)
                            .minimumScaleFactor(0.55)
                    }
                }

                Image(systemName: post.kind.symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accent)
            }
            .padding(10)
        }
        .aspectRatio(ratio, contentMode: .fit)
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
        )
    }
}

/// The glass block that stands in for missing art, shared by both tile shapes.
///
/// The accent arrives as a bloom and a glyph, never as a fill. A flat wash of a
/// warm accent over the violet backdrop turns to mud — the same trap the
/// palette names for itself, where colour belongs to the backdrop and to
/// action, and surfaces stay glass.
private struct BentoWellBackground: View {

    let accent: Color
    let cornerRadius: CGFloat
    var haloDiameter: CGFloat = 150

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(.ultraThinMaterial)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.10))

            TPHalo(color: accent, strength: 0.34, diameter: haloDiameter)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// The art block: one tile cropped to the ratio the layout asks for, with the
/// kind tag and an overflow count laid over it.
private struct BentoCover: View {

    let post: CDPost
    let media: CDMedia
    /// Width ÷ height.
    let ratio: CGFloat
    var cornerRadius: CGFloat = 16
    var showsKindTag: Bool = true
    let accent: Color

    private var overflow: Int { post.sortedMedia.count - 1 }

    var body: some View {
        Color.clear
            .aspectRatio(ratio, contentMode: .fit)
            .overlay(
                TPMediaTile(media: media, cornerRadius: cornerRadius)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(alignment: .topLeading) {
                if showsKindTag {
                    BentoKindTag(post: post)
                        .padding(9)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if overflow > 0 {
                    Text("+\(overflow)")
                        .font(TPFont.figure(11.5, .bold))
                        .foregroundColor(.tpCream)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.55)))
                        .padding(9)
                }
            }
    }
}

/// A bare icon-and-count, used for the replies and gifts on a wide tile.
private struct BentoMiniAction: View {

    let symbol: String
    let count: Int
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(tint)

                if count > 0 {
                    Text("\(count)")
                        .font(TPFont.figure(11.5, .semibold))
                        .foregroundColor(.tpCreamDim)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
