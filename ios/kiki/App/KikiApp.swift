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

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(store)
                .environment(subscriptions)
                .environment(onboarding)
                .environment(tracker)
                .tint(.ink)
                .task { await subscriptions.observe() }
                .onAppear {
                    APIClient.shared.onUnauthorized = { [auth] in auth.clearSession() }
                }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await subscriptions.refresh()
                await store.flush()
            }
        }
    }
}
