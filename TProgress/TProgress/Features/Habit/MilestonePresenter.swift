import SwiftUI
import Combine

// MARK: - Milestone presenter
//
// Owns the celebration for a streak rung, the way `GiftPresenter` owns the tray.
// Raised at the root so it covers whatever surface the log came from — the home
// chips, a circle page, or the chat sheet.

final class MilestonePresenter: ObservableObject {

    static let shared = MilestonePresenter()

    @Published private(set) var milestone: Int?
    @Published private(set) var freezeAwarded = 0

    private init() {}

    var isPresented: Bool { milestone != nil }

    /// Called after anything that lengthens a streak. Credits what is owed even
    /// when there is nothing to celebrate, so a payout is never lost.
    func consider() {
        if let result = HabitService.evaluateMilestones() {
            present(result.reached, cards: result.cards)
        }

        let cards = HabitService.grantPerfectWeekIfEarned()
        if cards > 0 {
            tpToast("A week kept whole · freeze card earned", tone: .success, symbol: "snowflake")
        }
    }

    func present(_ value: Int, cards: Int = 0) {
        freezeAwarded = cards
        TPHaptic.celebrate()
        withAnimation(TPMotion.spring) { milestone = value }
    }

    func dismiss() {
        withAnimation(TPMotion.gentle) { milestone = nil }
    }
}
