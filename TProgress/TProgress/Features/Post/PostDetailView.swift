import SwiftUI
import UIKit
import CoreData

// MARK: - Post detail
//
// Everything the post carries, plus the thread underneath it. Media opens full
// screen from here; on the feed a tap goes to this page instead.

struct PostDetailView: View {

    let post: CDPost

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var media = MediaPresenter.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var comments: [CDComment] = []
    @State private var draft = ""
    @State private var isSharing = false
    @State private var sortNewestFirst = true

    /// The page shows the like count twice — on the action bar and in the stat
    /// plate — and Core Data does not publish the change to either, so the
    /// plate keeps its own copy. Nil until the first tap, which means the post
    /// is the only source until then.
    @State private var likeCount: Int?

    @FocusState private var composerFocused: Bool

    private var accent: Color { .tpAccent(seed: post.seed) }
    private var author: CDUser? { post.author }

    var body: some View {
        VStack(spacing: 0) {
            header

            TPVerticalScroll {
                VStack(alignment: .leading, spacing: 16) {
                    authorRow

                    if let quantity = post.quantityLabel {
                        TPQuantityPlate(
                            value: numericPart(of: quantity),
                            unit: unitPart(of: quantity),
                            detail: post.habitName,
                            accent: accent,
                            symbol: post.kind.symbol
                        )
                    }

                    if !post.body.isEmpty {
                        Text(post.body)
                            .font(TPFont.ui(16))
                            .foregroundColor(.tpCream)
                            .lineSpacing(5.5)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if post.hasMedia {
                        PostMediaStack(post: post) { index in
                            openMedia(at: index)
                        }
                    }

                    if post.giftCount > 0 {
                        PostGiftSummary(post: post)
                    }

                    statsRow

                    TPFadeRule()

                    PostActionBar(
                        post: post,
                        showsLabels: true,
                        onLikeChanged: { likeCount = Int(post.likeCount) },
                        onComment: { composerFocused = true },
                        onGift: {
                            session.withAuth(prompt: "Sign in to send a gift.") {
                                GiftPresenter.shared.present(post)
                            }
                        },
                        onShare: { isSharing = true }
                    )

                    TPFadeRule()

                    commentsSection
                }
                .padding(.horizontal, TPMetric.gutter)
                .padding(.bottom, 26)
            }
            .tpDismissKeyboardOnTap()

            composer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                // A pushed page covers the tab root, so it paints its own ground. Kept
                // deeper than a tab's so forms and long reads stay comfortable.
                TPBackdropView(style: .deep)
                TPGrain(opacity: 0.04)
            }
            .ignoresSafeArea()
        )
        .sheet(isPresented: $isSharing) {
            TPShareSheet(items: ["\(author?.name ?? "Someone") on TProgress: \(post.body)"])
        }
        .onAppear(perform: reloadComments)
        .onChange(of: refresh.feed) { _ in reloadComments() }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            TPIconButton(symbol: "chevron.left", size: 38) { router.pop() }

            VStack(alignment: .leading, spacing: 2) {
                Text(post.kind.label)
                    .font(TPFont.display(21, .bold))
                    .foregroundColor(.tpCream)

                Text(post.relativeTime)
                    .font(TPFont.ui(11.5))
                    .foregroundColor(.tpCreamFaint)
            }

            Spacer(minLength: 8)

            TPTag(text: post.habitName ?? "General", color: accent)

            menu
        }
        .padding(.horizontal, TPMetric.gutter)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(
            TPBarFill(edge: .bottom)
                .overlay(alignment: .bottom) { TPFadeRule() }
                .ignoresSafeArea(edges: .top)
        )
    }

    private var menu: some View {
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
                    RefreshSignal.shared.bumpFeed()
                    router.popToRoot()
                    tpToast("Post removed", tone: .success, symbol: "trash")
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
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.tpCreamFaint)
                .frame(width: 30, height: 30)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 30)
    }

    // MARK: Author

    private var authorRow: some View {
        HStack(spacing: 12) {
            Button(action: openAuthor) {
                TPAvatar(
                    seed: author?.avatarSeed ?? 0,
                    name: author?.name ?? "?",
                    size: 46,
                    showsRing: true,
                    ringColor: accent.opacity(0.6),
                    imagePath: author?.avatarAssetName
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(author?.name ?? "Someone")
                        .font(TPFont.ui(15.5, .semibold))
                        .foregroundColor(.tpCream)

                    if author?.isFriend == true {
                        TPTag(text: "Friend", color: .tpMint)
                    }
                }

                Text(author?.handle ?? "")
                    .font(TPFont.ui(12.5))
                    .foregroundColor(.tpCreamFaint)
            }

            Spacer(minLength: 8)

            if let author, !author.isCurrentUser {
                followButton(author)
            }
        }
    }

    private func followButton(_ user: CDUser) -> some View {
        Button(action: {
            session.withAuth(prompt: "Sign in to follow \(user.name).") {
                CommunityService.toggleFollow(user)
                TPHaptic.tap()
            }
        }) {
            Text(user.isFollowedByMe ? "Following" : "Follow")
                .font(TPFont.ui(12.5, .semibold))
                .foregroundColor(user.isFollowedByMe ? .tpCreamDim : .tpOnAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(user.isFollowedByMe
                              ? AnyShapeStyle(Color.tpInkWell)
                              : AnyShapeStyle(TPGradient.ember))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(user.isFollowedByMe ? Color.tpLine : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            TPStatTile(value: "\(likeCount ?? Int(post.likeCount))", caption: "Cheers", color: .tpBloom, symbol: "heart.fill")
            TPStatTile(value: "\(post.commentCount)", caption: "Replies", color: .tpSky, symbol: "bubble.left.fill")
            TPStatTile(value: "\(post.giftCount)", caption: "Gifts", color: .tpSun, symbol: "gift.fill")
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
    }

    // MARK: Comments

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                Text.tpLabel("Replies")
                Spacer(minLength: 8)

                if comments.count > 1 {
                    Button {
                        TPHaptic.tap()
                        withAnimation(TPMotion.gentle) {
                            sortNewestFirst.toggle()
                            reloadComments()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 9, weight: .bold))
                            Text(sortNewestFirst ? "Newest" : "Oldest")
                                .font(TPFont.ui(11.5, .semibold))
                        }
                        .foregroundColor(.tpCreamFaint)
                    }
                    .buttonStyle(.plain)
                }
            }

            if comments.isEmpty {
                HStack(spacing: 11) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 15, weight: .light))
                        .foregroundColor(.tpCreamFaint)

                    Text("No replies yet. Be the first to say something useful.")
                        .font(TPFont.ui(13.5))
                        .foregroundColor(.tpCreamFaint)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(comments, id: \.objectID) { comment in
                        CommentRow(comment: comment, accent: accent) {
                            reloadComments()
                        }
                        .transition(.opacity)

                        if comment.objectID != comments.last?.objectID {
                            TPFadeRule()
                        }
                    }
                }
            }
        }
    }

    // MARK: Composer

    @ViewBuilder
    private var composer: some View {
        if session.isSignedIn {
            HStack(alignment: .bottom, spacing: 10) {
                TPAvatar(
                    seed: session.currentUser?.avatarSeed ?? 0,
                    name: session.currentUser?.name ?? "?",
                    size: 34
                )

                ZStack(alignment: .topLeading) {
                    if draft.isEmpty {
                        Text("Add something useful…")
                            .font(TPFont.ui(14.5))
                            .foregroundColor(.tpCreamFaint)
                            .padding(.top, 9)
                            .padding(.leading, 5)
                    }

                    // The multi-line axis on TextField is iOS 16, so this stays
                    // a single-line field with a fixed tap target.
                    TextField("", text: $draft)
                        .font(TPFont.ui(14.5))
                        .foregroundColor(.tpCream)
                        .focused($composerFocused)
                        .tint(.tpEmber)
                        .submitLabel(.send)
                        .onSubmit(submitComment)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 9)
                }
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .fill(Color.tpInkRaised)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .strokeBorder(composerFocused ? Color.tpEmber.opacity(0.5) : Color.tpLine, lineWidth: 1)
                )

                sendButton
            }
            .padding(.horizontal, TPMetric.gutter)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(
                TPBarFill(edge: .bottom)
                    .overlay(alignment: .top) { TPFadeRule() }
                    .ignoresSafeArea(edges: .bottom)
            )
            .transition(.move(edge: .bottom))
        } else {
            Button(action: {
                session.presentAuth(prompt: "Sign in to join the conversation.")
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Sign in to reply")
                        .font(TPFont.ui(15, .semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.tpEmber)
                .padding(.horizontal, 18)
                .frame(height: 52)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.tpEmber.opacity(0.12))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.tpEmber.opacity(0.32), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, TPMetric.gutter)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(
                TPBarFill(edge: .bottom)
                    .overlay(alignment: .top) { TPFadeRule() }
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    private var sendButton: some View {
        Button(action: submitComment) {
            ZStack {
                Circle()
                    .fill(canSend
                          ? AnyShapeStyle(TPGradient.ember)
                          : AnyShapeStyle(Color.tpInkWell))
                    .frame(width: 44, height: 44)

                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(canSend ? .tpOnAccent : .tpCreamFaint)
            }
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .animation(TPMotion.snappy, value: canSend)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitComment() {
        guard canSend else { return }
        let text = draft
        draft = ""
        composerFocused = false

        guard CommunityService.addComment(to: post, text: text) != nil else { return }
        TPHaptic.success()
        withAnimation(TPMotion.spring) { reloadComments() }
        RefreshSignal.shared.bumpFeed()
    }

    // MARK: Actions

    private func openAuthor() {
        guard let author, let id = author.id else { return }
        if author.isCurrentUser {
            session.dismissAuth()
        } else {
            router.push(.profile(id))
        }
    }

    private func openMedia(at index: Int) {
        let items = post.sortedMedia
        guard items.indices.contains(index) else { return }
        let item = items[index]
        let name = item.assetName ?? ""

        // A clip shipped with the app resolves exactly like a picked file does.
        // Only a picked file that has since gone missing fails to resolve, which
        // is the one case the toast is for.
        if item.isVideo {
            guard let url = TPMediaLibrary.clipURL(forAsset: item.assetName) else {
                tpToast("This attachment has no file yet.", tone: .warning, symbol: "photo")
                return
            }
            media.show(.video(url, seed: item.seed))
        } else {
            guard TPIconResolver.image(pathOrName: name) != nil else {
                tpToast("This attachment has no file yet.", tone: .warning, symbol: "photo")
                return
            }
            media.show(.image(name, seed: item.seed))
        }
    }

    private func reloadComments() {
        let all = post.sortedComments
        comments = sortNewestFirst ? all.reversed() : all
    }

    // MARK: Helpers

    private func numericPart(of label: String) -> String {
        label.split(separator: " ").first.map(String.init) ?? label
    }

    private func unitPart(of label: String) -> String {
        let parts = label.split(separator: " ").dropFirst()
        return parts.isEmpty ? "" : parts.joined(separator: " ")
    }
}

// MARK: - Vertical-only scroll
//
// A vertical `ScrollView` still takes whatever width its content asks for, and
// content wider than the viewport turns the whole page into something the
// reader can drag sideways — the page shows correctly and moves anyway. Pinning
// the content to the viewport width makes the page vertical by construction, so
// no post, however wide its media or its longest unbroken word, can reintroduce
// a horizontal drag.

private struct TPVerticalScroll<Content: View>: View {

    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { viewport in
            ScrollView {
                content()
                    .frame(width: viewport.size.width, alignment: .leading)
            }
        }
    }
}

// MARK: - Comment row

struct CommentRow: View {

    let comment: CDComment
    var accent: Color = .tpEmber
    var onChange: () -> Void

    @ObservedObject private var session = AppSession.shared

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Button(action: openAuthor) {
                TPAvatar(
                    seed: comment.author?.avatarSeed ?? 0,
                    name: comment.author?.name ?? "?",
                    size: 34,
                    imagePath: comment.author?.avatarAssetName
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(comment.author?.name ?? "Someone")
                        .font(TPFont.ui(13.5, .semibold))
                        .foregroundColor(.tpCream)
                        .lineLimit(1)

                    if comment.isMine {
                        TPTag(text: "You", color: accent)
                    }

                    Text("·")
                        .foregroundColor(.tpCreamFaint)

                    Text(comment.relativeTime)
                        .font(TPFont.ui(11.5))
                        .foregroundColor(.tpCreamFaint)

                    Spacer(minLength: 6)

                    CommentOverflowMenu(comment: comment, onChange: onChange)
                }

                Text(comment.body)
                    .font(TPFont.ui(14))
                    .foregroundColor(.tpCream.opacity(0.92))
                    .lineSpacing(3.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }

            Spacer(minLength: 6)

            Button(action: {
                session.withAuth(prompt: "Sign in to cheer replies on.") {
                    CommunityService.toggleCommentLike(comment)
                    onChange()
                }
            }) {
                VStack(spacing: 3) {
                    Image(systemName: comment.isLikedByMe ? "heart.fill" : "heart")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(comment.isLikedByMe ? .tpBloom : .tpCreamFaint)

                    if comment.likeCount > 0 {
                        Text("\(comment.likeCount)")
                            .font(TPFont.figure(10.5, .semibold))
                            .foregroundColor(.tpCreamFaint)
                    }
                }
                .frame(width: 30)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 13)
    }

    private func openAuthor() {
        guard let author = comment.author, let id = author.id, !author.isCurrentUser else { return }
        Router.shared.push(.profile(id))
    }
}

// MARK: - Reply overflow menu
//
// The same ellipsis a post wears, for the replies under it. It is the only
// route to report a reply, and a long press was not a discoverable one.

struct CommentOverflowMenu: View {

    let comment: CDComment
    var size: CGFloat = 26
    var onChange: () -> Void

    var body: some View {
        Menu {
            Button {
                UIPasteboard.general.string = comment.body
                tpToast("Copied to clipboard", tone: .success, symbol: "doc.on.doc")
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            if comment.isMine {
                Button(role: .destructive) {
                    CommunityService.delete(comment: comment)
                    onChange()
                    tpToast("Reply removed", tone: .success, symbol: "trash")
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } else {
                Button(role: .destructive) {
                    ReportPresenter.shared.present(.comment(comment))
                } label: {
                    Label("Report reply", systemImage: "flag")
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: size * 0.46, weight: .bold))
                .foregroundColor(.tpCreamFaint)
                .frame(width: size, height: size)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: size)
    }
}
