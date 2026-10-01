import SwiftUI

/// "Sign in" from the welcome screen: a bottom sheet in Kiki's style (solid
/// white, large corners, our type) rather than the stock system look.
struct SignInSheet: View {
    var body: some View {
        CompactSheet("Welcome back!") {
            // Returning runners skip the checkbox; a brand-new account made
            // here is asked once by `ConsentGate`.
            SignInOptions(requiresConsent: false, title: "Sign in with Apple") {}
            // Notice at the button (sign-in-wrap) for returning runners.
            Text(termsNotice)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .environment(\.colorScheme, .light)
        .onAppear { Analytics.screen("Sign In") }
    }

    /// Gray sentence with dark, underlined links.
    private var termsNotice: AttributedString {
        func plain(_ text: String) -> AttributedString {
            var run = AttributedString(text)
            run.foregroundColor = .muted
            return run
        }
        func link(_ text: String, _ url: URL) -> AttributedString {
            var run = AttributedString(text)
            run.link = url
            run.foregroundColor = .ink
            run.underlineStyle = .single
            return run
        }
        return plain("By continuing, you agree to Kiki's ") + link("Terms of Service", Config.termsURL)
            + plain(" and ") + link("Privacy Policy", Config.privacyURL) + plain(".")
    }
}
