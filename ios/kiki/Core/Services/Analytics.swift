import AppsFlyerLib
import Foundation
import PostHog
import RevenueCat

/// Product analytics and error tracking (PostHog). No session replay.
enum Analytics {
    static func configure() {
        let config = PostHogConfig(projectToken: Config.postHogToken, host: Config.postHogHost)
        config.sessionReplay = false
        config.captureScreenViews = false
        config.captureApplicationLifecycleEvents = true
        config.errorTrackingConfig.autoCapture = true
        #if DEBUG
        config.debug = false
        #endif
        PostHogSDK.shared.setup(config)
    }

    static func track(_ event: String, _ properties: [String: Any] = [:]) {
        PostHogSDK.shared.capture(event, properties: properties)
    }

    static func screen(_ name: String, _ properties: [String: Any] = [:]) {
        PostHogSDK.shared.screen(name, properties: properties)
    }

    static func captureError(_ error: Error, context: [String: Any] = [:]) {
        if error is CancellationError { return }
        PostHogSDK.shared.captureException(error, properties: context)
    }
}

/// Keeps the signed-in user ID consistent across PostHog, RevenueCat and AppsFlyer.
enum Identity {
    static func identify(userID: String, email: String?) {
        var props: [String: Any] = [:]
        if let email { props["email"] = email }
        PostHogSDK.shared.identify(userID, userProperties: props)

        AppsFlyerLib.shared().customerUserID = userID

        Task {
            do {
                _ = try await Purchases.shared.logIn(userID)
                let attribution = Purchases.shared.attribution
                attribution.collectDeviceIdentifiers()
                attribution.setAppsflyerID(AppsFlyerLib.shared().getAppsFlyerUID())
                attribution.setPostHogUserID(userID)
                if let email { attribution.setEmail(email) }
            } catch {
                Analytics.captureError(error, context: ["step": "revenuecat_login"])
            }
        }
    }

    /// Re-identifies on launch when a session exists but an SDK lost the user
    /// (e.g. after a reinstall, where the Keychain session survives).
    static func ensureIdentified(userID: String, email: String?) {
        let needsRevenueCat = Purchases.shared.appUserID != userID
        let needsPostHog = PostHogSDK.shared.getDistinctId() != userID
        if needsRevenueCat || needsPostHog {
            identify(userID: userID, email: email)
        } else {
            AppsFlyerLib.shared().customerUserID = userID
        }
    }

    static func reset() {
        PostHogSDK.shared.reset()
        AppsFlyerLib.shared().customerUserID = nil
        Task {
            guard !Purchases.shared.isAnonymous else { return }
            _ = try? await Purchases.shared.logOut()
        }
    }
}
