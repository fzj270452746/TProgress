import Foundation
import CryptoKit
import Security

// MARK: - Keychain
//
// Only the session token lives here. Credentials themselves are salted and
// hashed before they touch disk.

enum TPKeychain {

    private static let service = "com.tpro.TProgress.session"

    static func set(_ value: String, for key: String) {
        guard let data = value.data(using: .utf8) else { return }
        remove(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    static func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Account
//
// A local credential record. Passwords are stored as a salted SHA-256 digest so
// the file on disk is never the plaintext.

struct TPAccount: Codable, Identifiable, Equatable {

    let id: UUID
    var username: String
    var displayName: String
    var salt: String
    var digest: String
    var provider: Provider
    var createdAt: Date

    enum Provider: String, Codable {
        case password
        case apple
    }

    static func make(
        username: String,
        displayName: String,
        password: String,
        provider: Provider = .password
    ) -> TPAccount {
        let salt = UUID().uuidString
        return TPAccount(
            id: UUID(),
            username: username.lowercased(),
            displayName: displayName,
            salt: salt,
            digest: TPAccount.digest(password: password, salt: salt),
            provider: provider,
            createdAt: Date()
        )
    }

    static func makeApple(username: String, displayName: String) -> TPAccount {
        TPAccount(
            id: UUID(),
            username: username.lowercased(),
            displayName: displayName,
            salt: "",
            digest: UUID().uuidString,
            provider: .apple,
            createdAt: Date()
        )
    }

    func matches(password: String) -> Bool {
        guard provider == .password else { return false }
        return TPAccount.digest(password: password, salt: salt) == digest
    }

    static func digest(password: String, salt: String) -> String {
        let data = Data((salt + password).utf8)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Store

/// Registered accounts, kept in Application Support as JSON. Deliberately
/// separate from the content store so signing out never touches the community.
final class AccountStore {

    static let shared = AccountStore()

    private let fileURL: URL
    private(set) var accounts: [TPAccount] = []

    private init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSTemporaryDirectory())

        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("accounts.json")

        load()
    }

    // MARK: Queries

    func account(username: String) -> TPAccount? {
        let key = username.lowercased()
        return accounts.first { $0.username == key }
    }

    func exists(username: String) -> Bool {
        account(username: username) != nil
    }

    // MARK: Mutations

    @discardableResult
    func add(_ account: TPAccount) -> TPAccount {
        if let index = accounts.firstIndex(where: { $0.username == account.username }) {
            accounts[index] = account
        } else {
            accounts.append(account)
        }
        persist()
        return account
    }

    func update(username: String, displayName: String) {
        guard let index = accounts.firstIndex(where: { $0.username == username.lowercased() }) else { return }
        accounts[index].displayName = displayName
        persist()
    }

    func remove(username: String) {
        accounts.removeAll { $0.username == username.lowercased() }
        persist()
    }

    // MARK: Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        accounts = (try? JSONDecoder().decode([TPAccount].self, from: data)) ?? []
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(accounts) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Session token

enum TPSessionToken {

    private static let key = "active.session.username"

    static var username: String? {
        get { TPKeychain.get(key) }
        set {
            if let newValue {
                TPKeychain.set(newValue, for: key)
            } else {
                TPKeychain.remove(key)
            }
        }
    }

    static func clear() {
        TPKeychain.remove(key)
    }
}
