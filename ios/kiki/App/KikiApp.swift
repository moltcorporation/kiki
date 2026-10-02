import SwiftUI

@main
struct KikiApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    @State private var auth = AuthService()
    @State private var store = TrainingStore()
    @State private var subscriptions = Subscriptions()
    @State private var onboarding = OnboardingModel()
    @State private var tracker = RunTracker()
    @State private var health = HealthService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(store)
                .environment(subscriptions)
                .environment(onboarding)
                .environment(tracker)
                .environment(health)
                .tint(.ink)
                // Web links open in an in-app browser.
                .environment(\.openURL, InAppBrowser.openURLAction)
                .task { await subscriptions.observe() }
                // Runs from other apps, via Apple Health: now and as they arrive.
                .task(id: store.plan?.id) {
                    await health.sync(into: store)
                    health.startObserving(store)
                }
                .onAppear {
                    APIClient.shared.onUnauthorized = { [auth] in auth.clearSession() }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await subscriptions.refresh()
                await store.flush()
                await health.sync(into: store)
            }
        }
    }
}
