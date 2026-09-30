import SwiftUI

/// One workout in a list card: date, a consistent icon, title and summary,
/// and a status on the right. Rows own their padding; the card adds none.
struct WorkoutRow: View {
    let workout: Workout
    let units: Units
    var showsDate = true

    /// Where the text starts, for inset dividers (after the date column).
    static let textInset: CGFloat = RowMetrics.textInset + 40 + RowMetrics.spacing

    var body: some View {
        let isToday = workout.date == .today
        HStack(spacing: RowMetrics.spacing) {
            if showsDate {
                VStack(spacing: 1) {
                    Text(Format.weekday(workout.date, style: .abbreviated).uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isToday ? Color.ink : Color.muted)
                    Text("\(workout.date.day)")
                        .font(.title3.weight(isToday ? .bold : .semibold))
                        .monospacedDigit()
                }
                .frame(width: 40)
            }

            WorkoutIcon(workout: workout)

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.title)
                    .font(.body.weight(.semibold))
                    .strikethrough(workout.status == .skipped)
                if !workout.isRest {
                    Text(Format.workoutSummary(workout, units: units))
                        .font(.subheadline)
                        .foregroundStyle(.muted)
                }
            }
            Spacer(minLength: 0)
            StatusBadge(status: workout.status, isToday: isToday)
            RowChevron()
        }
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
    var size: CGFloat = RowMetrics.iconSize

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
            if isToday {
                Text("Today")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.paper)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.ink, in: .capsule)
            }
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

/// Seven-day strip for the current week.
struct WeekStrip: View {
    let days: [Day]
    let workouts: [Workout]
    @Binding var selected: Day

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                let workout = workouts.first { $0.date == day }
                let isSelected = day == selected
                Button {
                    Haptics.select()
                    selected = day
                } label: {
                    VStack(spacing: 8) {
                        Text(Format.weekday(day, style: .narrow))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(day == .today ? Color.ink : .muted)
                        ZStack {
                            Circle()
                                .fill(isSelected ? Color.ink : workout?.status == .completed ? Color.wash : .clear)
                            Circle()
                                .stroke(Color.secondary.opacity(isSelected || workout?.status == .completed ? 0 : 0.25))
                            if workout?.status == .completed {
                                Image(systemName: "checkmark").font(.caption.weight(.bold))
                            } else {
                                Text("\(day.day)").font(.subheadline.weight(.semibold))
                            }
                        }
                        .foregroundStyle(isSelected ? Color.paper : Color.ink)
                        .frame(width: 38, height: 38)
                        Circle()
                            .fill(workout.map { $0.isRest ? Color.clear : Color.ink.opacity(0.5) } ?? .clear)
                            .frame(width: 5, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month().day()))
                .accessibilityValue(workout.map { "\($0.title), \($0.status.rawValue)" } ?? "")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
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
