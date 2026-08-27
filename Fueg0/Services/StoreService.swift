import Foundation
import Observation
import StoreKit

enum StoreCatalog {
    static let productID = "fueg0_premium_monthly"
    static let trialDays = 7
    static let fallbackPriceLabel = "$2.99"
    static let productTitleFallback = "Fueg0 Premium Monthly"
}

enum LegalLinks {
    static let privacy = URL(string: "https://fueg0-431f7.web.app/privacy")!
    static let terms = URL(string: "https://fueg0-431f7.web.app/terms")!
}

/// StoreKit 2 entitlement. Never grants Premium from local prefs or a fake trial.
@MainActor
@Observable
final class StoreService {
    var product: Product?
    var isPremium = false
    var isOnTrial = false
    var trialDaysRemaining = 0
    var expirationDate: Date?
    var storeAvailable = false
    var isLoading = true
    var isPurchasing = false
    var introEligible = false
    var loadError: String?
    var lastMessage: String?

    var productTitle: String {
        let name = product?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? StoreCatalog.productTitleFallback : name
    }

    /// Recurring store price. Intro offers must not display as $0.00.
    var priceLabel: String {
        if let product {
            return product.displayPrice
        }
        return StoreCatalog.fallbackPriceLabel
    }

    var trialDaysFromStore: Int {
        guard let intro = product?.subscription?.introductoryOffer,
              intro.paymentMode == .freeTrial else {
            return StoreCatalog.trialDays
        }
        return Self.days(in: intro.period)
    }

    var showsIntroOffer: Bool {
        introEligible && product?.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    init() {
        Task { await listenForTransactionUpdates() }
        Task { await finishUnfinished() }
        Task { await refresh() }
    }

    func refresh() async {
        isLoading = product == nil
        loadError = nil
        await loadProducts()
        await refreshEntitlement()
        isLoading = false
    }

    @discardableResult
    func purchase() async -> Bool {
        lastMessage = nil
        guard let product else {
            lastMessage = "Store product unavailable."
            return false
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                await refreshEntitlement()
                lastMessage = isPremium ? "Premium unlocked." : "Purchase finished, but no entitlement yet."
                return isPremium
            case .userCancelled:
                lastMessage = "Purchase was not completed."
                return false
            case .pending:
                lastMessage = "Purchase is pending approval."
                return false
            @unknown default:
                lastMessage = "Purchase was not completed."
                return false
            }
        } catch {
            lastMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func restore() async -> Bool {
        lastMessage = nil
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            lastMessage = isPremium ? "Purchases restored." : "No purchases found."
            return isPremium
        } catch {
            lastMessage = error.localizedDescription
            return false
        }
    }

    private func loadProducts() async {
        do {
            let products = try await Product.products(for: [StoreCatalog.productID])
            product = products.first(where: { $0.id == StoreCatalog.productID })
            storeAvailable = product != nil
            if let subscription = product?.subscription {
                introEligible = await subscription.isEligibleForIntroOffer
            } else {
                introEligible = false
            }
            if product == nil {
                loadError = "Could not load Fueg0 Premium from the store."
            }
        } catch {
            storeAvailable = false
            product = nil
            introEligible = false
            loadError = error.localizedDescription
        }
    }

    private func refreshEntitlement() async {
        guard let result = await Transaction.currentEntitlement(for: StoreCatalog.productID) else {
            isPremium = false
            isOnTrial = false
            trialDaysRemaining = 0
            expirationDate = nil
            return
        }
        do {
            let transaction = try verified(result)
            let active = transaction.revocationDate == nil
                && (transaction.expirationDate.map { $0 > Date() } ?? true)
            isPremium = active
            expirationDate = transaction.expirationDate
            isOnTrial = active && transaction.offerType == .introductory
            if isOnTrial, let expiration = transaction.expirationDate {
                let days = Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0
                trialDaysRemaining = max(0, days)
            } else {
                trialDaysRemaining = 0
            }
        } catch {
            isPremium = false
            isOnTrial = false
            trialDaysRemaining = 0
            expirationDate = nil
        }
    }

    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            if let transaction = try? verified(result) {
                await transaction.finish()
                await refreshEntitlement()
            }
        }
    }

    private func finishUnfinished() async {
        for await result in Transaction.unfinished {
            if let transaction = try? verified(result) {
                await transaction.finish()
                await refreshEntitlement()
            }
        }
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    private static func days(in period: Product.SubscriptionPeriod) -> Int {
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return StoreCatalog.trialDays
        }
    }
}
