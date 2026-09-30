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
            TabPage(.text("You")) {
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
        .onAppear { Analytics.screen("You") }
    }

    // MARK: Header

    /// Photo, name and member-since in a standard card.
    private var profileCard: some View {
        HStack(spacing: 16) {
            ProfileAvatar(userID: auth.userID, name: store.profile?.firstName, size: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(store.profile?.firstName ?? "Runner")
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let since = store.memberSince {
                    Text("Kiki member since \(since.formatted(.dateTime.month(.wide).year()))")
                        .font(.subheadline)
                        .foregroundStyle(.muted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .elevatedCard(cornerRadius: 24)
    }

    // MARK: Goal

    @ViewBuilder
    private var goalSection: some View {
        TabSection("Your goal") {
            if let plan = store.plan {
                Button { path.append(.goal) } label: {
                    GoalCard(plan: plan, units: store.units)
                }
                .buttonStyle(.haptic)
            } else {
                PrimaryButton("Set your goal", systemImage: "flag.checkered") { startGoalEdit(.goal) }
            }
        }
    }

    // MARK: Preferences

    private func trainingSection(_ profile: Profile) -> some View {
        PreferenceGroup("Your training") {
            PreferenceRow(icon: "figure.run", label: "Experience", value: profile.experience.title) {
                path.append(.edit(.experience))
            }
            if profile.experience != .new {
                PreferenceRow(icon: "chart.bar", label: "Weekly distance",
                              value: Format.distance(Double(profile.weeklyDistanceM), store.units, decimals: 0)) {
                    path.append(.edit(.weeklyVolume))
                }
            }
            PreferenceRow(icon: "calendar", label: "Run days", value: RunDaysSelector.summary(profile.runDays)) {
                path.append(.edit(.runDays))
            }
            PreferenceRow(icon: (profile.coachingStyle ?? .balanced).icon, label: "Coaching style",
                          value: (profile.coachingStyle ?? .balanced).title) {
                path.append(.edit(.coachingStyle))
            }
            PreferenceRow(icon: "list.bullet", label: "Run history",
                          value: store.runs.isEmpty ? "None yet" : "\(store.runs.count)", showsDivider: false) {
                path.append(.runs)
            }
        }
    }

    private func aboutSection(_ profile: Profile) -> some View {
        let bodyUnits = BodyUnits.resolve(bodyUnitsStored, default: store.units)
        return PreferenceGroup("About you") {
            PreferenceRow(icon: "person", label: "Name", value: profile.firstName ?? "Add") {
                path.append(.edit(.name))
            }
            PreferenceRow(icon: "birthday.cake", label: "Age", value: profile.age.map(String.init) ?? "Add") {
                path.append(.edit(.age))
            }
            PreferenceRow(icon: "ruler", label: "Height", value: profile.heightCm.map { Format.height($0, bodyUnits) } ?? "Add") {
                path.append(.edit(.height))
            }
            PreferenceRow(icon: "scalemass", label: "Weight", value: profile.weightKg.map { Format.weight($0, bodyUnits) } ?? "Add",
                          showsDivider: false) {
                path.append(.edit(.weight))
            }
        }
    }

    private var appSection: some View {
        PreferenceGroup("App") {
            PreferenceRow(icon: "ruler.fill", label: "Units", value: store.units.title) {
                path.append(.edit(.units))
            }
            PreferenceToggleRow(icon: "bell", label: "Run day reminders", isOn: $remindersEnabled)
                .onChange(of: remindersEnabled) { _, enabled in
                    Task { await updateReminders(enabled) }
                }
            PreferenceRow(icon: "creditcard", label: "Subscription") { showCustomerCenter = true }
            PreferenceRow(icon: "arrow.clockwise", label: "Restore purchases") {
                Task {
                    let found = (try? await subscriptions.restore()) ?? false
                    message = found ? "Your subscription is active." : "No active subscription found for this Apple ID."
                }
            }
            PreferenceRow(icon: "star", label: "Rate Kiki") { requestReview() }
            PreferenceRow(icon: "envelope", label: "Contact support") {
                openURL(URL(string: "mailto:\(Config.supportEmail)")!)
            }
            PreferenceRow(icon: "hand.raised", label: "Privacy Policy") { openURL(Config.privacyURL) }
            PreferenceRow(icon: "doc.text", label: "Terms of Service", showsDivider: false) { openURL(Config.termsURL) }
        }
    }

    private var accountSection: some View {
        PreferenceGroup("Account") {
            PreferenceRow(icon: "rectangle.portrait.and.arrow.right", label: "Sign out") { confirmSignOut = true }
            PreferenceRow(icon: "trash", label: "Delete account", role: .destructive, showsDivider: false) {
                confirmDelete = true
            }
            .disabled(isDeleting)
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
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

/// The current goal in a standard card.
private struct GoalCard: View {
    let plan: Plan
    let units: Units

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: plan.goalKind.icon)
                .font(.title3.weight(.semibold))
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Text(plan.displayName)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.leading)
                ForEach(plan.goalDetails(units: units), id: \.self) { line in
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(.muted)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 6)
        }
        .foregroundStyle(.ink)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .elevatedCard(cornerRadius: 24)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows your goal details")
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
