import AppTrackingTransparency
import AppsFlyerLib
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Analytics.configure()
        Subscriptions.configure()
        configureAppsFlyer()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    private func configureAppsFlyer() {
        let appsFlyer = AppsFlyerLib.shared()
        #if DEBUG
        appsFlyer.isDebug = true
        #endif
        appsFlyer.initialize(devKey: Config.appsFlyerDevKey, appId: Config.appleAppID)
        // Set the customer user ID before start so sessions are tied to the user.
        if let userID = Keychain.userID {
            appsFlyer.customerUserID = userID
        }
        // Fires once per foreground cycle. On app open, ask for tracking
        // permission first (iOS shows it only once), then start the session.
        appsFlyer.registerSessionReadyListener {
            Task { @MainActor in
                await Self.requestTrackingAuthorizationIfNeeded()
                do {
                    let dictionary = try await AppsFlyerLib.shared().start()
                    #if DEBUG
                    print("[AppsFlyer] started: \(dictionary)")
                    #endif
                } catch {
                    #if DEBUG
                    print("[AppsFlyer] start error: \(error)")
                    #endif
                }
            }
        }
    }

    private static func requestTrackingAuthorizationIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        let status = await ATTrackingManager.requestTrackingAuthorization()
        Analytics.track("att_prompt_answered", ["authorized": status == .authorized])
    }

    // Show notifications while the app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
