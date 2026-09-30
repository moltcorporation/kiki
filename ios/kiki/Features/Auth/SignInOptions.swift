import AuthenticationServices
import SwiftUI

/// Sign in with Apple behind a required agreement checkbox (the strongest,
/// clickwrap form of consent). The agreement is logged server-side with its
/// version and time. Calls `onSignedIn` on success.
struct SignInOptions: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

    let onSignedIn: () -> Void

    @State private var agreed = false
    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 16) {
            ConsentCheckbox(isOn: $agreed)
            appleButton
                .disabled(!agreed || isWorking)
                .opacity(agreed ? 1 : 0.35)
                .animation(.snappy, value: agreed)
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(.continue) { request in
            auth.noteConsent()
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

/// "I agree" checkbox with links to the Terms and Privacy Policy.
private struct ConsentCheckbox: View {
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Button {
                isOn.toggle()
                Haptics.select()
            } label: {
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundStyle(isOn ? Color.ink : Color.secondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("I agree to the Terms and Privacy Policy, and understand Kiki isn't medical advice")
            .accessibilityAddTraits(isOn ? .isSelected : [])

            Text("I agree to the [Terms](\(Config.termsURL.absoluteString)) and [Privacy Policy](\(Config.privacyURL.absoluteString)), and understand Kiki isn't medical advice.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .tint(.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
