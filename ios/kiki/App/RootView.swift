import SwiftUI

/// Routes between welcome, onboarding, paywall and the main app.
struct RootView: View {
    @Environment(AuthService.self) private var auth
    @Environment(TrainingStore.self) private var store
    @Environment(Subscriptions.self) private var subscriptions
    @Environment(OnboardingModel.self) private var onboarding

    private enum Route: Equatable {
        case welcome, onboarding, loading, consent, needsPlan, paywall, main
    }

    private var route: Route {
        if !onboarding.path.isEmpty { return .onboarding }
        if !auth.isSignedIn { return .welcome }
        // Without the paywall, never wait on RevenueCat to open the app.
        if !store.hasLoaded || (Config.paywallEnabled && !subscriptions.hasLoaded) { return .loading }
        if store.needsConsent { return .consent }
        if store.plan == nil { return .needsPlan }
        if Config.paywallEnabled && !subscriptions.isPremium { return .paywall }
        return .main
    }

    /// Welcome ↔ onboarding uses the native iOS navigation push: onboarding
    /// slides over from the right while the welcome screen tucks underneath
    /// (a little to the left, dimmed); back is the exact reverse.
    /// Other route changes fade.
    private var isWelcomeHop: Bool { route == .welcome || route == .onboarding }

    private var routeAnimation: Animation {
        isWelcomeHop ? .smooth(duration: 0.45) : .smooth
    }

    var body: some View {
        ZStack {
            switch route {
            case .welcome:
                WelcomeView(onGetStarted: onboarding.start)
                    .transition(isWelcomeHop ? .underneath : .opacity)
            case .onboarding:
                OnboardingFlow()
                    .transition(isWelcomeHop ? .onTop : .opacity)
                    .zIndex(1)
            case .consent:
                ConsentGate()
            case .loading, .needsPlan:
                LaunchView()
                    .transition(.asymmetric(insertion: .identity, removal: .opacity.combined(with: .scale(scale: 1.08))))
            case .paywall:
                NavigationStack { PaywallView() }
            case .main:
                MainTabView()
            }
        }
        .animation(routeAnimation, value: route)
        .task(id: auth.isSignedIn) {
            guard let userID = auth.userID else { return }
            Identity.ensureIdentified(userID: userID, email: auth.email)
            await auth.recordPendingConsent()
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
            // Per-person display preference; the next runner starts fresh.
            UserDefaults.standard.removeObject(forKey: BodyUnits.storageKey)
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

// MARK: - Navigation push transitions

private extension AnyTransition {
    /// The incoming screen: slides fully in from the trailing edge, on top.
    static var onTop: AnyTransition {
        .modifier(active: PushedOnTop(progress: 1), identity: PushedOnTop(progress: 0))
    }

    /// The screen underneath: drifts 30% toward the leading edge and dims.
    static var underneath: AnyTransition {
        .modifier(active: TuckedUnderneath(progress: 1), identity: TuckedUnderneath(progress: 0))
    }
}

private struct PushedOnTop: ViewModifier {
    let progress: CGFloat

    func body(content: Content) -> some View {
        content
            .visualEffect { view, proxy in
                view.offset(x: proxy.size.width * progress)
            }
    }
}

private struct TuckedUnderneath: ViewModifier {
    let progress: CGFloat

    func body(content: Content) -> some View {
        content
            // Edge to edge, including the status bar and home indicator areas.
            .overlay {
                Color.black.opacity(0.25 * progress)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .visualEffect { view, proxy in
                view.offset(x: -proxy.size.width * 0.3 * progress)
            }
    }
}
