import SwiftUI

/// Asks a signed-in runner to agree to the Terms and Privacy Policy when the
/// server has no agreement on record: an account created from the welcome
/// sign-in sheet instead of onboarding.
struct ConsentGate: View {
    @Environment(AuthService.self) private var auth
    @Environment(TrainingStore.self) private var store

    @State private var agreed = false
    @State private var isSaving = false
    @State private var showAgreeAlert = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Spacer()
            KikiLogo(size: 56)
                .padding(.bottom, Spacing.m)
            PageHeader(title: "One last thing", subtitle: "Please agree to Kiki's Terms of Service and Privacy Policy to continue.")
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
            TextButton("Sign out") { Task { await auth.signOut() } }
        }
        .padding(.horizontal, Metrics.screenMargin)
        .padding(.bottom, Spacing.s)
        .background { PageBackground() }
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
