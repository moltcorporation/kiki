import SwiftUI

/// "Sign in" from the welcome screen: a full screen in the onboarding style,
/// pushed from the welcome screen, with Sign in with Apple right under the
/// title.
struct SignInScreen: View {
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            BackButton(action: onBack)
                .padding(.leading, 22)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 12) {
                KikiLogo(size: 56)
                    .padding(.bottom, 8)
                Text("Welcome back!")
                    .font(.system(.largeTitle, weight: .bold))
                Text("Sign in to continue.")
                    .foregroundStyle(.secondary)
                // Returning runners skip the checkbox; a brand-new account made
                // here is asked once by `ConsentGate`.
                SignInOptions(requiresConsent: false) {}
                    .padding(.top, 20)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.paper)
        .onAppear { Analytics.screen("Sign In") }
    }
}
