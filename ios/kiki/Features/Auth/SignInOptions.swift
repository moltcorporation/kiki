import AuthenticationServices
import SwiftUI

/// Sign in with Apple. Calls `onSignedIn` on success.
struct SignInOptions: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

    let onSignedIn: () -> Void

    @State private var isWorking = false
    @State private var error: String?

    var body: some View {
        SignInWithAppleButton(.continue) { request in
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
        .disabled(isWorking)
        .overlay { if isWorking { ProgressView() } }
        .alert("Couldn't sign in", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }
}
