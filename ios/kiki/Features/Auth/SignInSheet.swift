import AuthenticationServices
import SwiftUI

/// "Sign in" from the welcome screen: a bottom sheet in Kiki's style (solid
/// white, large corners, our type) rather than the stock system look.
struct SignInSheet: View {
    @State private var contentHeight: CGFloat = 240

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
        .padding(24)
        // Fit the sheet to its content.
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .environment(\.colorScheme, .light)
        .presentationDetents([.height(contentHeight)])
        .presentationCornerRadius(32)
        .presentationBackground(Color.white)
        // The grabber signals swipe-to-dismiss (there is no close button).
        .presentationDragIndicator(.visible)
        .onAppear { Analytics.screen("Sign In") }
    }

    /// Gray sentence with dark, underlined links.
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
            run.underlineStyle = .single
            return run
        }
        return plain("By continuing, you agree to Kiki's ") + link("Terms of Service", Config.termsURL)
            + plain(" and ") + link("Privacy Policy", Config.privacyURL) + plain(".")
    }
}
