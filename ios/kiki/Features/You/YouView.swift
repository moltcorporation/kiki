import RevenueCatUI
import StoreKit
import SwiftUI

/// Everything about the runner: goal, runs, training preferences, profile,
/// reminders, subscription and account. Every onboarding answer is editable
/// here using the same question components.
struct YouView: View {
    @Environment(AuthService.self) private var auth
    @Environment(TrainingStore.self) private var store
    @Environment(Subscriptions.self) private var subscriptions
    @Environment(\.requestReview) private var requestReview

    @AppStorage("reminders.enabled") private var remindersEnabled = true
    @AppStorage(BodyUnits.storageKey) private var bodyUnitsStored = ""
    @State private var sheet: AppSheet?
    @State private var newGoal: OnboardingModel?
    @State private var showCustomerCenter = false
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var message: String?

    var body: some View {
        let units = store.units
        NavigationStack {
            Form {
                goalSection

                Section {
                    NavigationLink(value: Route.runs) {
                        LabeledContent("Runs", value: store.runs.isEmpty ? "None yet" : "\(store.runs.count)")
                    }
                }

                if let profile = store.profile {
                    Section("Training") {
                        editorLink(.experience, "Experience", profile.experience.title)
                        if profile.experience != .new {
                            editorLink(.weeklyVolume, "Weekly distance", Format.distance(Double(profile.weeklyDistanceM), units, decimals: 0))
                        }
                        editorLink(.runDays, "Run days", RunDaysSelector.summary(profile.runDays))
                        editorLink(.coachingStyle, "Coaching style", (profile.coachingStyle ?? .balanced).title)
                        editorLink(.units, "Units", profile.units.title)
                    }

                    Section("About you") {
                        editorLink(.name, "Name", profile.firstName ?? "Add")
                        editorLink(.age, "Age", profile.age.map(String.init) ?? "Add")
                        let bodyUnits = BodyUnits.resolve(bodyUnitsStored, default: units)
                        editorLink(.height, "Height", profile.heightCm.map { Format.height($0, bodyUnits) } ?? "Add")
                        editorLink(.weight, "Weight", profile.weightKg.map { Format.weight($0, bodyUnits) } ?? "Add")
                    }
                }

                Section {
                    Toggle("Workout reminders", isOn: $remindersEnabled)
                        .onChange(of: remindersEnabled) { _, enabled in
                            Task { await updateReminders(enabled) }
                        }
                } footer: {
                    Text("A morning heads-up on days you have a run.")
                }

                Section("Subscription") {
                    Button("Manage subscription") { showCustomerCenter = true }
                    Button("Restore purchases") {
                        Task {
                            let found = (try? await subscriptions.restore()) ?? false
                            message = found ? "Your subscription is active." : "No active subscription found for this Apple ID."
                        }
                    }
                }

                Section("Help") {
                    Link(destination: URL(string: "mailto:\(Config.supportEmail)")!) {
                        Label("Contact support", systemImage: "envelope")
                    }
                    Button { requestReview() } label: {
                        Label("Rate Kiki", systemImage: "star")
                    }
                    Link(destination: Config.privacyURL) { Label("Privacy Policy", systemImage: "hand.raised") }
                    Link(destination: Config.termsURL) { Label("Terms of Service", systemImage: "doc.text") }
                }

                Section {
                    Button("Sign out") { confirmSignOut = true }
                    Button("Delete account", role: .destructive) { confirmDelete = true }
                        .disabled(isDeleting)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let email = auth.email { Text(email) }
                        Text("Kiki \(Bundle.main.appVersion) · Not medical advice. Check with a professional before starting a new training program.")
                    }
                    .padding(.top, 8)
                }
            }
            .tint(.ink)
            .navigationTitle(store.profile?.firstName ?? "You")
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .runs: RunsView()
                case .edit(let field): ProfileFieldEditor(field: field)
                }
            }
            .navigationDestination(for: Run.self) { RunDetailView(run: $0) }
            .appSheets($sheet)
            .sheet(isPresented: $showCustomerCenter) { CustomerCenterView() }
            .fullScreenCover(item: $newGoal) { model in
                OnboardingFlow().environment(model)
            }
            .confirmationDialog("Sign out of Kiki?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    Task { await auth.signOut() }
                }
            }
            .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete account", role: .destructive, action: deleteAccount)
            } message: {
                Text("This permanently deletes your profile, plans and runs. It doesn't cancel your subscription. Manage that in your Apple ID settings.")
            }
            .alert(message ?? "", isPresented: .constant(message != nil)) {
                Button("OK") { message = nil }
            }
        }
        .onAppear { Analytics.screen("You") }
    }

    enum Route: Hashable {
        case runs
        case edit(ProfileField)
    }

    @ViewBuilder
    private var goalSection: some View {
        Section("Goal") {
            if let plan = store.plan {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.displayName).font(.headline)
                    Text("\(store.totalWeeks) weeks · ends \(Format.shortDate(plan.raceDate))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            Button {
                sheet = .adjust
            } label: {
                Label("Adjust my plan", systemImage: "sparkles")
            }
            Button(action: changeGoal) {
                Label("Change goal", systemImage: "flag.checkered")
            }
        }
    }

    private func editorLink(_ field: ProfileField, _ title: String, _ value: String) -> some View {
        NavigationLink(value: Route.edit(field)) {
            LabeledContent(title, value: value)
        }
    }

    private func changeGoal() {
        let model = OnboardingModel(mode: .newGoal, profile: store.profile)
        model.onFinish = { [weak model] in
            if newGoal === model { newGoal = nil }
        }
        newGoal = model
        Analytics.track("change_goal_started")
    }

    private func updateReminders(_ enabled: Bool) async {
        if enabled {
            guard await Notifications.requestPermission() else {
                remindersEnabled = false
                message = "Turn on notifications for Kiki in the Settings app to get reminders."
                return
            }
            await Notifications.scheduleWorkoutReminders(store.workouts, units: store.units)
        } else {
            await Notifications.cancelWorkoutReminders()
        }
    }

    private func deleteAccount() {
        isDeleting = true
        Task {
            defer { isDeleting = false }
            do {
                try await auth.deleteAccount()
            } catch {
                Haptics.error()
                message = (error as? LocalizedError)?.errorDescription ?? "Couldn't delete your account. Please try again."
            }
        }
    }
}

extension OnboardingModel: Identifiable {
    var id: ObjectIdentifier { ObjectIdentifier(self) }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
