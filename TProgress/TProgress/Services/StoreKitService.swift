import Foundation
import StoreKit
import Combine

// MARK: - Result

enum TPPurchaseResult {
    case success
    case cancelled
    case pending
    case unavailable
    case failed(String)
}

// MARK: - Store

/// Gift tokens are consumables. Products are loaded once at launch and the
/// catalogue falls back to its own price labels if the store cannot be reached,
/// so the tray always renders even before App Store Connect exists.
final class StoreKitService: ObservableObject {

    static let shared = StoreKitService()

    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var didAttemptLoad = false

    var isStoreAvailable: Bool { !products.isEmpty }

    private init() {}

    // MARK: Loading

    func loadProducts() async {
        guard !isLoading else { return }
        isLoading = true
        defer {
            isLoading = false
            didAttemptLoad = true
        }

        let identifiers = TPGiftCatalog.all.map(\.productID)
        do {
            let loaded = try await Product.products(for: identifiers)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        } catch {
            products = [:]
        }
    }

    /// Localised price from the store when available, catalogue price otherwise.
    func priceLabel(for gift: TPGift) -> String {
        products[gift.productID]?.displayPrice ?? gift.priceLabel
    }

    // MARK: Purchasing

    func purchase(_ gift: TPGift) async -> TPPurchaseResult {
        if products[gift.productID] == nil {
            await loadProducts()
        }

        guard let product = products[gift.productID] else {
            return .unavailable
        }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    return .failed("That purchase could not be verified.")
                }
                await transaction.finish()
                return .success

            case .userCancelled:
                return .cancelled

            case .pending:
                return .pending

            @unknown default:
                return .failed("That purchase could not be completed.")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
