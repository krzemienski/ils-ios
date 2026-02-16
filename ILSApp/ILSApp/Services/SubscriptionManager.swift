import Foundation
import StoreKit
import Observation

// MARK: - Subscription Type

/// Represents the user's current subscription tier.
enum SubscriptionType: String, Sendable {
    case none
    case monthly
    case annual
}

// MARK: - SubscriptionManager

/// Manages StoreKit 2 subscription lifecycle including purchasing, restoring, and
/// entitlement verification.
///
/// Uses async/await StoreKit 2 APIs for all transaction operations. Listens for
/// real-time transaction updates to keep entitlement state current.
///
/// ## Product IDs
/// - `com.ils.app.premium.monthly` — Monthly premium subscription
/// - `com.ils.app.premium.annual` — Annual premium subscription
///
/// ## Usage
/// ```swift
/// let manager = SubscriptionManager.shared
/// if manager.isPremium {
///     // Show premium features
/// }
/// ```
@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    // MARK: - Product IDs

    static let monthlyProductID = "com.ils.app.premium.monthly"
    static let annualProductID = "com.ils.app.premium.annual"

    private static let productIDs: Set<String> = [
        monthlyProductID,
        annualProductID
    ]

    // MARK: - Published State

    /// Whether the user currently has an active premium subscription.
    private(set) var isPremium: Bool = false

    /// The current subscription type (monthly, annual, or none).
    private(set) var subscriptionType: SubscriptionType = .none

    /// Expiration date of the current subscription, if any.
    private(set) var expirationDate: Date?

    /// Whether a purchase or restore operation is in progress.
    private(set) var isLoading: Bool = false

    /// Available StoreKit products fetched from the App Store.
    private(set) var products: [Product] = []

    /// Last error message from a failed operation.
    private(set) var errorMessage: String?

    // MARK: - Private

    /// Listener task that observes `Transaction.updates` for the lifetime of the app.
    /// Not cancelled because this is a singleton that lives for the entire process.
    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Init

    private init() {
        transactionListenerTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
        Task { [weak self] in
            await self?.checkSubscriptionStatus()
            await self?.fetchProducts()
        }
    }

    // MARK: - Fetch Products

    /// Loads available subscription products from the App Store.
    func fetchProducts() async {
        do {
            let storeProducts = try await Product.products(for: Self.productIDs)
            // Sort so monthly appears before annual
            products = storeProducts.sorted { lhs, rhs in
                lhs.price < rhs.price
            }
            errorMessage = nil
        } catch {
            AppLogger.shared.error(
                "Failed to fetch products: \(error.localizedDescription)",
                category: "storekit"
            )
            errorMessage = "Unable to load subscription options. Please try again."
        }
    }

    // MARK: - Purchase

    /// Initiates a purchase for the given product.
    /// - Parameter product: The StoreKit `Product` to purchase.
    /// - Returns: `true` if the purchase succeeded, `false` otherwise.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await checkSubscriptionStatus()
                AppLogger.shared.info(
                    "Purchase successful: \(product.id)",
                    category: "storekit"
                )
                return true

            case .userCancelled:
                AppLogger.shared.info(
                    "Purchase cancelled by user",
                    category: "storekit"
                )
                return false

            case .pending:
                AppLogger.shared.info(
                    "Purchase pending approval",
                    category: "storekit"
                )
                errorMessage = "Purchase is pending approval."
                return false

            @unknown default:
                AppLogger.shared.warning(
                    "Unknown purchase result",
                    category: "storekit"
                )
                return false
            }
        } catch {
            AppLogger.shared.error(
                "Purchase failed: \(error.localizedDescription)",
                category: "storekit"
            )
            errorMessage = "Purchase failed. Please try again."
            return false
        }
    }

    // MARK: - Restore Purchases

    /// Restores previously purchased subscriptions.
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await checkSubscriptionStatus()
            AppLogger.shared.info(
                "Purchases restored successfully",
                category: "storekit"
            )
        } catch {
            AppLogger.shared.error(
                "Restore failed: \(error.localizedDescription)",
                category: "storekit"
            )
            errorMessage = "Unable to restore purchases. Please try again."
        }
    }

    // MARK: - Check Subscription Status

    /// Verifies current entitlements by iterating `Transaction.currentEntitlements`.
    func checkSubscriptionStatus() async {
        var foundPremium = false
        var foundType: SubscriptionType = .none
        var foundExpiration: Date?

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else {
                continue
            }

            if Self.productIDs.contains(transaction.productID) {
                foundPremium = true

                if transaction.productID == Self.monthlyProductID {
                    foundType = .monthly
                } else if transaction.productID == Self.annualProductID {
                    foundType = .annual
                }

                foundExpiration = transaction.expirationDate
            }
        }

        isPremium = foundPremium
        subscriptionType = foundType
        expirationDate = foundExpiration
    }

    // MARK: - Transaction Listener

    /// Listens for real-time transaction updates (renewals, revocations, refunds).
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard let transaction = try? checkVerified(result) else {
                continue
            }
            await transaction.finish()
            await checkSubscriptionStatus()
        }
    }

    // MARK: - Verification

    /// Unwraps a verified transaction or throws on verification failure.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
