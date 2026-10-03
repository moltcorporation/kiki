import Foundation
import RevenueCat

/// Subscription state from RevenueCat, kept live via the customer info stream.
@Observable
final class Subscriptions {
    private(set) var isPremium = false
    private(set) var hasLoaded = false
    private(set) var offering: Offering?
    private(set) var activeExpiration: Date?
    private(set) var isInTrial = false

    /// Pro, or the paywall is switched off (`Config.paywallEnabled`).
    var hasAccess: Bool { isPremium || !Config.paywallEnabled }

    /// The RevenueCat paywall, shown full screen over the app.
    var isPaywallPresented = false
    private(set) var paywallSource = ""

    /// Opens the paywall (after onboarding, or from a locked feature).
    func presentPaywall(_ source: String) {
        guard Config.paywallEnabled, !isPremium else { return }
        paywallSource = source
        isPaywallPresented = true
        Analytics.track("paywall_presented", ["source": source])
    }

    func closePaywall() { isPaywallPresented = false }

    static func configure() {
        #if DEBUG
        Purchases.logLevel = .warn
        // RevenueCat Test Store: simulated purchases without App Store setup.
        Purchases.configure(withAPIKey: Config.revenueCatTestStoreAPIKey)
        #else
        Purchases.configure(withAPIKey: Config.revenueCatAPIKey)
        #endif
    }

    /// Listens for entitlement changes for the lifetime of the app.
    func observe() async {
        for await info in Purchases.shared.customerInfoStream {
            apply(info)
        }
    }

    func refresh() async {
        do {
            apply(try await Purchases.shared.customerInfo())
        } catch {
            // Offline with no cached info: don't block the app on RevenueCat.
            hasLoaded = true
        }
    }

    /// Returns whether an active subscription was found.
    func restore() async throws -> Bool {
        let info = try await Purchases.shared.restorePurchases()
        apply(info)
        return isPremium
    }

    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements.active[Config.entitlementID]
        isPremium = entitlement != nil
        activeExpiration = entitlement?.expirationDate
        isInTrial = entitlement?.periodType == .trial
        hasLoaded = true
    }
}
