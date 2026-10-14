import SwiftUI
import CoreData

// MARK: - Me
//
// Signed out it is a single, calm invitation. Signed in it is the profile plus
// every door out of it, including the two that need confirming twice.

struct MeView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared

    @State private var posts: [CDPost] = []
    @State private var followingCount = 0
    @State private var followerCount = 0
    @State private var showSignOutConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showDeleteFinal = false

    var body: some View {
        ZStack {
            background

            if session.isSignedIn, let user = session.currentUser {
                signedIn(user)
            } else {
                signedOut
            }
        }
        .onAppear(perform: reload)
        .onChange(of: session.isSignedIn) { _ in reload() }
    }

    private var background: some View {
        ZStack {
            // The shell paints the gradient ground; pages stay transparent so it
            // reads continuously across a push.
            Color.clear
            TPHalo(color: .tpEmber, spread: 1.05)
                .offset(x: -110, y: -250)
            TPGrain(opacity: 0.04)
        }
        .ignoresSafeArea()
    }

    // MARK: Signed out

    private var signedOut: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            TPEmptyState(
                glyph: AnyView(
                    GlyphMe().stroke(Color.tpEmber, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                ),
                title: "You are browsing",
                message: "Sign in to keep your log, your circles and your threads in one place. Everything here stays on this device.",
                actionTitle: "Sign in or create an account",
                action: {
                    session.presentAuth(prompt: "Sign in to see your profile.")
                },
                accent: .tpEmber
            )

            Spacer(minLength: 0)

            TPLegalFooter { document in
                session.presentAuth(prompt: nil)
                _ = document
            }
            .padding(.horizontal, 30)
            .padding(.bottom, TPMetric.dockClearance)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, TPMetric.gutter)
    }

    // MARK: Signed in

    private func signedIn(_ user: CDUser) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                profileCard(user)
                quickActions
                accountSection
            }
            .padding(.bottom, TPMetric.dockClearance)
        }
        .tpDismissKeyboardOnTap()
        .confirmationDialog(
            "Sign out of TProgress?",
            isPresented: $showSignOutConfirm,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) { performSignOut() }
            Button("Stay signed in", role: .cancel) {}
        } message: {
            Text("Your posts and circles stay on this device. You can sign back in at any time.")
        }
        .confirmationDialog(
            "Delete your account?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Continue", role: .destructive) { showDeleteFinal = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your profile, your posts, your replies and your conversations.")
        }
        .alert("This cannot be undone", isPresented: $showDeleteFinal) {
            Button("Delete everything", role: .destructive) { performDelete() }
            Button("Keep my account", role: .cancel) {}
        } message: {
            Text("There is no recovery once your account is deleted.")
        }
    }

    // MARK: Profile card

    private func profileCard(_ user: CDUser) -> some View {
        Button {
            if let id = user.id { router.push(.profile(id)) }
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    TPAvatar(
                        seed: user.avatarSeed,
                        name: user.name,
                        size: 68,
                        showsRing: true,
                        ringColor: .tpEmber,
                        imagePath: user.avatarAssetName
                    )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(user.name)
                            .font(TPFont.display(23, .bold))
                            .foregroundColor(.tpCream)
                            .lineLimit(1)

                        Text(user.handle)
                            .font(TPFont.ui(13))
                            .foregroundColor(.tpCreamFaint)

                        Text(user.joinedLabel)
                            .font(TPFont.ui(11.5))
                            .foregroundColor(.tpCreamFaint)
                    }

                    Spacer(minLength: 6)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.tpCreamFaint)
                        .padding(.top, 6)
                }

                Text(user.bioText)
                    .font(TPFont.ui(14))
                    .foregroundColor(.tpCreamDim)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                TPFadeRule()

                HStack(spacing: 0) {
                    TPStatTile(value: "\(posts.count)", caption: "Posts", color: .tpEmber, symbol: "square.stack")
                    TPStatTile(value: "\(followingCount)", caption: "Following", color: .tpMint, symbol: "person.2")
                    TPStatTile(value: "\(followerCount)", caption: "Followers", color: .tpLilac, symbol: "person.crop.circle.badge.checkmark")
                    TPStatTile(value: "\(user.streak)", caption: "Streak", color: .tpSun, symbol: "flame.fill")
                }
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(TPGradient.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.tpLine, lineWidth: 1)
            )
            .tpShadow(20, y: 12, opacity: 0.32)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, TPMetric.gutter)
        .padding(.top, 14)
    }

    // MARK: Quick actions

    private var quickActions: some View {
        // Laid out in rows of three rather than one long strip, so the grid can
        // keep growing as the profile gains destinations without the tiles
        // getting narrower each time.
        let rows = stride(from: 0, to: quickTiles.count, by: 3).map {
            Array(quickTiles[$0..<min($0 + 3, quickTiles.count)])
        }

        return VStack(spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.title) { tile in
                        quickTile(symbol: tile.symbol, title: tile.title, accent: tile.accent) {
                            router.push(tile.route)
                        }
                    }

                    // Keeps a short final row aligned with the ones above it.
                    if row.count < 3 {
                        ForEach(0..<(3 - row.count), id: \.self) { _ in
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, TPMetric.gutter)
    }

    private struct QuickTile {
        let symbol: String
        let title: String
        let accent: Color
        let route: TPRoute
    }

    private var quickTiles: [QuickTile] {
        [
            QuickTile(symbol: "square.and.pencil", title: "Edit profile",
                      accent: .tpEmber, route: .editProfile),
            QuickTile(symbol: "square.stack", title: "My works",
                      accent: .tpLilac, route: .myWorks),
            QuickTile(symbol: "heart", title: "Liked",
                      accent: .tpBloom, route: .myLikes),
            QuickTile(symbol: "person.2", title: "Following",
                      accent: .tpMint, route: .myFollowing),
            QuickTile(symbol: "person.2.badge.plus", title: "Followers",
                      accent: .tpSky, route: .myFollowers),
            QuickTile(symbol: "chart.xyaxis.line", title: "Insights",
                      accent: .tpSun, route: .insights),
            QuickTile(symbol: "snowflake", title: "Freeze cards",
                      accent: .tpSky, route: .freezeCards)
        ]
    }

    private func quickTile(
        symbol: String,
        title: String,
        accent: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            TPHaptic.tap()
            action()
        }) {
            VStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(accent.opacity(0.14))
                        .frame(width: 42, height: 42)

                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(accent)
                }

                Text(title)
                    .font(TPFont.ui(10.5, .semibold))
                    .foregroundColor(.tpCreamDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(Color.tpInkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .strokeBorder(Color.tpLine, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Account
    //
    // The tiles above are the whole of the profile navigation, and the counts
    // they would list are already on the profile card. A second list repeating
    // them read as a group nobody had deleted, so what is left here is only what
    // the tiles do not cover.

    private var accountSection: some View {
        VStack(spacing: 10) {
            TPRow(symbol: "info.circle", title: "About TProgress", accent: .tpSky) {
                router.push(.about)
            }
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.tpInkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Color.tpLine, lineWidth: 1)
            )

            TPFadeRule()
                .padding(.top, 4)
                .padding(.bottom, 4)

            TPOutlineButton(title: "Sign out", symbol: "rectangle.portrait.and.arrow.right") {
                showSignOutConfirm = true
            }

            Button {
                TPHaptic.tap()
                showDeleteConfirm = true
            } label: {
                Text("Delete account")
                    .font(TPFont.ui(15, .semibold))
                    .foregroundColor(.tpDanger)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.plain)

            Text("Deleting removes your profile and everything you posted from this device.")
                .font(TPFont.ui(11.5))
                .foregroundColor(.tpCreamFaint)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)

            TPLegalFooter { _ in
                router.push(.legal(.terms))
            }
            .padding(.top, 12)
        }
        .padding(.horizontal, TPMetric.gutter)
        .padding(.top, 8)
    }

    // MARK: Actions

    private func performSignOut() {
        Task {
            await TPLoadingRun.run(message: "Signing you out") {
                session.signOut()
                TPHaptic.success()
                Router.shared.clearAll()
            }
        }
    }

    private func performDelete() {
        Task {
            await TPLoadingRun.run(minimumDuration: 1.2, message: "Deleting your account") {
                session.deleteAccount()
                TPHaptic.warning()
                Router.shared.clearAll()
                tpToast("Your account has been deleted", tone: .success, symbol: "checkmark")
            }
        }
    }

    // MARK: Data

    private func reload() {
        guard let user = session.currentUser else {
            posts = []
            followingCount = 0
            followerCount = 0
            return
        }

        posts = user.sortedPosts
        followingCount = user.followingCount
        followerCount = user.followerCount
    }
}
