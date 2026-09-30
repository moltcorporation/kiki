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
                    .transition(.asymmetric(insertion: .identity, removal: .opacity.combined(with: .scale(scale: 1.08))))
            case .paywall:
                NavigationStack { PaywallView() }
            case .main:
                MainTabView()
            }
        }
        .animation(.smooth, value: route)
        .task(id: auth.isSignedIn) {
            guard let userID = auth.userID else { return }
            Identity.ensureIdentified(userID: userID, email: auth.email)
            onboarding.isSignedIn = true
            var loaded = await store.refresh()
            // Signed in from onboarding's account step (or resumed there): a
            // returning runner with a plan goes to the app, otherwise build one.
            // Decide only on a confirmed server answer, never on a failed load.
            if onboarding.current == .account {
                var delay = 1.0
                while !loaded {
                    try? await Task.sleep(for: .seconds(delay))
                    if Task.isCancelled { return }
                    delay = min(delay * 2, 10)
                    loaded = await store.refresh()
                }
                if store.plan != nil {
                    onboarding.reset()
                } else {
                    onboarding.go(to: .generating)
                }
            }
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

/// Continues `LaunchScreen.storyboard` (same texture, aspect-filled, and the
/// wordmark centered on the full screen) while the session and subscription
/// load, so opening the app reads as one seamless splash.
struct LaunchView: View {
    var body: some View {
        GeometryReader { proxy in
            Image(.launchTexture)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .overlay {
                    Image(.launchWordmark).accessibilityLabel("Kiki")
                }
        }
        .background(Color.launchBackground)
        .ignoresSafeArea()
    }
}
