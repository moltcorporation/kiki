import RevenueCatUI
import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(AuthService.self) private var auth
    @Environment(TrainingStore.self) private var store
    @Environment(Subscriptions.self) private var subscriptions
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    @AppStorage("reminders.enabled") private var remindersEnabled = true
    @State private var showCustomerCenter = false
    @State private var showDays = false
    @State private var showNewPlan = false
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        KikiLogo(size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.profile?.firstName ?? "Runner").font(.headline)
                            if let email = auth.email {
                                Text(email).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Training") {
                    Picker("Units", selection: unitsBinding) {
                        Text("Kilometers").tag(Units.km)
                        Text("Miles").tag(Units.mi)
                    }
                    Button { showDays = true } label: {
                        LabeledContent("Training days", value: daysSummary)
                    }
                    Button { showNewPlan = true } label: {
                        Label("New race or goal", systemImage: "flag.checkered")
                    }
                }
                .foregroundStyle(.ink)

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
                .foregroundStyle(.ink)

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
                .foregroundStyle(.ink)

                Section {
                    Button("Sign out") { confirmSignOut = true }
                        .foregroundStyle(.ink)
                    Button("Delete account", role: .destructive) { confirmDelete = true }
                        .disabled(isDeleting)
                } footer: {
                    Text("Kiki \(Bundle.main.appVersion) · Not medical advice. Check with a professional before starting a new training program.")
                        .padding(.top, 8)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
            .sheet(isPresented: $showCustomerCenter) { CustomerCenterView() }
            .sheet(isPresented: $showDays) { TrainingDaysView() }
            .sheet(isPresented: $showNewPlan) { NewPlanView() }
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
        .onAppear { Analytics.screen("Settings") }
    }

    private var unitsBinding: Binding<Units> {
        Binding(
            get: { store.units },
            set: { units in
                guard var profile = store.profile, profile.units != units else { return }
                profile.units = units
                Haptics.select()
                Task {
                    do { try await store.saveProfile(profile) } catch { message = error.localizedDescription }
                }
            }
        )
    }

    private var daysSummary: String {
        guard let days = store.profile?.runDays else { return "" }
        return days.map { Calendar.current.shortWeekdaySymbols[$0 % 7] }.joined(separator: ", ")
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

/// Edit which days the runner can train and their long-run day.
private struct TrainingDaysView: View {
    @Environment(TrainingStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var days: Set<Int> = []
    @State private var longRunDay = 7
    @State private var isSaving = false
    @State private var showAdjust = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Days you can run") {
                    ForEach(1...7, id: \.self) { day in
                        Toggle(Calendar.current.weekdaySymbols[day % 7], isOn: Binding(
                            get: { days.contains(day) },
                            set: { on in
                                if on { days.insert(day) } else { days.remove(day) }
                                Haptics.select()
                            }
                        ))
                    }
                }
                Section("Long run day") {
                    Picker("Long run day", selection: $longRunDay) {
                        ForEach(days.sorted(), id: \.self) { Text(Calendar.current.weekdaySymbols[$0 % 7]).tag($0) }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
            .navigationTitle("Training days")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .disabled(days.count < 2 || !days.contains(longRunDay) || isSaving)
                }
            }
            .sheet(isPresented: $showAdjust, onDismiss: { dismiss() }) {
                AdjustPlanView(initialReason: .schedule)
            }
        }
        .onAppear {
            days = Set(store.profile?.runDays ?? [])
            longRunDay = store.profile?.longRunDay ?? 7
        }
    }

    private func save() {
        guard var profile = store.profile else { return }
        profile.runDays = days.sorted()
        profile.longRunDay = longRunDay
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await store.saveProfile(profile)
                Haptics.success()
                showAdjust = true
            } catch {
                Haptics.error()
            }
        }
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
