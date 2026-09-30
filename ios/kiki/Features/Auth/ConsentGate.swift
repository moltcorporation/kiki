import SwiftUI

/// Asks a signed-in runner to agree to the Terms and Privacy Policy when the
/// server has no agreement on record: an account created from the welcome
/// "Sign in" instead of onboarding.
struct ConsentGate: View {
    @Environment(AuthService.self) private var auth
    @Environment(TrainingStore.self) private var store

    @State private var agreed = false
    @State private var isSaving = false
    @State private var showAgreeAlert = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer()
            KikiLogo(size: 56)
                .padding(.bottom, 12)
            Text("One last thing")
                .font(.largeTitle.weight(.bold))
            Text("Please agree to Kiki's Terms of Service and Privacy Policy to continue.")
                .foregroundStyle(.secondary)
            Spacer()
            ConsentCheckbox(isOn: $agreed)
            PrimaryButton("Continue", isLoading: isSaving) {
                guard agreed else {
                    Haptics.warning()
                    showAgreeAlert = true
                    return
                }
                save()
            }
            Button("Sign out") { Task { await auth.signOut() } }
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.haptic)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .background(Color.paper)
        .alert("Please agree to continue", isPresented: $showAgreeAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Check the box to agree to Kiki's Terms of Service and Privacy Policy.")
        }
        .alert("Couldn't save", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
        .onAppear { Analytics.screen("Consent") }
    }

    private func save() {
        isSaving = true
        auth.noteConsent()
        Task {
            defer { isSaving = false }
            if await auth.recordPendingConsent() {
                Haptics.success()
                store.markConsented()
            } else {
                Haptics.error()
                error = "Please check your connection and try again."
            }
        }
    }
}
