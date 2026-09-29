import SwiftUI

struct DistanceStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let isOther = model.answers.raceDistance == .other

        OnboardingScaffold(
            title: "What are you training for?",
            subtitle: "Kiki builds your plan around your race.",
            showsContinue: isOther
        ) {
            ChoiceList(
                options: [
                    (RaceDistance.fiveK, "5K", "3.1 miles", nil),
                    (.tenK, "10K", "6.2 miles", nil),
                    (.half, "Half Marathon", "13.1 miles", nil),
                    (.marathon, "Marathon", "26.2 miles", nil),
                    (.other, "Another distance", nil, nil),
                ],
                selection: model.answers.raceDistance,
                onSelect: { value in
                    model.answers.raceDistance = value
                    guard value != .other else { return }
                    Task {
                        try? await Task.sleep(for: .milliseconds(250))
                        model.advance()
                    }
                },
                autoAdvance: false
            )

            if isOther {
                Card {
                    Stepper(value: $model.answers.customDistanceKm, in: 2...100, step: 1) {
                        VStack(alignment: .leading) {
                            Text("Race distance").font(.subheadline).foregroundStyle(.secondary)
                            Text(Format.distance(model.answers.customDistanceKm * 1000, model.answers.units, decimals: 1))
                                .font(.metric(.title2))
                        }
                    }
                }
                .padding(.top, 12)
            }
        }
    }
}

struct RaceDateStep: View {
    @Environment(OnboardingModel.self) private var model
    @State private var hasDate = true

    private var range: ClosedRange<Date> {
        Day.today.adding(days: 7).date...Day.today.adding(days: 40 * 7 - 1).date
    }

    var body: some View {
        @Bindable var model = model
        let dateBinding = Binding<Date>(
            get: { (model.answers.raceDate ?? model.suggestedRaceDate).date },
            set: { model.answers.raceDate = Day($0) }
        )

        OnboardingScaffold(
            title: "When is race day?",
            subtitle: "No race yet? We'll pick a date that gives you time to train. You can change it anytime.",
            onContinue: {
                if !hasDate { model.answers.raceDate = nil }
                model.advance()
            }
        ) {
            VStack(spacing: 16) {
                Picker("Race date", selection: $hasDate) {
                    Text("I have a date").tag(true)
                    Text("Not yet").tag(false)
                }
                .pickerStyle(.segmented)
                .onChange(of: hasDate) { Haptics.select() }

                if hasDate {
                    DatePicker("Race date", selection: dateBinding, in: range, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(.ink)

                    TextField("Race name (optional)", text: $model.answers.raceName)
                        .textInputAutocapitalization(.words)
                        .padding(18)
                        .background(Color.wash, in: .rect(cornerRadius: 16))
                } else {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("We'll plan for").foregroundStyle(.secondary)
                            Text(model.suggestedRaceDate.date, format: .dateTime.weekday(.wide).month(.wide).day())
                                .font(.title2.weight(.bold))
                            Text("\(Day.today.days(until: model.suggestedRaceDate) / 7) weeks to get you ready")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .onAppear { hasDate = model.answers.raceDate != nil || model.path.count <= 2 }
    }
}

struct ExperienceStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(title: "How would you describe your running?", showsContinue: false) {
            ChoiceList(
                options: [
                    (Experience.new, "Just starting out", "I'm new to running or getting back into it", "leaf"),
                    (.beginner, "Beginner", "I run occasionally, a few times a month", "figure.walk"),
                    (.intermediate, "Intermediate", "I run regularly and have done a race or two", "figure.run"),
                    (.advanced, "Advanced", "I train consistently and chase PRs", "bolt"),
                ],
                selection: model.answers.experience,
                onSelect: { value in
                    model.answers.experience = value
                    if model.answers.runDays.isEmpty { model.answers.runDays = model.suggestedRunDays }
                }
            )
        }
    }
}

struct WeeklyVolumeStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let km = model.answers.units == .km

        OnboardingScaffold(
            title: "How much do you run in a typical week?",
            subtitle: "Your plan starts from where you are today.",
            showsContinue: false
        ) {
            Picker("Units", selection: $model.answers.units) {
                Text("Kilometers").tag(Units.km)
                Text("Miles").tag(Units.mi)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 16)
            .onChange(of: model.answers.units) { Haptics.select() }

            ChoiceList(
                options: [
                    (0, "I'm not running yet", nil, nil),
                    (6_000, km ? "Less than 10 km" : "Less than 6 miles", nil, nil),
                    (15_000, km ? "10–20 km" : "6–12 miles", nil, nil),
                    (27_000, km ? "20–35 km" : "12–22 miles", nil, nil),
                    (45_000, km ? "35–55 km" : "22–34 miles", nil, nil),
                    (65_000, km ? "More than 55 km" : "More than 34 miles", nil, nil),
                ],
                selection: model.answers.weeklyDistanceM,
                onSelect: { model.answers.weeklyDistanceM = $0 }
            )
        }
    }
}

struct LongestRunStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        let km = model.answers.units == .km

        OnboardingScaffold(
            title: "What's your longest run in the past month?",
            showsContinue: false
        ) {
            ChoiceList(
                options: [
                    (0, "I haven't run yet", nil, nil),
                    (3_500, km ? "Less than 5 km" : "Less than 3 miles", nil, nil),
                    (8_000, km ? "5–10 km" : "3–6 miles", nil, nil),
                    (13_000, km ? "10–16 km" : "6–10 miles", nil, nil),
                    (20_000, km ? "16–25 km" : "10–15 miles", nil, nil),
                    (28_000, km ? "More than 25 km" : "More than 15 miles", nil, nil),
                ],
                selection: model.answers.longestRunM,
                onSelect: { model.answers.longestRunM = $0 }
            )
        }
    }
}

struct GoalStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(title: "What's your goal for race day?", showsContinue: false) {
            ChoiceList(
                options: [
                    (GoalType.finish, "Finish strong", "Cross the line feeling good", "flag.checkered"),
                    (.time, "Hit a time goal", "Train for a specific finish time", "stopwatch"),
                ],
                selection: model.answers.goalType,
                onSelect: { model.answers.goalType = $0 }
            )
        }
    }
}

struct GoalTimeStep: View {
    @Environment(OnboardingModel.self) private var model

    private var defaultTime: Int {
        switch model.answers.raceDistance ?? .half {
        case .fiveK: 27 * 60
        case .tenK: 55 * 60
        case .half: 2 * 3600
        case .marathon: 4 * 3600 + 15 * 60
        case .other: Int(model.answers.customDistanceKm * 360)
        }
    }

    var body: some View {
        @Bindable var model = model
        let time = Binding(
            get: { model.answers.goalTimeS ?? defaultTime },
            set: { model.answers.goalTimeS = $0 }
        )

        OnboardingScaffold(
            title: "What's your goal time?",
            subtitle: "Be ambitious but honest. Kiki will tell you if it's a stretch.",
            onContinue: {
                model.answers.goalTimeS = time.wrappedValue
                model.advance()
            }
        ) {
            DurationWheel(seconds: time, showsHours: model.answers.raceDistance != .fiveK)
            if let meters = raceMeters, time.wrappedValue > 0 {
                Text("That's about \(Format.pace(Double(time.wrappedValue) / (meters / 1000), model.answers.units)) pace")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: time.wrappedValue)
            }
        }
    }

    private var raceMeters: Double? {
        guard let distance = model.answers.raceDistance else { return nil }
        return distance == .other ? model.answers.customDistanceKm * 1000 : distance.meters.map(Double.init)
    }
}

struct RecentRaceStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let hasResult = model.answers.recentRaceTimeS != nil
        let time = Binding(
            get: { model.answers.recentRaceTimeS ?? 30 * 60 },
            set: { model.answers.recentRaceTimeS = $0 }
        )

        OnboardingScaffold(
            title: "Any recent race results?",
            subtitle: "A result from the last 6 months helps Kiki set your exact paces.",
            continueTitle: hasResult ? "Continue" : "Skip",
            onContinue: {
                if model.answers.recentRaceDistance == nil { model.answers.recentRaceTimeS = nil }
                model.advance()
            }
        ) {
            VStack(spacing: 20) {
                HStack(spacing: 8) {
                    ForEach([RaceDistance.fiveK, .tenK, .half, .marathon], id: \.self) { distance in
                        let selected = model.answers.recentRaceDistance == distance
                        Button {
                            Haptics.select()
                            if selected {
                                model.answers.recentRaceDistance = nil
                                model.answers.recentRaceTimeS = nil
                            } else {
                                model.answers.recentRaceDistance = distance
                                if model.answers.recentRaceTimeS == nil {
                                    model.answers.recentRaceTimeS = [.fiveK: 1680, .tenK: 3480, .half: 7500, .marathon: 16200][distance]
                                }
                            }
                        } label: {
                            Text(distance == .half ? "Half" : distance.label)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .foregroundStyle(selected ? Color.paper : Color.ink)
                                .background(selected ? Color.ink : Color.wash, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if model.answers.recentRaceDistance != nil {
                    DurationWheel(seconds: time, showsHours: model.answers.recentRaceDistance != .fiveK)
                        .transition(.opacity)
                }
            }
            .animation(.snappy, value: model.answers.recentRaceDistance)
        }
    }
}

/// Hours / minutes / seconds wheels.
struct DurationWheel: View {
    @Binding var seconds: Int
    var showsHours = true

    var body: some View {
        HStack(spacing: 0) {
            if showsHours {
                wheel(value: seconds / 3600, range: 0...9, label: "h") { seconds = $0 * 3600 + seconds % 3600 }
            }
            wheel(value: (seconds % 3600) / 60, range: 0...59, label: "min") { seconds = (seconds / 3600) * 3600 + $0 * 60 + seconds % 60 }
            wheel(value: seconds % 60, range: 0...59, label: "sec") { seconds = seconds - seconds % 60 + $0 }
        }
        .frame(height: 200)
        .onChange(of: seconds) { Haptics.select() }
    }

    private func wheel(value: Int, range: ClosedRange<Int>, label: String, set: @escaping (Int) -> Void) -> some View {
        Picker(label, selection: Binding(get: { value }, set: set)) {
            ForEach(range, id: \.self) { n in
                Text("\(n) \(label)").tag(n)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
