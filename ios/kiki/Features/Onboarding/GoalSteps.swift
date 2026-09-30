import SwiftUI

struct GoalStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            title: "What's your goal?",
            subtitle: "Kiki builds your plan around it. You can change this anytime.",
            canContinue: model.answers.goalKind != nil
        ) {
            ChoiceList(
                options: Questions.goals,
                selection: model.answers.goalKind,
                onSelect: { model.answers.goalKind = $0 }
            )
        }
    }
}

struct DistanceStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        @Bindable var model = model
        OnboardingScaffold(
            title: model.answers.goalKind == .faster ? "Which distance do you want to get faster at?" : "What distance is your race?",
            canContinue: model.answers.raceDistance != nil
        ) {
            ChoiceList(
                options: Questions.distances(units: model.answers.units),
                selection: model.answers.raceDistance,
                onSelect: { model.answers.raceDistance = $0 }
            )
            if model.answers.raceDistance == .other {
                Card {
                    Stepper(value: $model.answers.customDistanceKm, in: 2...100, step: 1) {
                        VStack(alignment: .leading) {
                            Text("Distance").font(.subheadline).foregroundStyle(.secondary)
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
        Day.today.adding(days: 7).date...Day.today.adding(days: 24 * 7 - 1).date
    }

    var body: some View {
        @Bindable var model = model
        let dateBinding = Binding<Date>(
            get: { (model.answers.raceDate ?? model.suggestedRaceDate).date },
            set: { model.answers.raceDate = Day($0) }
        )

        OnboardingScaffold(
            title: "When is race day?",
            subtitle: "No race picked yet? We'll suggest a date that gives you time to train.",
            onContinue: {
                model.answers.noRaceDate = !hasDate
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
        .onAppear { hasDate = !model.answers.noRaceDate }
    }
}

struct RaceGoalStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            title: "What do you want on race day?",
            canContinue: model.answers.goalType != nil
        ) {
            ChoiceList(
                options: [
                    .init(value: GoalType.finish, title: "Just finish", subtitle: "Cross the line feeling good", icon: "flag.checkered"),
                    .init(value: .time, title: "Hit a time", subtitle: "Train for a specific finish time", icon: "stopwatch"),
                ],
                selection: model.answers.goalType,
                onSelect: { model.answers.goalType = $0 }
            )
        }
    }
}

struct GoalTimeStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        @Bindable var model = model
        let time = Binding(
            get: { model.answers.goalTimeS ?? model.defaultGoalTime },
            set: { model.answers.goalTimeS = $0 }
        )
        let meters = model.answers.raceDistance == .other
            ? model.answers.customDistanceKm * 1000
            : Double(model.answers.raceDistance?.meters ?? 5000)

        OnboardingScaffold(
            title: "What's your goal time?",
            subtitle: "Be ambitious but honest. Kiki will tell you if it's a stretch.",
            onContinue: {
                model.answers.goalTimeS = time.wrappedValue
                model.advance()
            }
        ) {
            DurationWheel(seconds: time, showsHours: model.answers.raceDistance != .fiveK)
            if time.wrappedValue > 0 {
                Text("That's about \(Format.pace(Double(time.wrappedValue) / (meters / 1000), model.answers.units)) pace")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: time.wrappedValue)
            }
        }
    }
}

struct TimeframeStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(title: "How long do you want to train?") {
            ChoiceList(
                options: [
                    .init(value: 8, title: "8 weeks", subtitle: "A focused block to sharpen up"),
                    .init(value: 12, title: "12 weeks", subtitle: "More time for bigger gains"),
                ],
                selection: model.answers.weeks,
                onSelect: { model.answers.weeks = $0 }
            )
        }
    }
}
