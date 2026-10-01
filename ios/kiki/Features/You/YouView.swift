import RevenueCatUI
import StoreKit
import SwiftUI

/// The runner's profile: who they are, their goal, and the preferences that
/// shape their plan. Every onboarding answer is editable here, using the same
/// inputs as onboarding.
struct YouView: View {
    @Environment(AuthService.self) private var auth
    @Environment(TrainingStore.self) private var store
    @Environment(Subscriptions.self) private var subscriptions
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    @AppStorage("reminders.enabled") private var remindersEnabled = true
    @AppStorage(BodyUnits.storageKey) private var bodyUnitsStored = ""
    @State private var path: [Route] = []
    @State private var goalFlow: OnboardingModel?
    @State private var showCustomerCenter = false
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var message: String?

    enum Route: Hashable {
        case goal
        case runs
        case edit(ProfileField)
    }

    var body: some View {
        NavigationStack(path: $path) {
            TabPage(.text("Profile")) {
                profileCard
                goalSection
                if let profile = store.profile {
                    trainingSection(profile)
                    aboutSection(profile)
                }
                appSection
                accountSection
                footer
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .goal: GoalDetailView(onEdit: startGoalEdit)
                case .runs: RunsView()
                case .edit(let field): ProfileFieldEditor(field: field)
                }
            }
            .navigationDestination(for: Run.self) { RunDetailView(run: $0) }
            .sheet(isPresented: $showCustomerCenter) { CustomerCenterView() }
            .fullScreenCover(item: $goalFlow) { model in
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
        .onAppear { Analytics.screen("Profile") }
    }

    // MARK: Header

    /// Photo, name and join date in a standard card.
    private var profileCard: some View {
        HStack(spacing: RowMetrics.spacing) {
            ProfileAvatar(userID: auth.userID, name: store.profile?.firstName, size: 56)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(store.profile?.firstName ?? "Runner")
                    .font(.cardTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let since = store.memberSince {
                    Text("Joined \(since.formatted(.dateTime.month(.wide).year()))")
                        .font(.detail)
                        .foregroundStyle(.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, RowMetrics.horizontalPadding)
        .padding(.vertical, Spacing.l)
        .elevatedCard()
    }

    // MARK: Goal

    @ViewBuilder
    private var goalSection: some View {
        PageSection("Your goal") {
            if let plan = store.plan {
                ListCard {
                    Button { path.append(.goal) } label: {
                        ListRow(
                            icon: plan.goalKind.icon,
                            title: Text(plan.displayName),
                            subtitles: plan.goalDetails(units: store.units),
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.haptic)
                    .accessibilityElement(children: .combine)
                    .accessibilityHint("Shows your goal details")
                }
            } else {
                PrimaryButton("Set your goal", systemImage: "flag.checkered") { startGoalEdit(.goal) }
            }
        }
    }

    // MARK: Preferences

    private func trainingSection(_ profile: Profile) -> some View {
        ListSection("Your training") {
            SettingsRow(icon: "figure.run", label: "Experience", value: profile.experience.title) {
                path.append(.edit(.experience))
            }
            if profile.experience != .new {
                SettingsRow(icon: "chart.bar", label: "Weekly distance",
                              value: Format.distance(Double(profile.weeklyDistanceM), store.units, decimals: 0)) {
                    path.append(.edit(.weeklyVolume))
                }
            }
            SettingsRow(icon: "calendar", label: "Run days", value: RunDaysSelector.summary(profile.runDays)) {
                path.append(.edit(.runDays))
            }
            SettingsRow(icon: (profile.coachingStyle ?? .balanced).icon, label: "Coaching style",
                          value: (profile.coachingStyle ?? .balanced).title) {
                path.append(.edit(.coachingStyle))
            }
            SettingsRow(icon: "list.bullet", label: "Run history",
                          value: store.runs.isEmpty ? "None yet" : "\(store.runs.count)") {
                path.append(.runs)
            }
        }
    }

    private func aboutSection(_ profile: Profile) -> some View {
        let bodyUnits = BodyUnits.resolve(bodyUnitsStored, default: store.units)
        return ListSection("About you") {
            SettingsRow(icon: "person", label: "Name", value: profile.firstName ?? "Add") {
                path.append(.edit(.name))
            }
            SettingsRow(icon: "birthday.cake", label: "Age", value: profile.age.map(String.init) ?? "Add") {
                path.append(.edit(.age))
            }
            SettingsRow(icon: "ruler", label: "Height", value: profile.heightCm.map { Format.height($0, bodyUnits) } ?? "Add") {
                path.append(.edit(.height))
            }
            SettingsRow(icon: "scalemass", label: "Weight", value: profile.weightKg.map { Format.weight($0, bodyUnits) } ?? "Add") {
                path.append(.edit(.weight))
            }
        }
    }

    private var appSection: some View {
        ListSection("App") {
            SettingsRow(icon: "ruler", label: "Units", value: store.units.title) {
                path.append(.edit(.units))
            }
            SettingsToggleRow(icon: "bell", label: "Run day reminders", isOn: $remindersEnabled)
                .onChange(of: remindersEnabled) { _, enabled in
                    Task { await updateReminders(enabled) }
                }
            SettingsRow(icon: "creditcard", label: "Subscription") { showCustomerCenter = true }
            SettingsRow(icon: "arrow.clockwise", label: "Restore purchases") {
                Task {
                    let found = (try? await subscriptions.restore()) ?? false
                    message = found ? "Your subscription is active." : "No active subscription found for this Apple ID."
                }
            }
            SettingsRow(icon: "star", label: "Rate Kiki") { requestReview() }
            SettingsRow(icon: "envelope", label: "Contact support") {
                openURL(URL(string: "mailto:\(Config.supportEmail)")!)
            }
            SettingsRow(icon: "hand.raised", label: "Privacy Policy") { openURL(Config.privacyURL) }
            SettingsRow(icon: "doc.text", label: "Terms of Service") { openURL(Config.termsURL) }
        }
    }

    private var accountSection: some View {
        ListSection("Account") {
            SettingsRow(icon: "rectangle.portrait.and.arrow.right", label: "Sign out") { confirmSignOut = true }
            SettingsRow(icon: "trash", label: "Delete account", role: .destructive) {
                confirmDelete = true
            }
            .disabled(isDeleting)
        }
    }

    private var footer: some View {
        VStack(spacing: Spacing.xs) {
            if let email = auth.email { Text(email) }
            Text("Kiki \(Bundle.main.appVersion)")
            Text("Not medical advice. Check with a professional before starting a new training program.")
                .multilineTextAlignment(.center)
        }
        .font(.footnote)
        .foregroundStyle(.muted)
        .frame(maxWidth: .infinity)
    }

    // MARK: Actions

    /// Opens the goal questions from onboarding, prefilled with the current
    /// goal. `.goal` changes the whole goal; any other step edits just that
    /// detail. Either way the flow ends with a confirmation before rebuilding.
    private func startGoalEdit(_ step: OnboardingModel.Step) {
        let mode: OnboardingModel.Mode = step == .goal ? .newGoal : .editGoal(step)
        let model = OnboardingModel(mode: mode, profile: store.profile, plan: store.plan)
        model.onFinish = { [weak model] in
            if goalFlow === model { goalFlow = nil }
        }
        goalFlow = model
        Analytics.track("goal_edit_started", ["step": step.rawValue])
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
        let userID = auth.userID
        Task {
            defer { isDeleting = false }
            do {
                try await auth.deleteAccount()
                if let userID { AvatarStore.remove(userID: userID) }
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
