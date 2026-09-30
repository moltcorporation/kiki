import SwiftUI

/// "Sign in" from the welcome screen: a traditional login page. Content is
/// centered, with a help link at the bottom for anyone who gets stuck.
struct SignInScreen: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            BackButton(action: onBack)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 22)
                .padding(.top, 4)

            Spacer()

            VStack(spacing: 12) {
                Text("Welcome back!")
                    .font(.system(.largeTitle, weight: .bold))
                Text("Sign in to continue.")
                    .foregroundStyle(.secondary)
                // Returning runners skip the checkbox; a brand-new account made
                // here is asked once by `ConsentGate`.
                SignInOptions(requiresConsent: false) {}
                    .padding(.top, 20)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            Spacer()

            Link(destination: URL(string: "mailto:\(Config.supportEmail)")!) {
                Text("Trouble signing in? **Contact support**")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(minHeight: 44)
            }
            .tint(.ink)
            .padding(.bottom, 8)
        }
        .background(Color.paper)
        .onAppear { Analytics.screen("Sign In") }
    }
}
