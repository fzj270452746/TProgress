import SwiftUI
import CoreData

// MARK: - Chats
//
// Closed by default. Nothing here renders for a signed-out visitor — messaging
// only exists between people who have added each other.

struct ChatsView: View {

    @ObservedObject private var router = Router.shared
    @ObservedObject private var session = AppSession.shared
    @ObservedObject private var refresh = RefreshSignal.shared

    @State private var threads: [CDConversation] = []
    @State private var requests: [CDUser] = []

    var body: some View {
        ZStack {
            background

            if session.isSignedIn {
                signedIn
            } else {
                signedOut
            }
        }
        .onAppear(perform: reload)
        .onChange(of: session.isSignedIn) { _ in reload() }
        .onChange(of: refresh.chats) { _ in reload() }
    }

    private var background: some View {
        ZStack {
            // The shell paints the gradient ground; pages stay transparent so it
            // reads continuously across a push.
            Color.clear
            TPHalo(color: .tpSky, spread: 1.05)
                .offset(x: 120, y: -250)
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
                    GlyphChats().stroke(Color.tpSky, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                ),
                title: "Chats live behind an account",
                message: "TProgress only connects people who have both added each other. Sign in to see your threads and to add someone new.",
                actionTitle: "Sign in",
                action: {
                    session.presentAuth(prompt: "Sign in to open your chats.")
                },
                accent: .tpSky
            )

            Spacer(minLength: 0)
        }
        .padding(.horizontal, TPMetric.gutter)
        .padding(.bottom, TPMetric.dockClearance)
    }

    // MARK: Signed in

    private var signedIn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if !requests.isEmpty {
                    requestSection
                }

                threadSection
            }
            .padding(.bottom, TPMetric.dockClearance)
        }
        .tpDismissKeyboardOnTap()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text.tpLabel("Chats", size: 10, tracking: 1.8)

            Text("Your people")
                .font(TPFont.display(29, .heavy))
                .foregroundColor(.tpCream)

            Text("Threads are bound to real actions. When someone logs a session you will see it here, not just hear about it.")
                .font(TPFont.ui(13.5))
                .foregroundColor(.tpCreamDim)
                .lineSpacing(3.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, TPMetric.gutter)
        .padding(.top, 12)
    }

    // MARK: Requests

    private var requestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TPSectionHeader(label: "Requests", title: "Waiting on you")
                .padding(.horizontal, TPMetric.gutter)

            VStack(spacing: 10) {
                ForEach(requests, id: \.objectID) { person in
                    requestRow(person)
                }
            }
            .padding(.horizontal, TPMetric.gutter)
        }
    }

    private func requestRow(_ person: CDUser) -> some View {
        HStack(spacing: 12) {
            Button(action: { openProfile(person) }) {
                TPAvatar(
                    seed: person.avatarSeed,
                    name: person.name,
                    size: 46,
                    showsRing: true,
                    ringColor: .tpMint.opacity(0.6),
                    imagePath: person.avatarAssetName
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 3) {
                Text(person.name)
                    .font(TPFont.ui(15, .semibold))
                    .foregroundColor(.tpCream)

                Text("Wants to add you · \(person.handle)")
                    .font(TPFont.ui(12))
                    .foregroundColor(.tpCreamFaint)
            }

            Spacer(minLength: 8)

            Button {
                CommunityService.acceptFriendRequest(from: person)
                TPHaptic.success()
                tpToast("You are now friends with \(person.name)", tone: .success, symbol: "person.2.fill")
                reload()
            } label: {
                Text("Accept")
                    .font(TPFont.ui(12.5, .semibold))
                    .foregroundColor(.tpOnAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(TPGradient.ember))
            }
            .buttonStyle(.plain)

            Button {
                CommunityService.declineFriendRequest(from: person)
                TPHaptic.tap()
                reload()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.tpCreamFaint)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.tpInkWell))
            }
            .buttonStyle(.plain)
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(Color.tpMint.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .strokeBorder(Color.tpMint.opacity(0.28), lineWidth: 1)
        )
    }

    // MARK: Threads

    @ViewBuilder
    private var threadSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TPSectionHeader(label: "Friends", title: "Conversations")
                .padding(.horizontal, TPMetric.gutter)

            if threads.isEmpty {
                TPEmptyState(
                    symbol: "bubble.left.and.bubble.right",
                    title: "No conversations yet",
                    message: "Add someone from their profile. Once you have both accepted, a thread opens here and you can start with a small thing you actually did.",
                    accent: .tpSky
                )
                .padding(.horizontal, TPMetric.gutter)
            } else {
                // The reference's signature move: one neon-railed container
                // holding the whole list, with the rows as glass inside it.
                TPNeonRail(radius: 30, padding: 10, glow: 0.75, filled: false) {
                    VStack(spacing: 9) {
                        ForEach(threads, id: \.objectID) { thread in
                            threadRow(thread)
                        }
                    }
                }
                .padding(.horizontal, TPMetric.gutter)
            }
        }
    }

    private func threadRow(_ thread: CDConversation) -> some View {
        Button {
            guard let id = thread.id else { return }
            router.push(.chat(id))
        } label: {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    TPAvatar(
                        seed: thread.peer?.avatarSeed ?? 0,
                        name: thread.peer?.name ?? "?",
                        size: 50,
                        // Every contact wears the ring; unread just turns it
                        // ember. A ring that only appeared on unread rows made
                        // the list look half-finished.
                        showsRing: true,
                        ringColor: thread.hasUnread ? .tpEmber : nil,
                        imagePath: thread.peer?.avatarAssetName,
                        showsPresence: true
                    )

                    if thread.hasUnread {
                        Circle()
                            .fill(Color.tpEmber)
                            .frame(width: 12, height: 12)
                            .overlay(Circle().strokeBorder(Color.tpInk, lineWidth: 2))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(thread.peer?.name ?? "Someone")
                            .font(TPFont.ui(15, .semibold))
                            .foregroundColor(.tpCream)

                        Spacer(minLength: 4)

                        Text(thread.relativeTime)
                            .font(TPFont.ui(11.5))
                            .foregroundColor(.tpCreamFaint)
                    }

                    HStack(spacing: 6) {
                        Text(thread.preview)
                            .font(TPFont.ui(13))
                            .foregroundColor(thread.hasUnread ? .tpCream : .tpCreamDim)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        if thread.hasUnread {
                            Text("\(thread.unreadCount)")
                                .font(TPFont.figure(11, .bold))
                                .foregroundColor(.tpOnAccent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(Capsule().fill(TPGradient.ember))
                        }
                    }
                }
            }
            .padding(13)
            .background(
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .fill(Color.tpInkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 21, style: .continuous)
                    .strokeBorder(thread.hasUnread ? Color.tpEmber.opacity(0.34) : Color.tpLine, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: Data

    private func reload() {
        guard session.isSignedIn else {
            threads = []
            requests = []
            return
        }

        threads = CommunityService.conversations()
        requests = CoreDataStack.shared.fetch(
            CDUser.self,
            predicate: NSPredicate(format: "isCurrentUser == NO AND isBlocked == NO AND friendStateRaw == %@",
                                   FriendState.incoming.rawValue),
            sortBy: [TPSort.byDisplayName]
        )
    }

    private func openProfile(_ person: CDUser) {
        guard let id = person.id else { return }
        router.push(.profile(id))
    }
}
