import AuthenticationServices
import SwiftUI

/// Sign in with Apple behind a required agreement checkbox (the strongest,
/// clickwrap form of consent). The agreement is logged server-side with its
/// version and time. Calls `onSignedIn` on success.
struct SignInOptions: View {
    @Environment(AuthService.self) private var auth

    /// New accounts agree before signing in. Returning users (the welcome
    /// "Sign in") skip it; if the account turns out to be new or the Terms
    /// changed, `ConsentGate` asks after sign-in instead.
    var requiresConsent = true
    /// One of Apple's approved titles: "Continue with Apple" for new
    /// runners, "Sign in with Apple" for returning ones.
    var title: LocalizedStringKey = "Continue with Apple"
    let onSignedIn: () -> Void

    @State private var agreed = false
    @State private var showAgreeAlert = false
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: Spacing.l) {
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

    /// Sign in with Apple as our standard `PrimaryButton` with the Apple logo
    /// (a custom button, allowed by Apple's HIG: Apple logo, system font,
    /// black/white, approved title). The stock button scales its text with
    /// its height and renders larger than every other button.
    private var appleButton: some View {
        PrimaryButton(title, systemImage: "apple.logo", isLoading: isWorking, action: signIn)
            .alert("Couldn't sign in", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                Text(error ?? "")
            }
    }

    private func signIn() {
        guard !isWorking else { return }
        if requiresConsent { auth.noteConsent() }
        isWorking = true
        Task {
            defer { isWorking = false }
            let result = await AppleAuthorization().perform { auth.prepareAppleRequest($0) }
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
}

/// Runs a Sign in with Apple request with `ASAuthorizationController` and
/// returns its result, for custom buttons.
@MainActor
private final class AppleAuthorization: NSObject, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {
    private var continuation: CheckedContinuation<Result<ASAuthorization, Error>, Never>?
    private var controller: ASAuthorizationController?

    func perform(_ configure: (ASAuthorizationAppleIDRequest) -> Void) async -> Result<ASAuthorization, Error> {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        configure(request)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.controller = controller   // keep alive until it finishes
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        MainActor.assumeIsolated { finish(.success(authorization)) }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        MainActor.assumeIsolated { finish(.failure(error)) }
    }

    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            if let key = scenes.flatMap(\.windows).first(where: \.isKeyWindow) { return key }
            return ASPresentationAnchor(windowScene: scenes[0])
        }
    }

    private func finish(_ result: Result<ASAuthorization, Error>) {
        continuation?.resume(returning: result)
        continuation = nil
        controller = nil
    }
}

/// "I agree" checkbox. The whole row toggles it; the two links still open
/// their pages. Every word of the sentence is a link, so each tap goes to
/// exactly one place: the documents open, and plain words hit a private
/// "toggle" link handled below.
struct ConsentCheckbox: View {
    @Environment(\.openURL) private var openURL
    @Binding var isOn: Bool
    private static let toggleURL = URL(string: "kiki-consent://toggle")!

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .font(.title2)
                .foregroundStyle(isOn ? Color.ink : Color.muted)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Metrics.minTapTarget, height: Metrics.minTapTarget)
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
                    // The documents open in the app's in-app browser.
                    openURL(url)
                    return .handled
                })
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("I agree to Kiki's Terms of Service and Privacy Policy")
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .accessibilityAction { toggle() }
        .accessibilityAction(named: "Open Terms of Service") { openURL(Config.termsURL) }
        .accessibilityAction(named: "Open Privacy Policy") { openURL(Config.privacyURL) }
    }

    private var sentence: AttributedString {
        func plain(_ text: String) -> AttributedString {
            var run = AttributedString(text)
            run.link = Self.toggleURL
            run.foregroundColor = .muted
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
