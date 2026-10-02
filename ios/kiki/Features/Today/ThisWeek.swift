import SwiftUI

/// Home's "This week": the seven days at a glance (today solid black,
/// done days a check, upcoming runs outlined, rest days gray) and how far through the week's distance and runs the runner is.
/// Tapping a day opens its workout.
struct ThisWeekCard: View {
    @Environment(TrainingStore.self) private var store
    let units: Units
    let onOpen: (Workout) -> Void

    var body: some View {
        let monday = Day.today.mondayOfWeek
        let days = (0..<7).map { monday.adding(days: $0) }
        let workouts = store.workouts(inWeekOf: .today)
        let runs = workouts.filter { !$0.isRest }
        let plannedM = Double(runs.compactMap(\.distanceM).reduce(0, +))
        let doneM = store.runs
            .filter { Day($0.startedAt) >= monday && Day($0.startedAt) <= monday.adding(days: 6) }
            .reduce(0) { $0 + $1.distanceM }
        let runsDone = runs.filter { $0.status == .completed }.count

        Card(padding: Spacing.l) {
            VStack(spacing: Spacing.l) {
                HStack(spacing: 0) {
                    ForEach(days, id: \.self) { day in
                        let workout = workouts.first { $0.date == day }
                        DayColumn(day: day, workout: workout, units: units) {
                            if let workout { onOpen(workout) }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                VStack(spacing: Spacing.s) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("\(runsDone) of \(runs.count) runs done")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(shortDistance(doneM)) of \(shortDistance(plannedM)) \(units.rawValue)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.muted)
                            .monospacedDigit()
                    }
                    // The bar follows the label beside it: runs done out of runs planned.
                    ProgressBar(progress: runs.isEmpty ? 0 : Double(runsDone) / Double(runs.count))
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// "2" or "5.5": no trailing ".0".
    private func shortDistance(_ meters: Double) -> String {
        shortNumber(Format.distanceNumber(meters, units))
    }
}

/// "2.0" → "2", "5.5" stays.
private func shortNumber(_ value: String) -> String {
    value.hasSuffix(".0") ? String(value.dropLast(2)) : value
}

/// One day: weekday letter, the date in a circle, and the plan below.
private struct DayColumn: View {
    let day: Day
    let workout: Workout?
    let units: Units
    let action: () -> Void

    private enum State { case done, today, upcoming, quiet }

    private var state: State {
        guard let workout else { return .quiet }
        if workout.status == .completed && !workout.isRest { return .done }
        if day == .today { return .today }
        if !workout.isRest && workout.status == .planned && day > .today { return .upcoming }
        return .quiet
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.s) {
                Text(Format.weekday(day, style: .narrow))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(day == .today ? Color.ink : Color.muted)
                circle
                Text(label)
                    .font(.caption2.weight(day == .today ? .bold : .medium))
                    .foregroundStyle(day == .today ? Color.ink : Color.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.haptic)
        .disabled(workout == nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month().day()))
        .accessibilityValue(accessibilityValue)
    }

    private var circle: some View {
        ZStack {
            switch state {
            case .done:
                // An accent check: only today is solid black.
                Circle().fill(Color.highlight)
                Image(systemName: "checkmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.onHighlight)
            case .today:
                Circle().fill(Color.ink)
                Text("\(day.day)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.paper)
            case .upcoming:
                Circle().strokeBorder(Color.ink, lineWidth: 1.5)
                Text("\(day.day)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.ink)
            case .quiet:
                Circle().fill(Color.wash)
                Text("\(day.day)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.muted)
            }
        }
        .monospacedDigit()
        .frame(width: 36, height: 36)
    }

    /// The run's amount ("2 mi"); nothing on rest days or outside the plan.
    private var label: String {
        guard let workout, !workout.isRest else { return " " }
        if let meters = workout.distanceM { return "\(shortNumber(Format.distanceNumber(Double(meters), units))) \(units.rawValue)" }
        if let seconds = workout.durationS { return Format.minutes(seconds) }
        return workout.type.label
    }

    private var accessibilityValue: String {
        guard let workout else { return "Not in your plan" }
        if workout.isRest { return "Rest" }
        let status = workout.status == .completed ? "done" : workout.status == .skipped ? "skipped" : "planned"
        return "\(workout.title), \(label), \(status)"
    }
}
