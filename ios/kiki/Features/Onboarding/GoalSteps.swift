import SwiftUI

struct GoalStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            title: "What's your goal?",
            subtitle: "Your plan is built around it. You can change it anytime.",
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
    @State private var showCustom = false

    var body: some View {
        @Bindable var model = model
        let units = model.answers.units
        // "Other" shows the chosen distance once one is picked.
        let options = Questions.distances(units: units).map { option in
            guard option.value == .other, model.answers.raceDistance == .other else { return option }
            return ChoiceList<RaceDistance>.Option(
                value: .other,
                title: "Other",
                subtitle: Format.distance(model.answers.customDistanceKm * 1000, units, decimals: 0)
            )
        }
        OnboardingScaffold(
            title: model.answers.goalKind == .faster ? "Which distance do you want to run faster?" : "Which race are you training for?",
            canContinue: model.answers.raceDistance != nil
        ) {
            ChoiceList(options: options, selection: model.answers.raceDistance) { distance in
                model.answers.raceDistance = distance
                if distance == .other { showCustom = true }
            }
        }
        .sheet(isPresented: $showCustom) {
            CustomDistanceSheet(km: $model.answers.customDistanceKm, units: units)
        }
    }
}

/// Picks a custom race distance on the same ruler as the body inputs.
private struct CustomDistanceSheet: View {
    @Binding var km: Double
    let units: Units
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 28) {
            Text("Race distance")
                .font(.title2.weight(.bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            if units == .mi {
                RulerPicker(
                    value: Binding(get: { max(1, Int((km / 1.609344).rounded())) }, set: { km = Double($0) * 1.609344 }),
                    range: 1...62,
                    majorEvery: 5
                ) { "\($0) mi" }
            } else {
                RulerPicker(
                    value: Binding(get: { Int(km.rounded()) }, set: { km = Double($0) }),
                    range: 2...100
                ) { "\($0) km" }
            }
            PrimaryButton("Done") { dismiss() }
        }
        .padding(24)
        .presentationDetents([.height(380)])
        .presentationDragIndicator(.visible)
    }
}

/// Race date as a big readout over a compact date wheel (stable height, same
/// feel as the goal-time wheel), plus an optional race name for a more
/// personal plan. "I don't have a date yet" picks a suggested date instead.
struct RaceDateStep: View {
    @Environment(OnboardingModel.self) private var model
    @FocusState private var nameFocused: Bool

    private var range: ClosedRange<Date> {
        Day.today.adding(days: 7).date...Day.today.adding(days: 24 * 7 - 1).date
    }

    var body: some View {
        @Bindable var model = model
        let date = model.answers.raceDate ?? model.suggestedRaceDate
        // Same count the summary and plan use (includes this week).
        let weeks = GoalSummary(answers: model.answers, raceDate: date).weeks

        OnboardingScaffold(
            title: "When's your race?",
            subtitle: "Your plan counts down to race day.",
            onContinue: {
                model.answers.raceDate = date
                model.answers.noRaceDate = false
                model.advance()
            },
            secondaryTitle: "I don't have a date yet",
            onSecondary: {
                model.answers.raceDate = nil
                model.answers.noRaceDate = true
                model.advance()
            }
        ) {
            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text(date.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                        .font(.metric(.largeTitle))
                        .contentTransition(.numericText())
                    Text(weeks == 1 ? "1 week to train" : "\(weeks) weeks to train")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity)
                .animation(.snappy, value: date)
                .accessibilityElement(children: .combine)

                DatePicker(
                    "Race date",
                    selection: Binding(get: { date.date }, set: { model.answers.raceDate = Day($0) }),
                    in: range,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 180)
                .clipped()
                .onChange(of: model.answers.raceDate) { Haptics.select() }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Race name (optional)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g. Chicago Marathon", text: $model.answers.raceName)
                        .font(.title3.weight(.semibold))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .background(Color.wash, in: .rect(cornerRadius: 20))
                }
            }
        }
    }
}

struct RaceGoalStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(
            title: "What's your goal for race day?",
            canContinue: model.answers.goalType != nil
        ) {
            ChoiceList(
                options: [
                    .init(value: GoalType.finish, title: "Just finish", subtitle: "Cross the line feeling good", icon: "flag.checkered"),
                    .init(value: .time, title: "Hit a time", subtitle: "Train for a finish time", icon: "stopwatch"),
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
            title: "What time are you aiming for?",
            subtitle: "Aim high, but be honest.",
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
                GoalTimeFeedback(seconds: time.wrappedValue, meters: meters)
                    .padding(.top, 16)
            }
        }
    }
}

/// A gentle read on how realistic a goal time is, measured against the
/// world record for the distance. It informs; it never blocks.
private struct GoalTimeFeedback: View {
    let seconds: Int
    let meters: Double

    enum Level { case impossible, elite, ambitious, strong, great }

    /// Fastest times on record (men's 5000m, 10,000m, half, marathon).
    private static let records: [(meters: Double, seconds: Double)] = [
        (5000, 12 * 60 + 35),
        (10000, 26 * 60 + 11),
        (21097, 56 * 60 + 42),
        (42195, 2 * 3600 + 35),
    ]

    /// The record for a distance; custom distances scale from the nearest
    /// record with Riegel's formula.
    static func record(for meters: Double) -> Double {
        let nearest = records.min { abs(log($0.meters / meters)) < abs(log($1.meters / meters)) }!
        return nearest.seconds * pow(meters / nearest.meters, 1.06)
    }

    static func level(seconds: Int, meters: Double) -> Level {
        switch Double(seconds) / record(for: meters) {
        case ..<1: .impossible
        case ..<1.2: .elite
        case ..<1.5: .ambitious
        case ..<1.9: .strong
        default: .great
        }
    }

    var body: some View {
        let level = Self.level(seconds: seconds, meters: meters)
        let (icon, message): (String, LocalizedStringKey) = switch level {
        case .impossible: ("exclamationmark.triangle.fill", "Faster than the world record. Double-check your time?")
        case .elite: ("trophy", "That's elite, world-class territory.")
        case .ambitious: ("flame", "Very ambitious. That takes years of serious training.")
        case .strong: ("bolt", "A strong, challenging goal. Let's go!")
        case .great: ("checkmark.circle", "Great goal. You've got this!")
        }
        Label {
            Text(message)
        } icon: {
            Image(systemName: icon)
        }
        .font(.subheadline.weight(level == .impossible ? .semibold : .medium))
        .foregroundStyle(level == .impossible ? .primary : .secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.wash, in: .rect(cornerRadius: 16))
        .overlay {
            if level == .impossible { RoundedRectangle(cornerRadius: 16).stroke(Color.ink, lineWidth: 1.5) }
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: level)
        .onChange(of: level == .impossible) { _, isImpossible in
            if isImpossible { Haptics.warning() }
        }
        .accessibilityElement(children: .combine)
    }
}

struct TimeframeStep: View {
    @Environment(OnboardingModel.self) private var model

    var body: some View {
        OnboardingScaffold(title: "How many weeks do you want to train?") {
            ChoiceList(
                options: [
                    .init(value: 8, title: "8 weeks", subtitle: "Short and focused"),
                    .init(value: 12, title: "12 weeks", subtitle: "More time to improve"),
                ],
                selection: model.answers.weeks,
                onSelect: { model.answers.weeks = $0 }
            )
        }
    }
}
