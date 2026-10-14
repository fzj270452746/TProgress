import SwiftUI

// MARK: - Compact post row
//
// Used by the lists under You: likes, works and a profile's own shelf. Smaller
// than a card, same anatomy — who, how much, what was said.

struct CompactPostRow: View {

    let post: CDPost
    var showsAuthor: Bool = true
    var trailing: AnyView?
    var onOpen: () -> Void

    private var accent: Color { .tpAccent(seed: post.seed) }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(alignment: .top, spacing: 11) {
                    if showsAuthor {
                        TPAvatar(
                            seed: post.author?.avatarSeed ?? 0,
                            name: post.author?.name ?? "?",
                            size: 36,
                            imagePath: post.author?.avatarAssetName
                        )
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(showsAuthor ? (post.author?.name ?? "Someone") : post.kind.label)
                                .font(TPFont.ui(13.5, .semibold))
                                .foregroundColor(.tpCream)
                                .lineLimit(1)

                            Text("·")
                                .font(TPFont.ui(12))
                                .foregroundColor(.tpCreamFaint)

                            Text(post.relativeTime)
                                .font(TPFont.ui(11.5))
                                .foregroundColor(.tpCreamFaint)
                        }

                        Text(post.body)
                            .font(TPFont.ui(13.5))
                            .foregroundColor(.tpCream.opacity(0.88))
                            .lineSpacing(3)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 6)

                    if let trailing {
                        trailing
                    }
                }

                if post.hasMedia {
                    mediaThumbs
                }

                HStack(spacing: 16) {
                    if let quantity = post.quantityLabel {
                        TPTag(text: quantity, color: accent)
                    }

                    if let habit = post.habitName {
                        Text(habit)
                            .font(TPFont.ui(11.5))
                            .foregroundColor(.tpCreamFaint)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    miniStat(symbol: "heart.fill", value: Int(post.likeCount), tint: .tpBloom)
                    miniStat(symbol: "bubble.left.fill", value: post.commentCount, tint: .tpSky)
                    if post.giftCount > 0 {
                        miniStat(symbol: "gift.fill", value: Int(post.giftCount), tint: .tpSun)
                    }
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.tpInkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.tpLine, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var mediaThumbs: some View {
        HStack(spacing: 6) {
            ForEach(Array(post.sortedMedia.prefix(3).enumerated()), id: \.offset) { _, media in
                TPMediaTile(media: media, cornerRadius: 10, showsChrome: media.isVideo)
                    .frame(width: 54, height: 54)
            }

            if post.sortedMedia.count > 3 {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.tpInkWell)
                        .frame(width: 54, height: 54)
                    Text("+\(post.sortedMedia.count - 3)")
                        .font(TPFont.figure(12, .bold))
                        .foregroundColor(.tpCreamDim)
                }
            }
        }
    }

    private func miniStat(symbol: String, value: Int, tint: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(tint)
            Text("\(value)")
                .font(TPFont.figure(11.5, .semibold))
                .foregroundColor(.tpCreamDim)
        }
    }
}
