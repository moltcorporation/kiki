import SwiftUI

/// Compact row used in week lists and previews.
struct WorkoutRow: View {
    let workout: Workout
    let units: Units
    var showsDate = true

    var body: some View {
        HStack(spacing: 14) {
            if showsDate {
                VStack(spacing: 2) {
                    Text(Format.weekday(workout.date, style: .abbreviated).uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("\(workout.date.day)")
                        .font(.title3.weight(.bold))
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
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            StatusBadge(status: workout.status, isToday: workout.date == .today)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(workout.date == .today ? Color.wash : .clear, in: .rect(cornerRadius: 18))
        .opacity(workout.isRest || workout.status == .skipped ? 0.6 : 1)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

struct WorkoutIcon: View {
    let workout: Workout
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: workout.type.symbol)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(workout.type.isQuality ? Color.paper : Color.ink)
            .frame(width: size, height: size)
            .background(workout.type.isQuality ? Color.ink : Color.wash, in: .circle)
            .accessibilityHidden(true)
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
            Text("Skipped").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
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
                            .foregroundStyle(day == .today ? Color.ink : .secondary)
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
