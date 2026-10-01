import SwiftUI

/// One workout in a list card: date, a consistent icon, title and summary,
/// and a status on the right. The standard row anatomy with a date column.
struct WorkoutRow: View {
    let workout: Workout
    let units: Units
    /// Shows the chevron; off where the row doesn't open anything.
    var isNavigable = true

    /// Where the text starts, for inset dividers (after the date column).
    static let textInset: CGFloat = RowMetrics.textInset + 40 + RowMetrics.spacing

    var body: some View {
        let isToday = workout.date == .today
        HStack(spacing: RowMetrics.spacing) {
            VStack(spacing: 1) {
                Text(Format.weekday(workout.date, style: .abbreviated).uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isToday ? Color.ink : Color.muted)
                Text("\(workout.date.day)")
                    .font(.title3.weight(isToday ? .bold : .semibold))
                    .monospacedDigit()
            }
            .frame(width: 40)

            WorkoutIcon(workout: workout)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(workout.title)
                    .font(.rowTitle)
                    .strikethrough(workout.status == .skipped)
                if !workout.isRest {
                    Text(Format.workoutSummary(workout, units: units))
                        .font(.detail)
                        .foregroundStyle(.muted)
                }
            }
            Spacer(minLength: 0)
            StatusBadge(status: workout.status, isToday: isToday)
            if isNavigable { RowChevron() }
        }
        .foregroundStyle(.ink)
        .padding(.horizontal, RowMetrics.horizontalPadding)
        .padding(.vertical, RowMetrics.verticalPadding)
        .opacity(workout.isRest || workout.status == .skipped ? 0.55 : 1)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// The workout type as an outlined glyph in a light circle. One style for
/// every type, so rows read evenly.
struct WorkoutIcon: View {
    let workout: Workout
    var size: RowIcon.Size = .regular

    var body: some View {
        RowIcon(systemName: workout.type.symbol, size: size)
    }
}

struct StatusBadge: View {
    let status: Workout.Status
    var isToday = false

    var body: some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.ink)
                .accessibilityLabel("Completed")
        case .skipped:
            Text("Skipped").font(.caption.weight(.semibold)).foregroundStyle(.muted)
        case .planned:
            if isToday { Pill("Today") }
        }
    }
}

/// The target pace zone for a workout type.
extension WorkoutType {
    var paceZone: PaceZone? {
        switch self {
        case .easy: .easy
        case .recovery: .recovery
        case .long: .long
        case .tempo, .progression: .tempo
        case .intervals, .fartlek, .hills: .interval
        case .racePace, .race: .race
        case .rest, .crossTraining, .runWalk: nil
        }
    }
}

extension PaceZone {
    /// How the pace should feel, in plain words for beginners.
    var effort: String {
        switch self {
        case .easy, .recovery: "Easy. You can chat in full sentences."
        case .long: "Steady and relaxed. Save energy for the finish."
        case .tempo: "Comfortably hard. You can say a few words at a time."
        case .interval: "Hard. Push during each rep, then catch your breath."
        case .race: "Your goal race pace. Practice how it feels."
        }
    }
}
