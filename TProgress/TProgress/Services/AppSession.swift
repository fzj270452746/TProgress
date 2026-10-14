import Foundation
import SwiftUI
import Combine
import CoreData
import AuthenticationServices

// MARK: - Errors

enum AuthError: LocalizedError, Equatable {

    case emptyUsername
    case emptyPassword
    case usernameTaken
    case invalidCredentials
    case passwordMismatch
    case passwordTooShort
    case usernameTooShort
    case appleUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyUsername:      return "Enter a username to continue."
        case .emptyPassword:      return "Enter your password to continue."
        case .usernameTaken:      return "That username is already taken."
        case .invalidCredentials: return "That username and password do not match."
        case .passwordMismatch:   return "The two passwords do not match."
        case .passwordTooShort:   return "Use at least 6 characters for your password."
        case .usernameTooShort:   return "Usernames need at least 3 characters."
        case .appleUnavailable:   return "Apple sign in is unavailable right now. Try again in a moment."
        }
    }
}

// MARK: - Session

/// Owns who is signed in, and gates every action that needs an account.
/// `withAuth` is the only door: it either runs the work or opens the auth sheet
/// and replays the work once the user is through.
final class AppSession: ObservableObject {

    static let shared = AppSession()

    @Published private(set) var currentUser: CDUser?

    @Published var isPresentingAuth = false
    @Published var authPrompt: String?

    /// Set when a report removes the signed-in user's own account.
    @Published var didDeleteAccount = false

    private var pendingAction: (() -> Void)?

    var isSignedIn: Bool { currentUser != nil }

    var accountName: String { currentUser?.name ?? "" }

    private init() {
        restore()
    }

    // MARK: - Gating

    /// Runs `action` now when signed in, otherwise opens the auth sheet and
    /// queues it. The queued work runs the moment sign in completes.
    func withAuth(prompt: String? = nil, _ action: @escaping () -> Void) {
        if isSignedIn {
            action()
            return
        }
        pendingAction = action
        authPrompt = prompt
        withAnimation(TPMotion.gentle) { isPresentingAuth = true }
    }

    func presentAuth(prompt: String? = nil) {
        withAuth(prompt: prompt) {}
    }

    func dismissAuth() {
        pendingAction = nil
        authPrompt = nil
        withAnimation(TPMotion.gentle) { isPresentingAuth = false }
    }

    private func runPendingAction() {
        let action = pendingAction
        pendingAction = nil
        authPrompt = nil
        action?()
    }

    // MARK: - Restore

    private func restore() {
        guard let username = TPSessionToken.username else { return }
        guard let user = Self.fetchUser(username: username) else {
            TPSessionToken.clear()
            return
        }
        markCurrent(user)
        currentUser = user
    }

    // MARK: - Password account

    func signIn(username: String, password: String) throws {
        let key = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { throw AuthError.emptyUsername }
        guard !password.isEmpty else { throw AuthError.emptyPassword }

        guard let account = AccountStore.shared.account(username: key) else {
            throw AuthError.invalidCredentials
        }
        guard account.matches(password: password) else {
            throw AuthError.invalidCredentials
        }

        establish(account)
    }

    func signUp(username: String, displayName: String, password: String, confirm: String) throws {
        let key = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard key.count >= 3 else { throw AuthError.usernameTooShort }
        guard !password.isEmpty else { throw AuthError.emptyPassword }
        guard password.count >= 6 else { throw AuthError.passwordTooShort }
        guard password == confirm else { throw AuthError.passwordMismatch }
        guard !AccountStore.shared.exists(username: key) else { throw AuthError.usernameTaken }

        let account = TPAccount.make(
            username: key,
            displayName: name.isEmpty ? key.capitalized : name,
            password: password
        )
        AccountStore.shared.add(account)
        establish(account)
    }

    /// The reviewer account shipped with the build.
    static let demoUsername = "test"
    static let demoPassword = "123456"

    // MARK: - Apple

    func handleApple(_ authorization: ASAuthorization) throws {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.appleUnavailable
        }

        let identifier = credential.user
        let username = "apple_" + identifier.replacingOccurrences(of: ".", with: "_").prefix(14).lowercased()

        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        let account: TPAccount
        if let existing = AccountStore.shared.account(username: String(username)) {
            account = existing
        } else {
            account = TPAccount.makeApple(
                username: String(username),
                displayName: name.isEmpty ? "Apple Member" : name
            )
            AccountStore.shared.add(account)
        }

        establish(account)
    }

    // MARK: - Establish

    private func establish(_ account: TPAccount) {
        let user: CDUser
        if let existing = Self.fetchUser(username: account.username) {
            user = existing
            if user.displayName?.isEmpty ?? true {
                user.displayName = account.displayName
            }
        } else {
            let created = CDUser(context: CoreDataStack.shared.context)
            created.id = UUID()
            created.username = account.username
            created.displayName = account.displayName
            created.bio = ""
            created.avatarSeed = Int64(abs(account.username.hashValue % 997))
            created.joinedAt = Date()
            created.streak = 0
            created.totalCheckIns = 0
            created.friendState = .none
            created.isBlocked = false
            created.isFollowedByMe = false
            created.followsMe = false
            CoreDataStack.shared.save()
            user = created
        }

        markCurrent(user)
        CoreDataStack.shared.save()

        TPSessionToken.username = account.username

        withAnimation(TPMotion.gentle) {
            currentUser = user
            isPresentingAuth = false
        }

        runPendingAction()
    }

    private func markCurrent(_ user: CDUser) {
        for candidate in CoreDataStack.shared.fetch(CDUser.self) {
            candidate.isCurrentUser = (candidate.objectID == user.objectID)
        }
    }

    private static func fetchUser(username: String) -> CDUser? {
        CoreDataStack.shared.fetch(
            CDUser.self,
            predicate: NSPredicate(format: "username ==[c] %@", username),
            limit: 1
        ).first
    }

    // MARK: - Profile

    func updateProfile(displayName: String, bio: String) {
        guard let user = currentUser else { return }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            user.displayName = name
            if let username = user.username {
                AccountStore.shared.update(username: username, displayName: name)
            }
        }
        user.bio = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        CoreDataStack.shared.save()
        objectWillChange.send()
    }

    /// Points the profile at a photo already copied into app storage.
    func updateAvatar(path: String?) {
        guard let user = currentUser else { return }
        if let previous = user.avatarAssetName, previous != path {
            TPMediaLibrary.remove(path: previous)
        }
        user.avatarAssetName = path
        CoreDataStack.shared.save()
        objectWillChange.send()
    }

    /// Redraws the generated sigil instead of uploading anything.
    func shuffleAvatarPattern() {
        guard let user = currentUser else { return }
        if let previous = user.avatarAssetName {
            TPMediaLibrary.remove(path: previous)
            user.avatarAssetName = nil
        }
        user.avatarSeed = Int64.random(in: 1...9_999)
        CoreDataStack.shared.save()
        objectWillChange.send()
        TPHaptic.tap()
    }

    // MARK: - Exit

    func signOut() {
        for user in CoreDataStack.shared.fetch(CDUser.self) {
            user.isCurrentUser = false
        }
        CoreDataStack.shared.save()
        TPSessionToken.clear()
        withAnimation(TPMotion.gentle) {
            currentUser = nil
        }
    }

    /// Removes the account and everything authored by it.
    func deleteAccount() {
        guard let user = currentUser else { return }

        if let username = user.username {
            AccountStore.shared.remove(username: username)
        }

        CommunityService.erase(user: user)
        TPSessionToken.clear()

        withAnimation(TPMotion.gentle) {
            currentUser = nil
            didDeleteAccount = true
        }
    }
}
