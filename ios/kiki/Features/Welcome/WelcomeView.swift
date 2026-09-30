import SwiftUI

/// First screen: a full-bleed running video with the pitch and sign-up
/// actions over a dark, grainy gradient. Always dark, whatever the system
/// appearance, so the brand colors invert to white on the footage.
struct WelcomeView: View {
    let onGetStarted: () -> Void

    /// The entrance plays once per launch; coming back from onboarding the
    /// screen slides in already settled.
    private static var didPlayEntrance = false
    @State private var appeared = WelcomeView.didPlayEntrance
    @State private var showSignIn = false
    /// The headline follows the user's text size; the wordmark is a logo
    /// and stays fixed.
    @ScaledMetric(relativeTo: .largeTitle) private var headlineSize = 44

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

            // Centered at the bottom: wordmark, headline, then the actions.
            // 20pt side margins, 8pt above the home indicator.
            VStack(spacing: 32) {
                VStack(spacing: 10) {
                    Text("Kiki")
                        .font(.system(size: 26, weight: .black).italic())
                        .opacity(0.9)
                        .accessibilityAddTraits(.isHeader)
                    Text("Your AI\nrunning coach.")
                        .font(.system(size: headlineSize, weight: .black).italic())
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
            .padding(.horizontal, Metrics.screenMargin)
            .padding(.bottom, 8)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $showSignIn) {
            SignInSheet()
        }
        .onAppear {
            if !Self.didPlayEntrance {
                Self.didPlayEntrance = true
                withAnimation(.smooth(duration: 0.9).delay(0.15)) { appeared = true }
            }
            Analytics.screen("Welcome")
        }
    }
}
