import SwiftUI

/// Home's "This week": the seven days at a glance (done, today, upcoming,
/// rest) and how far through the week's distance and runs the runner is.
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
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                            Text(Format.distanceNumber(doneM, units)).font(.metric(.title3))
                            Text("of \(Format.distance(plannedM, units))")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.muted)
                        }
                        Spacer()
                        Text("\(runsDone) of \(runs.count) runs")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.muted)
                    }
                    ProgressView(value: min(doneM, plannedM), total: max(plannedM, 1))
                        .tint(.ink)
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
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
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.muted)
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
                Circle().fill(Color.ink)
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.paper)
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

    /// The day's amount ("2.0"), "Rest", or a dash outside the plan.
    private var label: String {
        guard let workout else { return "–" }
        if workout.isRest { return "Rest" }
        if let meters = workout.distanceM { return Format.distanceNumber(Double(meters), units) }
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
