import SwiftUI

/// First screen: a full-bleed running video with the pitch and sign-up
/// actions over a dark, grainy gradient. Always dark, whatever the system
/// appearance, so the brand colors invert to white on the footage.
struct WelcomeView: View {
    let onGetStarted: () -> Void
    let onSignIn: () -> Void

    /// The entrance plays once per launch; coming back from onboarding the
    /// screen slides in already settled.
    private static var didPlayEntrance = false
    @State private var appeared = WelcomeView.didPlayEntrance
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

            // Soft corner vignette so the wordmark reads over the bright sky
            // (worst frame of the film is 5:1 contrast behind it).
            RadialGradient(
                stops: [
                    .init(color: .black.opacity(0.7), location: 0),
                    .init(color: .black.opacity(0.4), location: 0.5),
                    .init(color: .black.opacity(0), location: 1),
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()

            // Wordmark top-left, set like the logo (heavy italic).
            Text("Kiki")
                .font(.system(size: 28, weight: .black).italic())
                .shadow(color: .black.opacity(0.25), radius: 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .opacity(appeared ? 1 : 0)

            // 24pt side margins, 12pt between the two full-width buttons,
            // 8pt above the home indicator (like the onboarding footer).
            VStack(alignment: .leading, spacing: 32) {
                Text("Your AI\nrunning coach.")
                    .font(.system(size: headlineSize, weight: .black).italic())
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 4)

                VStack(spacing: 12) {
                    PrimaryButton("Get started", action: onGetStarted)
                    // Secondary: same size, translucent so "Get started" leads.
                    Button {
                        onSignIn()
                    } label: {
                        Text("I already have an account")
                            .font(.headline)
                            .foregroundStyle(.ink)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Color.ink.opacity(0.14), in: .capsule)
                            .contentShape(.capsule)
                    }
                    .buttonStyle(.haptic)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .onAppear {
            if !Self.didPlayEntrance {
                Self.didPlayEntrance = true
                withAnimation(.smooth(duration: 0.9).delay(0.15)) { appeared = true }
            }
            Analytics.screen("Welcome")
        }
    }
}
