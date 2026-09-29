import SwiftUI

/// Routes between welcome, onboarding, paywall and the main app.
struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(TrainingStore.self) private var store
    @Environment(Subscriptions.self) private var subscriptions
    @Environment(OnboardingModel.self) private var onboarding

    private enum Route: Equatable {
        case welcome, onboarding, loading, needsPlan, paywall, main
    }

    private var route: Route {
        if !onboarding.path.isEmpty { return .onboarding }
        if !auth.isSignedIn { return .welcome }
        if !store.hasLoaded || !subscriptions.hasLoaded { return .loading }
        if store.plan == nil { return .needsPlan }
        if !subscriptions.isPremium { return .paywall }
        return .main
    }

    var body: some View {
        ZStack {
            switch route {
            case .welcome:
                WelcomeView(onGetStarted: onboarding.start, onSignedIn: {})
            case .onboarding:
                OnboardingFlow()
            case .loading, .needsPlan:
                LaunchView()
            case .paywall:
                NavigationStack { PaywallView() }
            case .main:
                MainTabView()
            }
        }
        .animation(.smooth, value: route)
        .task(id: auth.isSignedIn) {
            guard auth.isSignedIn else { return }
            onboarding.isSignedIn = true
            await store.refresh()
        }
        .onChange(of: route) { _, route in
            // Signed in without a plan (e.g. a returning runner): build one.
            if route == .needsPlan {
                onboarding.isSignedIn = true
                onboarding.start()
            }
        }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            guard !signedIn else { return }
            store.reset()
            onboarding.reset()
            onboarding.isSignedIn = false
            Notifications.cancelAll()
        }
    }
}

struct LaunchView: View {
    var body: some View {
        KikiLogo(size: 88)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.paper)
    }
}
