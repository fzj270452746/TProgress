import SwiftUI
import UIKit

// MARK: - Tile

/// One piece of media. Video tiles resolve their own poster frame lazily so the
/// feed never blocks on decoding.
struct TPMediaTile: View {

    let media: CDMedia
    var cornerRadius: CGFloat = 16
    var showsChrome: Bool = true

    @State private var poster: UIImage?
    @State private var clipDuration: Double?

    /// The clip this row plays: a picked file in the container, or the clip
    /// shipped with the app. Nil for stills, and for picked files that are gone.
    private var clipURL: URL? {
        media.isVideo ? TPMediaLibrary.clipURL(forAsset: media.assetName) : nil
    }

    /// The real length when a clip ships, so the badge cannot promise a duration
    /// the player will not deliver. Seeded lengths stand in for stills.
    private var durationLabel: String? {
        if let clipDuration, clipDuration > 0 {
            return TPMediaLibrary.label(forDuration: clipDuration)
        }
        return media.durationLabel
    }

    var body: some View {
        ZStack {
            artwork

            if media.isVideo, showsChrome {
                videoChrome
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
        .task(id: media.assetName) {
            // Both reads hit `TPMediaLibrary`'s caches, so tiles sharing one clip
            // decode a single frame between them.
            guard let clipURL else { return }
            if poster == nil { poster = TPMediaLibrary.thumbnail(forVideoAt: clipURL) }
            if clipDuration == nil { clipDuration = TPMediaLibrary.duration(ofVideoAt: clipURL) }
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let poster {
            Image(uiImage: poster)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // The asset *name*, not a resolved path. `TPMediaFrame` looks the name
            // up in the catalogue first and falls back to proc art, which is what
            // lets the artwork pack drop in without a code change. Resolving to a
            // path here first would strand every catalogue image on the fallback.
            TPMediaFrame(assetName: media.assetName, seed: media.seed, cornerRadius: cornerRadius)
        }
    }

    private var videoChrome: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.42)],
                startPoint: .center,
                endPoint: .bottom
            )

            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.42))
                    .frame(width: 46, height: 46)
                Circle()
                    .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                    .frame(width: 46, height: 46)
                Image(systemName: "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .offset(x: 1.5)
            }

            if let duration = durationLabel {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(duration)
                            .font(TPFont.figure(11, .bold))
                            .foregroundColor(.tpCream)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule().fill(Color.black.opacity(0.55))
                            )
                    }
                }
                .padding(10)
            }
        }
    }
}

// MARK: - Strip (cards)
//
// One asset fills the width, two split it, three or more become a row with an
// overflow count. Keeps every card the same rhythm regardless of attachment count.

struct PostMediaStrip: View {

    let post: CDPost
    var maxVisible: Int = 3
    var cornerRadius: CGFloat = 16
    var onSelect: (Int) -> Void

    private var items: [CDMedia] { post.sortedMedia }

    var body: some View {
        Group {
            if items.isEmpty {
                EmptyView()
            } else if items.count == 1 {
                single
            } else {
                row
            }
        }
    }

    private var single: some View {
        Color.clear
            .aspectRatio(singleRatio, contentMode: .fit)
            .overlay(
                TPMediaTile(media: items[0], cornerRadius: cornerRadius)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { onSelect(0) }
    }

    /// Portrait art is capped so a tall image cannot dominate the whole feed.
    private var singleRatio: CGFloat {
        let ratio = items[0].aspectRatio
        return min(max(1 / ratio, 0.72), 1.5)
    }

    private var row: some View {
        let visible = Array(items.prefix(maxVisible))
        let overflow = items.count - visible.count

        return HStack(spacing: 8) {
            ForEach(Array(visible.enumerated()), id: \.offset) { index, media in
                ZStack {
                    TPMediaTile(media: media, cornerRadius: cornerRadius)

                    if overflow > 0 && index == visible.count - 1 {
                        ZStack {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(Color.black.opacity(0.58))
                            Text("+\(overflow)")
                                .font(TPFont.figure(19, .bold))
                                .foregroundColor(.tpCream)
                        }
                    }
                }
                .aspectRatio(0.82, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .contentShape(Rectangle())
                .onTapGesture { onSelect(index) }
            }
        }
    }
}

// MARK: - Stack (detail)
//
// The detail page reads top to bottom, and nothing on it moves sideways. A
// horizontal strip here let a post with two or three attachments be dragged
// left and right while the rest of the page only ever scrolled up and down.
// Every attachment now sits at full width in the page's own vertical flow, so
// the page has exactly one direction.

struct PostMediaStack: View {

    let post: CDPost
    var onSelect: (Int) -> Void

    private var items: [CDMedia] { post.sortedMedia }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, media in
                tile(media, index: index)
            }
        }
    }

    private func tile(_ media: CDMedia, index: Int) -> some View {
        Color.clear
            .aspectRatio(min(max(1 / media.aspectRatio, 0.74), 1.35), contentMode: .fit)
            .overlay(
                TPMediaTile(media: media, cornerRadius: 20)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(Rectangle())
            .onTapGesture { onSelect(index) }
    }
}

// MARK: - Quantity plate
//
// The concrete amount is the headline of every post. This is the piece that
// makes the feed read as a progress log rather than a social timeline.

struct TPQuantityPlate: View {

    let value: String
    let unit: String
    var detail: String?
    var accent: Color = .tpEmber
    var symbol: String?

    var body: some View {
        HStack(spacing: 13) {
            Capsule()
                .fill(TPGradient.accent(accent))
                .frame(width: 4, height: 40)

            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundColor(.tpCream)

                    if let symbol {
                        Image(systemName: symbol)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(accent)
                            .offset(y: -12)
                    }
                }

                // The unit sits in white, not in the accent. The accent already
                // carries this plate via the bar and the symbol; tinting the
                // label too made it vanish whenever the accent matched the
                // backdrop behind the card.
                Text.tpLabel(
                    detail.map { "\(unit) · \($0)" } ?? unit,
                    size: 9.5,
                    tracking: 1.5,
                    color: .tpCreamDim
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.14))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        }
    }
}
