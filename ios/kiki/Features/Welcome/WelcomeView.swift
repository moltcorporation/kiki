import SwiftUI

/// First screen: a full-bleed running video with the pitch and sign-up
/// actions over a dark, grainy gradient. Always dark, whatever the system
/// appearance, so the brand colors invert to white on the footage.
struct WelcomeView: View {
    let onGetStarted: () -> Void
    let onSignedIn: () -> Void

    @State private var showSignIn = false
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .bottom) {
            LoopingVideo(video: "welcome", poster: "welcome-poster.jpg")

            // A light fade so the status bar reads over the bright sky.
            LinearGradient(colors: [.black.opacity(0.35), .black.opacity(0)], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.18))
                .ignoresSafeArea()

            // Darkens the lower half so the text reads cleanly on any frame.
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0), location: 0.35),
                    .init(color: .black.opacity(0.55), location: 0.62),
                    .init(color: .black.opacity(0.9), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Fine film grain: a gritty, filmic finish that also hides
            // banding in the gradient.
            Image(decorative: "Grain")
                .resizable(resizingMode: .tile)
                .blendMode(.overlay)
                .opacity(0.22)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Spacing matches the onboarding footer (OnboardingScaffold) so
            // the buttons stay put when onboarding starts: 24pt side margins,
            // 4pt between the primary and secondary action, 8pt above the
            // home indicator, 44pt minimum tap targets.
            VStack(spacing: 32) {
                // The wordmark leads; the headline supports it in a calmer
                // weight so the two don't compete.
                VStack(spacing: 10) {
                    Text("Kiki")
                        .font(.system(size: 40, weight: .black).italic())

                    Text("Your AI\nrunning coach.")
                        .font(.system(size: 28, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.7)
                }
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)

                VStack(spacing: 4) {
                    PrimaryButton("Get started", action: onGetStarted)
                    Button {
                        showSignIn = true
                    } label: {
                        Text("Already have an account? **Sign in**")
                            .foregroundStyle(.ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.haptic)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .onAppear {
            withAnimation(.smooth(duration: 0.9).delay(0.15)) { appeared = true }
            Analytics.screen("Welcome")
        }
        .sheet(isPresented: $showSignIn) {
            VStack(alignment: .leading, spacing: 24) {
                Text("Welcome back").font(.title.weight(.bold))
                SignInOptions {
                    showSignIn = false
                    onSignedIn()
                }
            }
            .padding(24)
            .presentationDetents([.height(200)])
        }
    }
}
