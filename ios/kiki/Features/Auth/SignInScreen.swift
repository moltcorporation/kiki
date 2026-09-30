import SwiftUI

/// "I already have an account": a full screen in the onboarding style,
/// pushed from the welcome screen. Sign in with Apple sits where Continue
/// does in onboarding.
struct SignInScreen: View {
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackButton(action: onBack)
                .padding(.leading, 22)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 12) {
                Text("Sign in to Kiki")
                    .font(.system(.largeTitle, weight: .bold))
                Text("Pick up right where you left off.")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .safeAreaInset(edge: .bottom) {
            // Returning runners skip the checkbox; a brand-new account made
            // here is asked once by `ConsentGate`.
            SignInOptions(requiresConsent: false) {}
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
        .background(Color.paper)
        .onAppear { Analytics.screen("Sign In") }
    }
}
