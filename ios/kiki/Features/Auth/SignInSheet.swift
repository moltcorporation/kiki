import SwiftUI

/// "Sign in" from the welcome screen: a bottom sheet in Kiki's style (solid
/// white, large corners, our type) rather than the stock system look.
struct SignInSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Welcome back!")
                .font(.system(.title, weight: .bold))
            VStack(spacing: 14) {
                // Returning runners skip the checkbox; a brand-new account made
                // here is asked once by `ConsentGate`.
                SignInOptions(requiresConsent: false, label: .signIn) {}
                // Notice at the button (sign-in-wrap) for returning runners.
                Text(termsNotice)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 8)
        .environment(\.colorScheme, .light)
        .presentationDetents([.height(250)])
        .presentationCornerRadius(32)
        .presentationBackground(Color.white)
        .presentationDragIndicator(.hidden)
        .onAppear { Analytics.screen("Sign In") }
    }

    /// Gray sentence with bold, underlined links (same style as the consent
    /// checkbox).
    private var termsNotice: AttributedString {
        func plain(_ text: String) -> AttributedString {
            var run = AttributedString(text)
            run.foregroundColor = .secondary
            return run
        }
        func link(_ text: String, _ url: URL) -> AttributedString {
            var run = AttributedString(text)
            run.link = url
            run.foregroundColor = .ink
            run.font = .footnote.weight(.semibold)
            run.underlineStyle = .single
            return run
        }
        return plain("By continuing, you agree to Kiki's ") + link("Terms of Service", Config.termsURL)
            + plain(" and ") + link("Privacy Policy", Config.privacyURL) + plain(".")
    }
}
