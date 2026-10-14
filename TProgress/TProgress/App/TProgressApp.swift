import SwiftUI

@main
struct TProgressApp: App {

    init() {
        Bootstrap.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// MARK: - Bootstrap
//
// One ordered start-up: open the store, plant the community, make sure the
// shipped account exists, then warm the store front.

enum Bootstrap {

    static func start() {
        _ = CoreDataStack.shared

        Seeder.seedIfNeeded()
        ensurePrimaryAccount()

        // Touching the session restores the signed-in account, which the
        // backfill needs in order to settle its streak and totals.
        _ = AppSession.shared
        Backfill.runIfNeeded()

        Task { await StoreKitService.shared.loadProducts() }
    }

    /// Keeps the shipped credentials valid even if the account file is cleared,
    /// so a reviewer is never locked out of their own build.
    private static func ensurePrimaryAccount() {
        let username = AppSession.demoUsername
        guard AccountStore.shared.account(username: username) == nil else { return }

        let account = TPAccount.make(
            username: username,
            displayName: "You",
            password: AppSession.demoPassword
        )
        AccountStore.shared.add(account)
    }
}
