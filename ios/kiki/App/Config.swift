import Foundation

enum Config {
    /// Read from Info.plist (`KikiAPIBaseURL`), set per build configuration.
    static let apiBaseURL: URL = {
        let value = Bundle.main.object(forInfoDictionaryKey: "KikiAPIBaseURL") as? String
        return URL(string: value ?? "") ?? URL(string: "https://kikirunning.com")!
    }()

    static let websiteURL = URL(string: "https://kikirunning.com")!
    static let privacyURL = URL(string: "https://kikirunning.com/privacy")!
    static let termsURL = URL(string: "https://kikirunning.com/terms")!
    static let supportURL = URL(string: "https://kikirunning.com/support")!
    static let supportEmail = "hello@moltcorporation.com"
    /// Recorded with each agreement as evidence of which Terms were shown:
    /// the legal pages' "last updated" date. Update it with those pages.
    static let legalVersion = "2026-09-30"

    static let revenueCatAPIKey = "appl_ppXlhrDnEMVOHybBpkcLCDGqREX"
    static let revenueCatTestStoreAPIKey = "test_NRcIEOCQlCzcXRJSErelwABhisd"
    static let entitlementID = "premium"
    /// Launch switch: while false there's no paywall (everyone goes straight
    /// into the app after their plan is ready). RevenueCat is still set up
    /// and identifies every user. Turn on with `PAYWALL_ENABLED` on the server.
    static let paywallEnabled = false

    static let postHogToken = "phc_8gxp6t8uX1YtlMqClOiCAXGB1sMNmZ1ul18q9yJMEpp"
    static let postHogHost = "https://us.i.posthog.com"

    static let appsFlyerDevKey = "q7DRdHdcBM2St39UQBXhfK"
    static let appleAppID = "6817469393"
    /// Kiki on the App Store, for sharing.
    static let appStoreURL = URL(string: "https://apps.apple.com/app/id\(appleAppID)")!
    /// Opens the App Store app straight to "Write a Review".
    static let writeReviewURL = URL(string: "itms-apps://apps.apple.com/app/id\(appleAppID)?action=write-review")!

}
