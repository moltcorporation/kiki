import AuthenticationServices
import SwiftUI

/// Sign in with Apple behind a required agreement checkbox (the strongest,
/// clickwrap form of consent). The agreement is logged server-side with its
/// version and time. Calls `onSignedIn` on success.
struct SignInOptions: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

    /// New accounts agree before signing in. Returning users (the welcome
    /// "Sign in") skip it; if the account turns out to be new or the Terms
    /// changed, `ConsentGate` asks after sign-in instead.
    var requiresConsent = true
    let onSignedIn: () -> Void

    @State private var agreed = false
    @State private var showAgreeAlert = false
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            if requiresConsent {
                ConsentCheckbox(isOn: $agreed)
            }
            appleButton
                .disabled(isWorking)
                // Until they agree, a tap explains why instead of doing nothing.
                .overlay {
                    if requiresConsent && !agreed {
                        Color.clear
                            .contentShape(.capsule)
                            .onTapGesture {
                                Haptics.warning()
                                showAgreeAlert = true
                            }
                            .accessibilityHidden(true)
                    }
                }
        }
        .alert("Please agree to continue", isPresented: $showAgreeAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("To create your account, check the box to agree to Kiki's Terms of Service and Privacy Policy.")
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            if requiresConsent { auth.noteConsent() }
            auth.prepareAppleRequest(request)
        } onCompletion: { result in
            isWorking = true
            Task {
                defer { isWorking = false }
                do {
                    if try await auth.completeApple(result) {
                        Haptics.success()
                        onSignedIn()
                    }
                } catch {
                    Haptics.error()
                    Analytics.captureError(error, context: ["step": "sign_in"])
                    self.error = (error as? LocalizedError)?.errorDescription ?? "Please try again."
                }
            }
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 56)
        .clipShape(.capsule)
        .overlay { if isWorking { ProgressView() } }
        .alert("Couldn't sign in", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }
}

/// "I agree" checkbox. The whole row toggles it; the two links still open
/// their pages. Every word of the sentence is a link, so each tap goes to
/// exactly one place: the documents open, and plain words hit a private
/// "toggle" link handled below.
struct ConsentCheckbox: View {
    @Binding var isOn: Bool
    private static let toggleURL = URL(string: "kiki-consent://toggle")!

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .font(.title2)
                .foregroundStyle(isOn ? Color.ink : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .contentShape(.rect)
                .onTapGesture(perform: toggle)

            Text(sentence)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.openURL, OpenURLAction { url in
                    if url == Self.toggleURL {
                        toggle()
                        return .handled
                    }
                    return .systemAction
                })
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("I agree to Kiki's Terms of Service and Privacy Policy")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityAction { toggle() }
        .accessibilityAction(named: "Open Terms of Service") { UIApplication.shared.open(Config.termsURL) }
        .accessibilityAction(named: "Open Privacy Policy") { UIApplication.shared.open(Config.privacyURL) }
    }

    private var sentence: AttributedString {
        func plain(_ text: String) -> AttributedString {
            var run = AttributedString(text)
            run.link = Self.toggleURL
            run.foregroundColor = .secondary
            return run
        }
        func document(_ text: String, _ url: URL) -> AttributedString {
            var run = AttributedString(text)
            run.link = url
            run.foregroundColor = .ink
            run.font = .footnote.weight(.semibold)
            run.underlineStyle = .single
            return run
        }
        return plain("I agree to Kiki's ") + document("Terms of Service", Config.termsURL)
            + plain(" and ") + document("Privacy Policy", Config.privacyURL) + plain(".")
    }

    private func toggle() {
        isOn.toggle()
        Haptics.select()
    }
}
