import SwiftUI

struct AdaptInfoStep: View {
    var body: some View {
        OnboardingScaffold(
            title: "A plan that adapts, like a real coach",
            subtitle: "Most plans break the first time life gets in the way. Kiki adjusts, so you keep progressing."
        ) {
            Card(padding: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your fitness").font(.headline)
                    AdaptChart()
                        .frame(height: 120)
                    HStack(spacing: 16) {
                        Legend(color: .ink, label: "Kiki")
                        Legend(color: .secondary.opacity(0.6), label: "Rigid plan", dashed: true)
                    }
                    .font(.footnote)
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                InfoRow(symbol: "calendar.badge.exclamationmark", text: "Missed a day? Your week rebalances.")
                InfoRow(symbol: "battery.25percent", text: "Tired or sore? Kiki eases off.")
                InfoRow(symbol: "arrow.up.right", text: "Getting fitter? Your paces keep up.")
            }
            .padding(.top, 28)
        }
    }

    private struct Legend: View {
        let color: Color
        let label: String
        var dashed = false

        var body: some View {
            HStack(spacing: 6) {
                Capsule()
                    .stroke(color, style: StrokeStyle(lineWidth: 3, dash: dashed ? [4, 3] : []))
                    .frame(width: 18, height: 3)
                Text(label).foregroundStyle(.secondary)
            }
        }
    }
}

/// Illustrative curves: steady progress vs. a plan that stalls after setbacks.
private struct AdaptChart: View {
    @State private var drawn: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.85))
                    p.addCurve(to: CGPoint(x: w * 0.45, y: h * 0.55), control1: CGPoint(x: w * 0.2, y: h * 0.8), control2: CGPoint(x: w * 0.3, y: h * 0.55))
                    p.addCurve(to: CGPoint(x: w, y: h * 0.7), control1: CGPoint(x: w * 0.6, y: h * 0.55), control2: CGPoint(x: w * 0.75, y: h * 0.85))
                }
                .trim(from: 0, to: drawn)
                .stroke(Color.secondary.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 5]))

                Path { p in
                    p.move(to: CGPoint(x: 0, y: h * 0.85))
                    p.addCurve(to: CGPoint(x: w, y: h * 0.08), control1: CGPoint(x: w * 0.35, y: h * 0.8), control2: CGPoint(x: w * 0.6, y: h * 0.2))
                }
                .trim(from: 0, to: drawn)
                .stroke(Color.ink, style: StrokeStyle(lineWidth: 4, lineCap: .round))

                Circle().fill(Color.ink).frame(width: 12, height: 12)
                    .position(x: w, y: h * 0.08)
                    .opacity(drawn == 1 ? 1 : 0)
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).delay(0.2)) { drawn = 1 }
        }
    }
}

struct InfoRow: View {
    let symbol: String
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 40, height: 40)
                .background(Color.wash, in: .circle)
            Text(text).font(.body)
        }
    }
}

struct RunDaysStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let recommendation: String = switch model.answers.experience ?? .beginner {
        case .new: "3 days a week is a great start."
        case .beginner: "3–4 days a week works well for most beginners."
        case .intermediate: "4–5 days a week is ideal for your level."
        case .advanced: "5–6 days a week suits experienced runners."
        }

        OnboardingScaffold(
            title: "Which days can you run?",
            subtitle: LocalizedStringKey(recommendation),
            canContinue: model.answers.runDays.count >= 2
        ) {
            VStack(spacing: 12) {
                ForEach(1...7, id: \.self) { day in
                    let selected = model.answers.runDays.contains(day)
                    OptionCard(title: Self.weekdayName(day), isSelected: selected) {
                        if selected {
                            model.answers.runDays.remove(day)
                        } else {
                            model.answers.runDays.insert(day)
                        }
                    }
                }
            }
            Text("\(model.answers.runDays.count) days selected")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 12)
        }
    }

    static func weekdayName(_ isoDay: Int) -> String {
        Calendar.current.weekdaySymbols[isoDay % 7]
    }
}

struct LongRunDayStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        let days = model.answers.runDays.sorted()
        OnboardingScaffold(
            title: "Which day works best for your long run?",
            subtitle: "Pick a day when you have the most time.",
            showsContinue: false
        ) {
            ChoiceList(
                options: days.map { ($0, RunDaysStep.weekdayName($0), nil, nil) },
                selection: model.answers.longRunDay,
                onSelect: { model.answers.longRunDay = $0 }
            )
        }
        .onAppear {
            if let day = model.answers.longRunDay, !model.answers.runDays.contains(day) {
                model.answers.longRunDay = nil
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
            title: "What should Kiki call you?",
            continueTitle: model.answers.firstName.trimmingCharacters(in: .whitespaces).isEmpty ? "Skip" : "Continue"
        ) {
            TextField("First name", text: $model.answers.firstName)
                .font(.title2.weight(.semibold))
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .submitLabel(.continue)
                .focused($focused)
                .onSubmit { model.advance() }
                .padding(20)
                .background(Color.wash, in: .rect(cornerRadius: 20))
        }
        .onAppear { focused = model.answers.firstName.isEmpty }
    }
}

struct AgeStep: View {
    @Environment(OnboardingModel.self) private var model
    private let currentYear = Calendar.current.component(.year, from: .now)

    var body: some View {
        @Bindable var model = model
        let year = Binding(
            get: { model.answers.birthYear ?? currentYear - 32 },
            set: { model.answers.birthYear = $0 }
        )

        OnboardingScaffold(
            title: "What year were you born?",
            subtitle: "Age helps Kiki balance training load and recovery.",
            onContinue: {
                model.answers.birthYear = year.wrappedValue
                model.advance()
            }
        ) {
            Picker("Birth year", selection: year) {
                ForEach((currentYear - 90...currentYear - 13).reversed(), id: \.self) { y in
                    Text(String(y)).tag(y)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 220)
            .onChange(of: year.wrappedValue) { Haptics.select() }
        }
    }
}

struct BodyStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let imperial = model.answers.units == .mi
        let heightCm = Binding(
            get: { model.answers.heightCm ?? (imperial ? 175.26 : 172) },
            set: { model.answers.heightCm = $0 }
        )
        let weightKg = Binding(
            get: { model.answers.weightKg ?? (imperial ? 72.57 : 70) },
            set: { model.answers.weightKg = $0 }
        )
        let hasValues = model.answers.heightCm != nil || model.answers.weightKg != nil

        OnboardingScaffold(
            title: "Height and weight",
            subtitle: "Optional. It helps Kiki fine-tune your training load.",
            continueTitle: hasValues ? "Continue" : "Skip"
        ) {
            HStack(spacing: 0) {
                if imperial {
                    Picker("Height", selection: Binding(
                        get: { Int((heightCm.wrappedValue / 2.54).rounded()) },
                        set: { heightCm.wrappedValue = Double($0) * 2.54 }
                    )) {
                        ForEach(48...84, id: \.self) { inches in
                            Text("\(inches / 12)′ \(inches % 12)″").tag(inches)
                        }
                    }
                    Picker("Weight", selection: Binding(
                        get: { Int((weightKg.wrappedValue / 0.453592).rounded()) },
                        set: { weightKg.wrappedValue = Double($0) * 0.453592 }
                    )) {
                        ForEach(80...400, id: \.self) { Text("\($0) lb").tag($0) }
                    }
                } else {
                    Picker("Height", selection: Binding(
                        get: { Int(heightCm.wrappedValue.rounded()) },
                        set: { heightCm.wrappedValue = Double($0) }
                    )) {
                        ForEach(120...220, id: \.self) { Text("\($0) cm").tag($0) }
                    }
                    Picker("Weight", selection: Binding(
                        get: { Int(weightKg.wrappedValue.rounded()) },
                        set: { weightKg.wrappedValue = Double($0) }
                    )) {
                        ForEach(35...180, id: \.self) { Text("\($0) kg").tag($0) }
                    }
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 220)
        }
    }
}

struct InjuryStep: View {
    @Environment(OnboardingModel.self) private var model
    @FocusState private var focused: Bool

    var body: some View {
        @Bindable var model = model
        OnboardingScaffold(
            title: "Any injuries or pain right now?",
            subtitle: "Kiki will keep your plan gentle where it matters.",
            showsContinue: model.answers.hasInjury == true
        ) {
            ChoiceList(
                options: [
                    (false, "No, I feel good", nil, "checkmark.circle"),
                    (true, "Yes, something's bothering me", nil, "bandage"),
                ],
                selection: model.answers.hasInjury,
                onSelect: { value in
                    model.answers.hasInjury = value
                    if value {
                        focused = true
                    } else {
                        Task {
                            try? await Task.sleep(for: .milliseconds(250))
                            model.advance()
                        }
                    }
                },
                autoAdvance: false
            )
            if model.answers.hasInjury == true {
                TextField("What's going on? e.g. sore left knee on long runs", text: $model.answers.injury, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focused)
                    .padding(18)
                    .background(Color.wash, in: .rect(cornerRadius: 16))
                    .padding(.top, 16)
                Text("Kiki isn't a substitute for medical advice. If pain is sharp or persistent, please see a professional.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
    }
}

struct NotificationsStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            title: "Stay on track",
            subtitle: "Get a quick heads-up on run days, plus a reminder before your free trial ends.",
            continueTitle: "Turn on reminders",
            onContinue: {
                Task {
                    _ = await Notifications.requestPermission()
                    model.advance()
                }
            }
        ) {
            VStack(spacing: 28) {
                NotificationPreview(units: model.answers.units)
                Button("Not now") { model.advance() }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .buttonStyle(.haptic)
            }
        }
    }
}

private struct NotificationPreview: View {
    let units: Units

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            KikiLogo(size: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Today: Tempo Run").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("7:00 AM").font(.caption).foregroundStyle(.secondary)
                }
                Text("Tempo · \(units == .km ? "8.0 km" : "5.0 mi"). Comfortably hard, you've got this.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.primary.opacity(0.06)))
        .shadow(color: .black.opacity(0.08), radius: 20, y: 10)
        .padding(.vertical, 24)
        .accessibilityHidden(true)
    }
}
