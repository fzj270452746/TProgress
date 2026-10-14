import SwiftUI
import Combine

// MARK: - Root
//
// Owns the tab roots, the navigation stacks, the dock, and every app-level
// surface: auth, report, the call screen and full screen media.

struct RootView: View {

    @StateObject private var router = Router.shared
    @StateObject private var session = AppSession.shared
    @StateObject private var reporter = ReportPresenter.shared
    @StateObject private var gifts = GiftPresenter.shared
    @StateObject private var caller = CallService.shared
    @StateObject private var media = MediaPresenter.shared
    @StateObject private var milestones = MilestonePresenter.shared

    var body: some View {
        ZStack {
            // One gradient ground for the whole shell, cross-faded when the
            // destination changes so the colour moves with the content instead
            // of snapping. Pushed pages inherit it and stay transparent.
            TPBackdropView(style: TPBackdrop.forTab(router.tab))
                .id(router.tab)
                .transition(.opacity)
                .animation(TPMotion.gentle, value: router.tab)

            // Pages and the dock share one layer, so anything raised above it —
            // the tray, a call, full screen media — covers the dock too.
            ZStack {
                tabRoot
                    .zIndex(0)

                ForEach(Array(router.stack.enumerated()), id: \.offset) { index, route in
                    routeView(route)
                        .zIndex(Double(index) + 1)
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .trailing),
                                removal: .move(edge: .trailing)
                            )
                        )
                }
            }
            .animation(TPMotion.gentle, value: router.stack)
            .overlay(alignment: .bottom) { dockLayer }
            .animation(TPMotion.gentle, value: router.isAtRoot)

            callOverlay
            mediaOverlay
            milestoneOverlay
        }
        .tpSheet(isPresented: giftBinding) { giftSheet }
        .sheet(isPresented: $session.isPresentingAuth) {
            AuthSheet()
        }
        .sheet(isPresented: $reporter.isPresented) {
            reportSheet
        }
        .onChange(of: session.isSignedIn) { isSignedIn in
            if !isSignedIn { router.clearAll() }
        }
        .tpToastHost()
        .tpLoadingGate()
        .preferredColorScheme(.dark)
    }

    // MARK: - Gift

    private var giftBinding: Binding<Bool> {
        Binding(
            get: { gifts.isPresented },
            set: { if !$0 { gifts.dismiss() } }
        )
    }

    @ViewBuilder
    private var giftSheet: some View {
        if let post = gifts.target {
            GiftTray(post: post) { _ in
                gifts.dismiss()
                tpToast("Gift sent", tone: .success, symbol: "gift.fill")
            }
        }
    }

    // MARK: - Tab roots

    @ViewBuilder
    private var tabRoot: some View {
        switch router.tab {
        case .today:   TodayView()
        case .circles: CirclesView()
        case .chats:   ChatsView()
        case .me:      MeView()
        case .create:  TodayView()
        }
    }

    private var tabBinding: Binding<AppTab> {
        Binding(
            get: { router.tab },
            set: { router.select($0) }
        )
    }

    // MARK: - Dock

    @ViewBuilder
    private var dockLayer: some View {
        if router.isAtRoot {
            TPDock(selection: tabBinding, onCreate: { router.push(.compose) })
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Routes

    @ViewBuilder
    private func routeView(_ route: TPRoute) -> some View {
        switch route {
        case .post(let id):
            if let post = TPStore.post(id) {
                PostDetailView(post: post)
            } else {
                missingPage(title: "Post unavailable")
            }

        case .profile(let id):
            if let user = TPStore.user(id) {
                UserProfileView(user: user)
            } else {
                missingPage(title: "Profile unavailable")
            }

        case .chat(let id):
            if let thread = TPStore.conversation(id) {
                ChatDetailView(thread: thread)
            } else {
                missingPage(title: "Conversation unavailable")
            }

        case .circle(let id):
            if let habit = TPStore.habit(id) {
                CircleDetailView(habit: habit)
            } else {
                missingPage(title: "Circle unavailable")
            }

        case .recap(let id):
            if let habit = TPStore.habit(id) {
                RecapDetailView(habit: habit)
            } else {
                missingPage(title: "Recap unavailable")
            }

        case .focus(let id):
            if let habit = TPStore.habit(id) {
                FocusTimerView(habit: habit)
            } else {
                missingPage(title: "Circle unavailable")
            }

        case .challenge(let id):
            if let challenge = TPStore.challenge(id) {
                ChallengeDetailView(challenge: challenge)
            } else {
                missingPage(title: "Challenge unavailable")
            }

        case .myFollowers:
            MyFollowersView()

        case .compose:
            ComposeView()

        case .editProfile:
            EditProfileView()

        case .myLikes:
            MyLikesView()

        case .myFollowing:
            MyFollowingView()

        case .myWorks:
            MyWorksView()

        case .freezeCards:
            FreezeCardsView()

        case .insights:
            InsightsView()

        case .yearReview:
            YearInReviewView()

        case .about:
            AboutView()

        case .legal(let document):
            LegalView(document: document)
        }
    }

    private func missingPage(title: String) -> some View {
        VStack(spacing: 0) {
            TPPageHeader(title: title, onBack: { router.pop() })
            TPEmptyState(
                symbol: "questionmark.circle",
                title: "Nothing here",
                message: "This item was removed. Head back and pick another one."
            )
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .tpBackdrop(.deep)
    }

    // MARK: - Overlays

    @ViewBuilder
    private var callOverlay: some View {
        if caller.isActive, let peer = caller.peer {
            TPCallScreen(peer: peer, phase: caller.phase) { caller.hangUp() }
                .zIndex(500)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var mediaOverlay: some View {
        if media.isPresented, let content = media.content {
            TPFullscreenMedia(content: content) { media.dismiss() }
                .zIndex(600)
                .transition(.opacity)
        }
    }

    // MARK: - Milestone

    @ViewBuilder
    private var milestoneOverlay: some View {
        if milestones.isPresented, let value = milestones.milestone {
            MilestoneCelebration(
                value: value,
                freezeCards: milestones.freezeAwarded
            ) {
                milestones.dismiss()
            }
            .zIndex(700)
            .transition(.opacity)
        }
    }

    // MARK: - Report

    @ViewBuilder
    private var reportSheet: some View {
        if let target = reporter.target {
            ReportView(target: target) { outcome in
                reporter.dismiss()
                switch outcome {
                case .stay:
                    // The reply is already gone from Core Data, but the page
                    // that listed it is still holding the row it built for it.
                    RefreshSignal.shared.bumpFeed()
                case .leaveAndRefresh:
                    // A removed post or person takes the page it lived on with it.
                    router.returnToSource()
                    RefreshSignal.shared.bumpFeed()
                    RefreshSignal.shared.bumpChats()
                }
            }
        }
    }
}
