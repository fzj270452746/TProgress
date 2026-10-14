import SwiftUI
import Combine
import CoreData

// MARK: - Tabs

enum AppTab: String, CaseIterable, Identifiable {

    case today
    case circles
    case create
    case chats
    case me

    var id: String { rawValue }

    var label: String {
        switch self {
        case .today:   return "Today"
        case .circles: return "Circles"
        case .create:  return "Post"
        case .chats:   return "Chats"
        case .me:      return "You"
        }
    }

    /// The four destinations the dock actually selects. Create is an action.
    static var destinations: [AppTab] { [.today, .circles, .chats, .me] }
}

// MARK: - Routes

enum LegalDocument: String, Hashable, Identifiable {
    case terms
    case privacy
    case eula

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms:   return "Terms of Service"
        case .privacy: return "Privacy Policy"
        case .eula:    return "End User Licence Agreement"
        }
    }
}

enum TPRoute: Hashable {

    case post(UUID)
    case profile(UUID)
    case chat(UUID)
    case circle(UUID)
    case recap(UUID)
    case focus(UUID)
    case challenge(UUID)
    case myFollowers
    case compose
    case editProfile
    case myLikes
    case myFollowing
    case myWorks
    case freezeCards
    case insights
    case yearReview
    case about
    case legal(LegalDocument)
}

// MARK: - Router
//
// A stack per tab. Pushing anything hides the dock, which is what the brief
// asks for on every second-level page.

final class Router: ObservableObject {

    static let shared = Router()

    @Published var tab: AppTab = .today

    @Published private var stacks: [AppTab: [TPRoute]] = [:]

    private var backSwipeEnabled = true

    var stack: [TPRoute] { stacks[tab] ?? [] }

    var isAtRoot: Bool { stack.isEmpty }

    var canGoBack: Bool { !stack.isEmpty }

    // MARK: Navigation

    func push(_ route: TPRoute) {
        TPHaptic.tap()
        stacks[tab, default: []].append(route)
    }

    func pop() {
        guard !(stacks[tab] ?? []).isEmpty else { return }
        stacks[tab]?.removeLast()
    }

    func popToRoot() {
        guard !(stacks[tab] ?? []).isEmpty else { return }
        stacks[tab] = []
    }

    func select(_ tab: AppTab) {
        guard tab != .create else {
            push(.compose)
            return
        }
        guard tab != self.tab else {
            // Tapping the current tab returns to its root, like every other app.
            popToRoot()
            return
        }
        TPHaptic.tap()
        withAnimation(TPMotion.spring) { self.tab = tab }
    }

    /// Clears the current tab back to its root — used after a report removes
    /// the post or the person the page was built around.
    func returnToSource() {
        stacks[tab] = []
    }

    func clearAll() {
        stacks = [:]
        tab = .today
    }
}

// MARK: - Refresh signal
//
// Pages that must re-read after a deletion bump this. Cheap, and it keeps the
// report flow from reaching into view models directly.

final class RefreshSignal: ObservableObject {

    static let shared = RefreshSignal()

    @Published var feed = 0
    @Published var chats = 0
    @Published var profile = 0

    /// Raised when a circle's log changes — a check-in, an undo, a freeze card
    /// buying back a day. Pages that read derived counters listen to this one.
    @Published var practice = 0

    private init() {}

    func bumpFeed() { feed += 1 }
    func bumpChats() { chats += 1 }
    func bumpProfile() { profile += 1 }
    func bumpPractice() { practice += 1 }
}

// MARK: - Report presenter

final class ReportPresenter: ObservableObject {

    static let shared = ReportPresenter()

    @Published var target: ReportTarget?
    @Published var isPresented = false

    private init() {}

    func present(_ target: ReportTarget) {
        self.target = target
        withAnimation(TPMotion.gentle) { isPresented = true }
    }

    func dismiss() {
        withAnimation(TPMotion.gentle) { isPresented = false }
        target = nil
    }
}

// MARK: - Gift presenter
//
// The tray belongs to the app, not to a page. Raised at the root so it always
// sits above the dock, whichever surface opened it.

final class GiftPresenter: ObservableObject {

    static let shared = GiftPresenter()

    @Published var target: CDPost?

    private init() {}

    var isPresented: Bool { target != nil }

    func present(_ post: CDPost) {
        TPHaptic.tap()
        withAnimation(TPMotion.gentle) { target = post }
    }

    func dismiss() {
        withAnimation(TPMotion.gentle) { target = nil }
    }
}

// MARK: - Object lookup
//
// Routes carry identifiers, never managed objects, so a deleted object simply
// resolves to nothing instead of crashing on a stale reference.

enum TPStore {

    static func post(_ id: UUID) -> CDPost? {
        CoreDataStack.shared.fetch(
            CDPost.self,
            predicate: NSPredicate(format: "id == %@", id as CVarArg),
            limit: 1
        ).first
    }

    static func user(_ id: UUID) -> CDUser? {
        CoreDataStack.shared.fetch(
            CDUser.self,
            predicate: NSPredicate(format: "id == %@", id as CVarArg),
            limit: 1
        ).first
    }

    static func conversation(_ id: UUID) -> CDConversation? {
        CoreDataStack.shared.fetch(
            CDConversation.self,
            predicate: NSPredicate(format: "id == %@", id as CVarArg),
            limit: 1
        ).first
    }

    static func habit(_ id: UUID) -> CDHabit? {
        CoreDataStack.shared.fetch(
            CDHabit.self,
            predicate: NSPredicate(format: "id == %@", id as CVarArg),
            limit: 1
        ).first
    }

    static func challenge(_ id: UUID) -> CDChallenge? {
        CoreDataStack.shared.fetch(
            CDChallenge.self,
            predicate: NSPredicate(format: "id == %@", id as CVarArg),
            limit: 1
        ).first
    }
}
