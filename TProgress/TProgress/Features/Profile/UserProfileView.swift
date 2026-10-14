import SwiftUI
import CoreData

// MARK: - User profile
//
// The third level. Reached from a post's author or the avatar on a thread.
// Reporting here removes the person and everything they posted, then hands the
// user back to the tab they came from.

struct UserProfileView: View {

    let user: CDUser

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var posts: [CDPost] = []
    @State private var appeared = false
    @State private var showBlockConfirm = false

    private var accent: Color { .tpAccent(seed: user.avatarSeed) }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 18) {
                    hero
                    statsRow
                    actionRow
                    shelf
                }
                .padding(.bottom, 50)
            }
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
        .onAppear(perform: reload)
        .onChange(of: refresh.feed) { _ in reload() }
        .onChange(of: refresh.profile) { _ in reload() }
        .confirmationDialog(
            "Block \(user.name)?",
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button("Block and remove", role: .destructive) {
                CommunityService.block(user)
                RefreshSignal.shared.bumpFeed()
                RefreshSignal.shared.bumpChats()
                router.returnToSource()
                tpToast("\(user.name) was blocked", tone: .success, symbol: "hand.raised")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Their posts and conversations are removed from your view.")
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            TPIconButton(symbol: "chevron.left", size: 38) { router.pop() }

            VStack(alignment: .leading, spacing: 2) {
                Text("Profile")
                    .font(TPFont.display(21, .bold))
                    .foregroundColor(.tpCream)

                Text(user.handle)
                    .font(TPFont.ui(11.5))
                    .foregroundColor(.tpCreamFaint)
            }

            Spacer(minLength: 8)

            if !user.isCurrentUser {
                TPIconButton(symbol: "flag", size: 38, tint: .tpCreamDim) {
                    ReportPresenter.shared.present(.user(user))
                }
            }
        }
        .padding(.horizontal, TPMetric.gutter)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                TPArt(seed: user.avatarSeed &* 5 &+ 7, cornerRadius: 0)
                    .frame(height: 132)
                    .overlay(
                        LinearGradient(
                            colors: [Color.tpInk.opacity(0.1), Color.tpInk.opacity(0.85)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipped()

                TPAvatar(
                    seed: user.avatarSeed,
                    name: user.name,
                    size: 88,
                    showsRing: true,
                    ringColor: accent,
                    imagePath: user.avatarAssetName
                )
                .offset(x: TPMetric.gutter, y: 44)
            }
            // The avatar hangs 44pt below the banner, and the block underneath
            // paints an opaque card fill. Without this it was drawn over the
            // avatar's lower half, squaring off its corners and cutting the
            // monogram through the descender.
            .zIndex(1)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(user.name)
                        .font(TPFont.display(25, .bold))
                        .foregroundColor(.tpCream)

                    if user.isFriend {
                        TPTag(text: "Friend", color: .tpMint)
                    }
                }

                Text(user.joinedLabel)
                    .font(TPFont.ui(12))
                    .foregroundColor(.tpCreamFaint)

                Text(user.bioText)
                    .font(TPFont.ui(14))
                    .foregroundColor(.tpCreamDim)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.tpSun)
                        Text("\(user.streak) day streak")
                            .font(TPFont.ui(12, .medium))
                            .foregroundColor(.tpCreamDim)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.tpMint)
                        Text("\(user.totalCheckIns) sessions")
                            .font(TPFont.ui(12, .medium))
                            .foregroundColor(.tpCreamDim)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, TPMetric.gutter)
            .padding(.top, 54)
            .padding(.bottom, 18)
            .background(TPGradient.card)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
        .padding(.horizontal, TPMetric.gutter)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            DispatchQueue.main.async { withAnimation(TPMotion.gentle) { appeared = true } }
        }
    }

    // MARK: Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            TPStatTile(value: "\(posts.count)", caption: "Posts", color: accent, symbol: "square.stack")
            TPStatTile(value: "\(user.followingCount)", caption: "Following", color: .tpMint, symbol: "person.2")
            TPStatTile(value: "\(user.followerCount)", caption: "Followers", color: .tpLilac, symbol: "person.crop.circle.badge.checkmark")
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.tpInkRaised)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.tpLine, lineWidth: 1)
        )
        .padding(.horizontal, TPMetric.gutter)
    }

    // MARK: Actions

    @ViewBuilder
    private var actionRow: some View {
        if user.isCurrentUser {
            EmptyView()
        } else {
            HStack(spacing: 10) {
                Button(action: toggleFollow) {
                    HStack(spacing: 7) {
                        Image(systemName: user.isFollowedByMe ? "checkmark" : "plus")
                            .font(.system(size: 13, weight: .bold))
                        Text(user.isFollowedByMe ? "Following" : "Follow")
                            .font(TPFont.ui(15, .semibold))
                    }
                    .foregroundColor(user.isFollowedByMe ? .tpCream : .tpOnAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
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

                friendAction
            }
            .padding(.horizontal, TPMetric.gutter)
        }
    }

    /// Hidden entirely once the two are friends — a message button replaces it.
    @ViewBuilder
    private var friendAction: some View {
        switch user.friendState {
        case .friends:
            Button(action: openThread) {
                friendButtonLabel(title: "Message", symbol: "bubble.left", filled: false, tint: .tpSky)
            }
            .buttonStyle(.plain)

        case .requested:
            Text("Requested")
                .font(TPFont.ui(15, .semibold))
                .foregroundColor(.tpCreamFaint)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Capsule().fill(Color.tpInkWell))
                .overlay(Capsule().strokeBorder(Color.tpLine, lineWidth: 1))

        case .incoming:
            Button(action: acceptRequest) {
                friendButtonLabel(title: "Accept", symbol: "person.badge.plus", filled: true, tint: .tpMint)
            }
            .buttonStyle(.plain)

        case .none:
            Button(action: sendRequest) {
                friendButtonLabel(title: "Add friend", symbol: "person.badge.plus", filled: false, tint: .tpMint)
            }
            .buttonStyle(.plain)
        }
    }

    private func friendButtonLabel(title: String, symbol: String, filled: Bool, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
            Text(title)
                .font(TPFont.ui(15, .semibold))
        }
        .foregroundColor(filled ? .tpInk : tint)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
            Capsule(style: .continuous)
                .fill(filled ? AnyShapeStyle(TPGradient.accent(tint)) : AnyShapeStyle(tint.opacity(0.13)))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(filled ? Color.clear : tint.opacity(0.36), lineWidth: 1)
        )
    }

    // MARK: Shelf

    private var shelf: some View {
        VStack(alignment: .leading, spacing: 14) {
            TPSectionHeader(label: "Shelf", title: "What they have logged")
                .padding(.horizontal, TPMetric.gutter)

            if posts.isEmpty {
                TPEmptyState(
                    symbol: "square.stack",
                    title: "Nothing published",
                    message: "\(user.name) has not logged anything yet.",
                    accent: accent
                )
                .padding(.horizontal, TPMetric.gutter)
            } else {
                VStack(spacing: 12) {
                    ForEach(posts, id: \.objectID) { post in
                        CompactPostRow(post: post, showsAuthor: false) {
                            guard let id = post.id else { return }
                            router.push(.post(id))
                        }
                    }
                }
                .padding(.horizontal, TPMetric.gutter)
            }
        }
    }

    // MARK: Actions

    private func toggleFollow() {
        session.withAuth(prompt: "Sign in to follow \(user.name).") {
            CommunityService.toggleFollow(user)
            TPHaptic.tap()
        }
    }

    private func sendRequest() {
        session.withAuth(prompt: "Sign in to add \(user.name).") {
            CommunityService.sendFriendRequest(to: user)
            TPHaptic.success()
            tpToast("Request sent to \(user.name)", tone: .success, symbol: "paperplane")
            reload()
        }
    }

    private func acceptRequest() {
        session.withAuth(prompt: "Sign in to add \(user.name).") {
            CommunityService.acceptFriendRequest(from: user)
            TPHaptic.success()
            tpToast("You are now friends with \(user.name)", tone: .success, symbol: "person.2.fill")
            RefreshSignal.shared.bumpChats()
            reload()
        }
    }

    private func openThread() {
        guard let thread = CommunityService.conversation(with: user), let id = thread.id else { return }
        router.push(.chat(id))
    }

    private func reload() {
        posts = user.sortedPosts
    }
}
