import SwiftUI

struct UnitsStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            title: "Miles or kilometers?",
            subtitle: "For your distances and paces."
        ) {
            ChoiceList(options: Questions.units, selection: model.answers.units) { model.answers.units = $0 }
        }
    }
}

struct ExperienceStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            title: "How would you rate your running ability?",
            subtitle: "Pick the closest fit. You can change this later.",
            canContinue: model.answers.experience != nil,
            onContinue: { model.advance() }
        ) {
            ChoiceList(
                options: Questions.experience(units: model.answers.units),
                selection: model.answers.experience
            ) { model.answers.experience = $0 }
        }
    }
}

struct WeeklyVolumeStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            title: "How much do you run each week?",
            subtitle: "Your plan starts from here.",
            canContinue: model.answers.weeklyDistanceM != nil
        ) {
            ChoiceList(
                options: Questions.weeklyVolume(units: model.answers.units),
                selection: model.answers.weeklyDistanceM
            ) { model.answers.weeklyDistanceM = $0 }
        }
    }
}

struct LongestRunStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            title: "What's your longest run lately?",
            subtitle: "In the last few weeks.",
            canContinue: model.answers.longestRunM != nil
        ) {
            ChoiceList(
                options: Questions.longestRun(units: model.answers.units),
                selection: model.answers.longestRunM
            ) { model.answers.longestRunM = $0 }
        }
    }
}

struct RunDaysStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        @Bindable var model = model
        OnboardingScaffold(
            title: "Which days can you run?",
            subtitle: "Pick the days that fit your week.",
            canContinue: !model.answers.runDays.isEmpty
        ) {
            RunDaysSelector(days: $model.answers.runDays, longRunDay: $model.answers.longRunDay, experience: model.answers.experience)
        }
    }
}

struct CoachingStyleStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            title: "How do you like to be coached?",
            subtitle: "Kiki will match your style.",
            canContinue: model.answers.coachingStyle != nil
        ) {
            ChoiceList(options: Questions.coachingStyles, selection: model.answers.coachingStyle) {
                model.answers.coachingStyle = $0
            }
        }
    }
}

struct NameStep: View {
    @Environment(OnboardingModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
        OnboardingScaffold(
            title: "What's your name?",
            canContinue: model.firstName != nil
        ) {
            TextField("First name", text: $model.answers.firstName)
                .font(.screenTitle)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($focused)
                .onSubmit { if model.firstName != nil { model.advance() } }
                .inputField()
        }
        .onAppear { focused = model.answers.firstName.isEmpty }
    }
}

struct AgeStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let age = Binding(get: { model.answers.age ?? Defaults.age }, set: { model.answers.age = $0 })
        OnboardingScaffold(
            title: "How old are you?",
            subtitle: "It helps Kiki balance training and recovery.",
            onContinue: {
                model.answers.age = age.wrappedValue
                model.advance()
            }
        ) {
            AgeInput(age: age).padding(.top, Spacing.xxl)
        }
    }
}

struct HeightStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let height = Binding(get: { model.answers.heightCm ?? Defaults.heightCm }, set: { model.answers.heightCm = $0 })
        OnboardingScaffold(
            title: "How tall are you?",
            subtitle: "Optional. Used to tailor your plan.",
            onContinue: {
                model.answers.heightCm = height.wrappedValue
                model.advance()
            },
            secondaryTitle: "Skip",
            onSecondary: {
                model.answers.heightCm = nil
                model.advance()
            }
        ) {
            HeightInput(heightCm: height, units: model.answers.units).padding(.top, Spacing.xxl)
        }
    }
}

struct WeightStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let weight = Binding(get: { model.answers.weightKg ?? Defaults.weightKg }, set: { model.answers.weightKg = $0 })
        OnboardingScaffold(
            title: "How much do you weigh?",
            subtitle: "Optional. Used to tailor your plan.",
            onContinue: {
                model.answers.weightKg = weight.wrappedValue
                model.advance()
            },
            secondaryTitle: "Skip",
            onSecondary: {
                model.answers.weightKg = nil
                model.advance()
            }
        ) {
            WeightInput(weightKg: weight, units: model.answers.units).padding(.top, Spacing.xxl)
        }
    }
}

struct ReferralStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            title: "How did you hear about Kiki?",
            canContinue: model.answers.referralSource != nil,
            onContinue: {
                if let source = model.answers.referralSource {
                    Analytics.track("referral_source_selected", ["source": source], personProperties: ["referral_source": source])
                }
                model.advance()
            }
        ) {
            ChoiceList(
                options: Questions.referralSources.map { .init(value: $0, title: $0) },
                selection: model.answers.referralSource
            ) { model.answers.referralSource = $0 }
        }
    }
}

/// Connect Apple Health: optional. Kiki saves its runs there and syncs
/// runs from other apps; any age, height and weight Health shares fill in
/// those questions so they're skipped.
struct HealthStep: View {
    @Environment(OnboardingModel.self) private var model
    @Environment(HealthService.self) private var health
    @State private var isConnecting = false

    var body: some View {
        OnboardingScaffold(
            title: "Connect Apple Health",
            subtitle: "Kiki works with the running apps you already use.",
            continueTitle: isConnecting ? "Connecting…" : "Connect Apple Health",
            canContinue: !isConnecting,
            onContinue: connect,
            secondaryTitle: "Not now"
        ) {
            // Kiki ⇄ Apple Health, then what connecting does.
            Card(padding: Spacing.xl) {
                HStack(spacing: Spacing.l) {
                    KikiLogo(size: 64)
                        .clipShape(.rect(cornerRadius: 15))
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.muted)
                    HealthAppIcon(size: 64)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Kiki and Apple Health")
            }
            ListCard {
                ListRow(icon: "arrow.triangle.2.circlepath", title: Text("Sync your runs"),
                        subtitles: ["From Apple Watch, Strava, Garmin and more"])
                ListRow(icon: "heart", title: Text("Save runs to Apple Health"),
                        subtitles: ["Runs you record in Kiki, with the route"])
            }
        }
    }

    private func connect() {
        isConnecting = true
        Task {
            defer { isConnecting = false }
            if await health.connect() {
                let info = await health.bodyInfo()
                var filled: Set<OnboardingModel.Step> = []
                if let age = info.age, (13...100).contains(age) {
                    model.answers.age = age
                    filled.insert(.age)
                }
                if let height = info.heightCm, (100...250).contains(height) {
                    model.answers.heightCm = height
                    filled.insert(.height)
                }
                if let weight = info.weightKg, (30...250).contains(weight) {
                    model.answers.weightKg = weight
                    filled.insert(.weight)
                }
                model.answers.fromHealth = filled
                Analytics.track("health_onboarding_connected", ["prefilled": filled.count])
            }
            model.advance()
        }
    }
}

struct NotificationsStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            title: "Want a nudge on run days?",
            subtitle: "A reminder on the mornings you run.",
            continueTitle: "Turn on reminders",
            onContinue: {
                Task {
                    _ = await Notifications.requestPermission()
                    model.advance()
                }
            },
            secondaryTitle: "Not now"
        ) {
            NotificationPreview(units: model.answers.units)
        }
    }
}

private struct NotificationPreview: View {
    let units: Units

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            KikiLogo(size: 40)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    Text("Today: Easy Run").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("7:00 AM").font(.caption).foregroundStyle(.muted)
                }
                Text("Easy Run · \(units == .km ? "5.0 km" : "3.0 mi"). Relaxed and conversational.")
                    .font(.detail)
                    .foregroundStyle(.muted)
            }
        }
        .padding(Spacing.l)
        .elevatedCard(cornerRadius: Radius.card)
        .accessibilityHidden(true)
    }
}

/// The Apple Health app's mark: a pink heart on a white rounded square.
struct HealthAppIcon: View {
    var size: CGFloat = 64

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(LinearGradient(
                colors: [Color(red: 1, green: 0.37, blue: 0.47), Color(red: 1, green: 0.17, blue: 0.33)],
                startPoint: .top, endPoint: .bottom))
            .frame(width: size, height: size)
            .background(Color.white, in: .rect(cornerRadius: size * 0.23))
            .overlay(RoundedRectangle(cornerRadius: size * 0.23).strokeBorder(Color.black.opacity(0.08)))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            .accessibilityLabel("Apple Health")
    }
}
