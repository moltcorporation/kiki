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
    @Environment(HealthService.self) private var health
    @Environment(\.requestReview) private var requestReview
    @Environment(\.openURL) private var openURL

    @AppStorage("reminders.enabled") private var remindersEnabled = true
    @AppStorage(BodyUnits.storageKey) private var bodyUnitsStored = ""
    /// Holds `Route`s and `Run`s.
    @State private var path = NavigationPath()
    @State private var goalFlow: OnboardingModel?
    @State private var showCustomerCenter = false
    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    /// Reminders were turned on but notifications are off for Kiki.
    @State private var notificationsOff = false
    @State private var isDeleting = false
    @State private var message: String?

    enum Route: Hashable {
        case goal
        case edit(ProfileField)
    }

    var body: some View {
        NavigationStack(path: $path) {
            TabPage("Profile") {
                profileCard
                goalSection
                if let profile = store.profile {
                    trainingSection(profile)
                    aboutSection(profile)
                }
                if HealthService.isAvailable { connectedAppsSection }
                appSection
                accountSection
                footer
            }
            .hidesTabBar(!path.isEmpty)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .goal: GoalDetailView()
                case .edit(let field): ProfileFieldEditor(field: field)
                }
            }
            .navigationDestination(for: Run.self) { RunDetailView(run: $0) }
            .sheet(isPresented: $showCustomerCenter) { CustomerCenterView() }
            .goalEditFlow($goalFlow)
            .alert("Turn on notifications", isPresented: $notificationsOff) {
                Button("Open Settings") {
                    // Kiki's notification settings, one tap from the toggle.
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
                Button("Not now", role: .cancel) {}
            } message: {
                Text("Allow notifications for Kiki to get run day reminders.")
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
                Button { path.append(Route.goal) } label: {
                    ProfileGoalCard(plan: plan, units: store.units, timeline: PlanTimeline(plan: plan, store: store))
                }
                .buttonStyle(.haptic)
                .accessibilityHint("Shows your goal details")
            } else {
                PrimaryButton("Set your goal", systemImage: "flag.checkered") { startGoalEdit(.goal) }
            }
        }
    }

    // MARK: Preferences

    private func trainingSection(_ profile: Profile) -> some View {
        ListSection("Your training") {
            SettingsRow(icon: "figure.run", label: "Experience", value: profile.experience.title) {
                path.append(Route.edit(.experience))
            }
            if profile.experience != .new {
                SettingsRow(icon: "chart.bar", label: "Weekly distance",
                              value: Format.distance(Double(profile.weeklyDistanceM), store.units, decimals: 0)) {
                    path.append(Route.edit(.weeklyVolume))
                }
                SettingsRow(icon: "road.lanes", label: "Longest recent run",
                              value: Format.distance(Double(profile.longestRunM), store.units, decimals: 0)) {
                    path.append(Route.edit(.longestRun))
                }
            }
            SettingsRow(icon: "calendar", label: "Run days", value: RunDaysSelector.summary(profile.runDays)) {
                path.append(Route.edit(.runDays))
            }
            SettingsRow(icon: (profile.coachingStyle ?? .balanced).icon, label: "Coaching style",
                          value: (profile.coachingStyle ?? .balanced).title) {
                path.append(Route.edit(.coachingStyle))
            }
        }
    }

    private func aboutSection(_ profile: Profile) -> some View {
        let bodyUnits = BodyUnits.resolve(bodyUnitsStored, default: store.units)
        return ListSection("About you") {
            SettingsRow(icon: "person", label: "Name", value: profile.firstName ?? "Add") {
                path.append(Route.edit(.name))
            }
            SettingsRow(icon: "birthday.cake", label: "Age", value: profile.age.map(String.init) ?? "Add") {
                path.append(Route.edit(.age))
            }
            SettingsRow(icon: "ruler", label: "Height", value: profile.heightCm.map { Format.height($0, bodyUnits) } ?? "Add") {
                path.append(Route.edit(.height))
            }
            SettingsRow(icon: "scalemass", label: "Weight", value: profile.weightKg.map { Format.weight($0, bodyUnits) } ?? "Add") {
                path.append(Route.edit(.weight))
            }
        }
    }

    /// Apple Health for now; other apps (Strava, Garmin) can join later.
    private var connectedAppsSection: some View {
        PageSection("Connected apps") {
            VStack(alignment: .leading, spacing: Metrics.sectionHeaderSpacing) {
                ListCard {
                    SettingsRow(icon: "heart", label: "Apple Health", value: health.isConnected ? "Connected" : "Connect") {
                        if health.isConnected {
                            // Permissions live in the Health app.
                            if let url = URL(string: "x-apple-health://") { openURL(url) }
                        } else {
                            Task {
                                if await health.connect() {
                                    Haptics.success()
                                    await health.sync(into: store)
                                    health.startObserving(store)
                                }
                            }
                        }
                    }
                }
                Footnote("Kiki saves your runs to Apple Health and syncs runs from apps like Strava, Garmin and Nike Run Club.")
            }
        }
    }

    private var appSection: some View {
        ListSection("App") {
            SettingsRow(icon: "ruler", label: "Units", value: store.units.title) {
                path.append(Route.edit(.units))
            }
            SettingsToggleRow(icon: "bell", label: "Run day reminders", isOn: $remindersEnabled)
                .onChange(of: remindersEnabled) { _, enabled in
                    Task { await updateReminders(enabled) }
                }
            if Config.paywallEnabled {
                SettingsRow(icon: "creditcard", label: "Subscription") { showCustomerCenter = true }
                SettingsRow(icon: "arrow.clockwise", label: "Restore purchases") {
                    Task {
                        let found = (try? await subscriptions.restore()) ?? false
                        message = found ? "Your subscription is active." : "No active subscription found for this Apple ID."
                    }
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
            // Dialogs sit on their rows, so the popover points at the right one.
            SettingsRow(icon: "rectangle.portrait.and.arrow.right", label: "Sign out") { confirmSignOut = true }
                .confirmationDialog("Sign out of Kiki?", isPresented: $confirmSignOut, titleVisibility: .visible) {
                    Button("Sign out", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                }
            SettingsRow(icon: "trash", label: "Delete account", role: .destructive) {
                confirmDelete = true
            }
            .disabled(isDeleting)
            .confirmationDialog("Delete your account?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete account", role: .destructive, action: deleteAccount)
            } message: {
                Text(Config.paywallEnabled
                     ? "This permanently deletes your profile, plans and runs. It doesn't cancel your subscription. Manage that in your Apple ID settings."
                     : "This permanently deletes your profile, plans and runs.")
            }
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

    /// "Set your goal" (no plan yet): the goal questions from onboarding.
    private func startGoalEdit(_ step: OnboardingModel.Step) {
        goalFlow = .goalEdit(step, store: store) { goalFlow = nil }
    }

    private func updateReminders(_ enabled: Bool) async {
        if enabled {
            guard await Notifications.requestPermission() else {
                remindersEnabled = false
                notificationsOff = true
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

/// The goal on the Profile tab: an ink badge, the goal and its distance and
/// date, then two facts under a hairline (the target and the time left).
private struct ProfileGoalCard: View {
    let plan: Plan
    let units: Units
    let timeline: PlanTimeline

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: RowMetrics.spacing) {
                Image(systemName: "flag")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.paper)
                    .frame(width: 40, height: 40)
                    .background(Color.ink, in: .rect(cornerRadius: Radius.inner - 2))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(plan.displayName).font(.rowTitle)
                    Text(subtitle).font(.detail).foregroundStyle(.muted)
                }
                Spacer(minLength: Spacing.s)
                RowChevron()
            }
            .padding(.bottom, Spacing.m)

            Rectangle().fill(Color.hairline).frame(height: 1)

            HStack(alignment: .top, spacing: Spacing.l) {
                Fact(label: "Goal", value: goalValue)
                Fact(label: "Time left", value: timeLeft)
            }
            .padding(.top, Spacing.m)
        }
        .foregroundStyle(.ink)
        .padding(RowMetrics.horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .elevatedCard()
        .contentShape(.rect(cornerRadius: Radius.card))
        .accessibilityElement(children: .combine)
    }

    /// "26.2 mi · Wed, Dec 16" (the date alone for goals without a distance).
    private var subtitle: String {
        let meters = plan.raceDistanceM ?? plan.raceDistance?.meters
        let distance = meters.map { Format.distance(Double($0), units) }
        let isThisYear = Calendar.current.isDate(timeline.endDate.date, equalTo: .now, toGranularity: .year)
        let date = isThisYear
            ? timeline.endDate.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            : timeline.endDate.date.formatted(.dateTime.month(.abbreviated).day().year())
        return [distance, date].compactMap { $0 }.joined(separator: " · ")
    }

    /// The target: a time, or what finishing means for this goal.
    private var goalValue: String {
        if (plan.goalType == .time || plan.goalKind == .faster), let time = plan.goalTimeS {
            return Format.duration(time)
        }
        switch plan.goalKind {
        case .race, .faster: return "Finish strong"
        case .start: return "Run 30 min"
        case .fit: return "Run consistently"
        }
    }

    /// "11 weeks", "5 days", "Today", or "Done".
    private var timeLeft: String {
        switch timeline.phase {
        case .finished: return "Done"
        case .goalDay: return "Today"
        case .underway:
            let days = timeline.daysLeft
            if days < 14 { return days == 1 ? "1 day" : "\(days) days" }
            return "\(days / 7) weeks"
        }
    }

    private struct Fact: View {
        let label: LocalizedStringKey
        let value: String

        var body: some View {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(label).font(.caption.weight(.medium)).foregroundStyle(.muted)
                Text(value).font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
