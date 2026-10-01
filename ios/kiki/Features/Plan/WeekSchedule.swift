import SwiftUI

/// One week of the plan as a schedule, like a calendar's list view: every
/// day is an equal-height row split by hairlines, the date on the left and
/// the day's workout as a simple event block (accent bar, title, amount).
/// Done workouts lose the block and are struck through; rest days are just
/// the word. Each workout is its own block so press-and-hold to move
/// or edit it can be added later.
struct WeekSchedule: View {
    let workouts: [Workout]
    let units: Units

    var body: some View {
        ListCard(dividerInset: RowMetrics.horizontalPadding, verticalPadding: Spacing.s) {
            ForEach(workouts.sorted { $0.date < $1.date }) { workout in
                if workout.isRest {
                    DayRow(workout: workout, units: units)
                } else {
                    NavigationLink(value: workout) {
                        DayRow(workout: workout, units: units)
                    }
                    .buttonStyle(.haptic)
                }
            }
        }
    }
}

/// One day: the date column and the day's workout (or "Rest").
private struct DayRow: View {
    let workout: Workout
    let units: Units

    static let height: CGFloat = 60

    var body: some View {
        HStack(spacing: Spacing.m) {
            DayLabel(day: workout.date)
            if workout.isRest {
                Text("Rest")
                    .font(.subheadline)
                    .foregroundStyle(.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                WorkoutEvent(workout: workout, units: units)
            }
        }
        .padding(.horizontal, RowMetrics.horizontalPadding)
        .frame(height: Self.height)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// The date column: weekday over the day number. Today's number sits in an
/// ink circle, like a calendar.
private struct DayLabel: View {
    let day: Day

    var body: some View {
        let isToday = day == .today
        VStack(spacing: Spacing.xs) {
            Text(Format.weekday(day, style: .abbreviated).uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(isToday ? Color.ink : Color.muted)
            Text("\(day.day)")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.paper : Color.ink)
                .frame(width: 26, height: 26)
                .background(isToday ? Color.ink : Color.clear, in: .circle)
        }
        .frame(width: 40)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
    }
}

/// A workout as a calendar event: a gray block with an ink accent bar, the
/// title, and how much on the right. Done: no block, gray, struck through.
/// Skipped: the same, with "Skipped" in place of the amount.
private struct WorkoutEvent: View {
    let workout: Workout
    let units: Units

    var body: some View {
        let isPlanned = workout.status == .planned
        HStack(spacing: Spacing.s) {
            switch workout.status {
            case .planned:
                Capsule()
                    .fill(Color.ink)
                    .frame(width: 3, height: 20)
            case .completed, .skipped:
                EmptyView()
            }
            Text(workout.title)
                .font(.subheadline.weight(isPlanned ? .semibold : .regular))
                .strikethrough(!isPlanned)
                .lineLimit(1)
            Spacer(minLength: Spacing.s)
            Text(workout.status == .skipped ? "Skipped" : amount ?? "")
                .font(.subheadline)
                .foregroundStyle(.muted)
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(isPlanned ? Color.ink : Color.muted)
        .padding(.horizontal, isPlanned ? Spacing.s : 0)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .background(isPlanned ? Color.wash : Color.clear, in: .rect(cornerRadius: Radius.inner))
        .accessibilityValue(workout.status == .completed ? "Done" : workout.status == .skipped ? "Skipped" : "")
    }

    /// Just how much, since the title already says what kind of run.
    private var amount: String? {
        if let meters = workout.distanceM { return Format.distance(Double(meters), units) }
        if let seconds = workout.durationS { return Format.minutes(seconds) }
        return nil
    }
}
